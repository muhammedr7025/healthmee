from datetime import date, datetime, timezone

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.models import User
from app.common.llm import get_llm_provider
from app.extensions import db
from app.goals.models import Goal
from app.media.models import MediaAsset
from app.media.storage import download_bytes
from app.medical_profile.models import Allergy, LabResult, MedicalProfile
from app.medical_profile.schemas import (
    AllergySchema,
    LabResultSchema,
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
        lab_result = LabResult(user_id=get_jwt_identity(), **data)
        db.session.add(lab_result)
        db.session.commit()
        return lab_result


@blp.route("/lab-results/scan")
class ScanLabReport(MethodView):
    """OCR lab-report scanning (VitaChat onboarding step 6 / Medical Profile
    "Snap a new report"). Uses the configured LLM provider's vision path —
    in mock mode (or against a provider without vision support) this
    honestly returns zero results rather than inventing lab values.
    """

    @jwt_required()
    @blp.arguments(ScanLabReportSchema)
    @blp.response(201, LabResultSchema(many=True))
    def post(self, data):
        user_id = get_jwt_identity()
        asset = MediaAsset.query.filter_by(id=data["media_asset_id"], user_id=user_id).first_or_404()
        if asset.kind != "photo":
            abort(400, message="Lab report scanning needs a photo, not a video.")

        try:
            image_bytes = download_bytes(asset.storage_key)
        except Exception:
            abort(502, message="Couldn't read that photo from storage — please try again.")

        provider = get_llm_provider()
        found = provider.extract_lab_values(image_bytes, asset.content_type or "image/jpeg")

        results = []
        for item in found:
            lab_result = LabResult(
                user_id=user_id,
                source="ocr",
                test_name=item["test_name"],
                value=str(item["value"]),
                unit=item.get("unit"),
                taken_at=datetime.now(timezone.utc),
                media_asset_id=asset.id,
            )
            db.session.add(lab_result)
            results.append(lab_result)
        db.session.commit()
        return results
