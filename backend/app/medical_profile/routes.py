import time
from datetime import date, timezone

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.models import User
from app.common.llm import get_llm_provider
from app.events.service import record_llm_call, track
from app.extensions import db, limiter, user_or_ip
from app.goals.models import Goal
from app.media.models import MediaAsset
from app.media.storage import MediaTooLarge, download_bytes
from app.medical_profile.models import Allergy, LabResult, MedicalProfile
from app.medical_profile.schemas import (
    AllergySchema,
    LabResultSchema,
    LabResultsBulkSchema,
    LabScanResponseSchema,
    MedicalProfileSchema,
    OnboardingSchema,
    ScanLabReportSchema,
)

blp = Blueprint(
    "medical_profile", __name__, url_prefix="/api/v1", description="Medical profile, allergies, lab results, onboarding"
)


@blp.route("/onboarding")
class Onboarding(MethodView):
    @jwt_required()
    @blp.arguments(OnboardingSchema)
    @blp.response(201, MedicalProfileSchema)
    def post(self, data):
        user = User.query.get_or_404(get_jwt_identity())
        if data.get("full_name"):
            user.full_name = data["full_name"]

        profile = MedicalProfile(
            user_id=user.id,
            version=1,
            is_current=True,
            conditions=data["conditions"],
            medications=data["medications"],
            baseline_vitals=data["baseline_vitals"],
        )
        db.session.add(profile)

        for allergy_data in data["allergies"]:
            db.session.add(Allergy(user_id=user.id, **allergy_data))

        for goal_data in data["goals"]:
            db.session.add(
                Goal(
                    user_id=user.id,
                    type=goal_data["type"],
                    target_value=goal_data["target_value"],
                    target_date=goal_data.get("target_date"),
                    start_date=date.today(),
                )
            )

        user.onboarding_completed = True
        db.session.commit()
        track(
            "onboarding_complete",
            user.id,
            conditions=len(data["conditions"]),
            medications=len(data["medications"]),
            allergies=len(data["allergies"]),
            goals=len(data["goals"]),
            has_name=bool(data.get("full_name")),
        )
        return profile


@blp.route("/medical-profile")
class MedicalProfileView(MethodView):
    @jwt_required()
    @blp.response(200, MedicalProfileSchema)
    def get(self):
        user_id = get_jwt_identity()
        return MedicalProfile.query.filter_by(user_id=user_id, is_current=True).first_or_404()

    @jwt_required()
    @blp.arguments(MedicalProfileSchema)
    @blp.response(201, MedicalProfileSchema)
    def put(self, data):
        """Edits are versioned: the previous current row is kept as history,
        a new row becomes current (dev-prompt §4)."""
        user_id = get_jwt_identity()
        current = MedicalProfile.query.filter_by(user_id=user_id, is_current=True).first()

        next_version = (current.version + 1) if current else 1
        if current:
            current.is_current = False

        new_profile = MedicalProfile(
            user_id=user_id,
            version=next_version,
            is_current=True,
            conditions=data.get("conditions", current.conditions if current else []),
            medications=data.get("medications", current.medications if current else []),
            baseline_vitals=data.get("baseline_vitals", current.baseline_vitals if current else {}),
            notes=data.get("notes", current.notes if current else None),
        )
        db.session.add(new_profile)
        db.session.commit()
        return new_profile


@blp.route("/medical-profile/history")
class MedicalProfileHistory(MethodView):
    @jwt_required()
    @blp.response(200, MedicalProfileSchema(many=True))
    def get(self):
        user_id = get_jwt_identity()
        return MedicalProfile.query.filter_by(user_id=user_id).order_by(MedicalProfile.version.desc()).all()


@blp.route("/allergies")
class Allergies(MethodView):
    @jwt_required()
    @blp.response(200, AllergySchema(many=True))
    def get(self):
        return Allergy.query.filter_by(user_id=get_jwt_identity()).all()

    @jwt_required()
    @blp.arguments(AllergySchema)
    @blp.response(201, AllergySchema)
    def post(self, data):
        allergy = Allergy(user_id=get_jwt_identity(), **data)
        db.session.add(allergy)
        db.session.commit()
        return allergy


@blp.route("/allergies/<string:allergy_id>")
class AllergyDetail(MethodView):
    @jwt_required()
    @blp.response(204)
    def delete(self, allergy_id):
        allergy = Allergy.query.filter_by(id=allergy_id, user_id=get_jwt_identity()).first_or_404()
        db.session.delete(allergy)
        db.session.commit()


@blp.route("/lab-results")
class LabResults(MethodView):
    @jwt_required()
    @blp.response(200, LabResultSchema(many=True))
    def get(self):
        return (
            LabResult.query.filter_by(user_id=get_jwt_identity())
            .order_by(LabResult.taken_at.desc())
            .all()
        )

    @jwt_required()
    @blp.arguments(LabResultSchema)
    @blp.response(201, LabResultSchema)
    def post(self, data):
        user_id = get_jwt_identity()
        if data.get("media_asset_id") and not MediaAsset.query.filter_by(id=data["media_asset_id"], user_id=user_id).first():
            abort(404, message="Unknown media asset.")
        lab_result = LabResult(user_id=user_id, **data)
        db.session.add(lab_result)
        db.session.commit()
        return lab_result


@blp.route("/lab-results/scan")
class ScanLabReport(MethodView):
    """Reads a lab report — a photo or a PDF — and returns what it found as
    *candidates*, plus the report date if one was printed. Nothing is saved
    here: the app shows the rows for the user to untick or correct, then
    POSTs the keepers to /lab-results/bulk. A misread glucose value is
    exactly the thing that must not land silently in a medical record. In
    mock mode (or with a provider that can't see) this honestly returns no
    candidates rather than inventing lab values.
    """

    decorators = [limiter.limit("20/hour", key_func=user_or_ip)]

    @jwt_required()
    @blp.arguments(ScanLabReportSchema)
    @blp.response(200, LabScanResponseSchema)
    def post(self, data):
        user_id = get_jwt_identity()
        asset = MediaAsset.query.filter_by(id=data["media_asset_id"], user_id=user_id).first_or_404()
        if asset.kind not in ("photo", "document"):
            abort(400, message="Lab report scanning needs a photo or a PDF, not a video.")

        try:
            file_bytes = download_bytes(asset.storage_key)
        except MediaTooLarge as too_large:
            abort(413, message=f"That file is {too_large.size // (1024 * 1024)} MB — the limit is {too_large.limit // (1024 * 1024)} MB. Try a photo of the page.")
        except Exception:
            abort(502, message="Couldn't read that file from storage — please try again.")

        default_mime = "application/pdf" if asset.kind == "document" else "image/jpeg"
        provider = get_llm_provider()
        started = time.perf_counter()
        report = provider.read_lab_report(file_bytes, asset.content_type or default_mime)
        record_llm_call(
            purpose="lab_report",
            provider=provider.name,
            model=provider.model_name,
            latency_ms=round((time.perf_counter() - started) * 1000),
            user_id=user_id,
            has_media=True,
            output_entries=len(report.get("results", [])),
            usage=getattr(provider, "last_usage", None),
        )
        track(
            "lab_scan_read",
            user_id,
            source=asset.kind,
            candidates=len(report.get("results", [])),
            report_date_detected=report.get("report_date") is not None,
        )
        return {
            "report_date": report.get("report_date"),
            "media_asset_id": asset.id,
            "candidates": report.get("results", []),
        }


@blp.route("/lab-results/bulk")
class LabResultsBulk(MethodView):
    """Saves the rows the user kept from a scan's review sheet, all dated
    with the report's date (or whatever date they picked) rather than the
    moment they happened to upload it."""

    decorators = [limiter.limit("30/hour", key_func=user_or_ip)]

    @jwt_required()
    @blp.arguments(LabResultsBulkSchema)
    @blp.response(201, LabResultSchema(many=True))
    def post(self, data):
        user_id = get_jwt_identity()
        taken_at = data["taken_at"]
        if taken_at.tzinfo is not None:
            taken_at = taken_at.astimezone(timezone.utc).replace(tzinfo=None)

        media_asset_id = data.get("media_asset_id")
        if media_asset_id and not MediaAsset.query.filter_by(id=media_asset_id, user_id=user_id).first():
            abort(404, message="Unknown media asset.")

        results = [
            LabResult(user_id=user_id, source="ocr", taken_at=taken_at, media_asset_id=media_asset_id, **item)
            for item in data["results"]
        ]
        db.session.add_all(results)
        db.session.commit()
        track("lab_results_saved", user_id, kept=len(results), from_scan=media_asset_id is not None)
        return results
