from datetime import date, datetime, time, timedelta

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.accounts.models import User
from app.analytics.models import DailyAggregate
from app.extensions import db
from app.logging.models import LogEntry
from app.media.storage import presign_download, upload_bytes
from app.medical_profile.models import Allergy, LabResult, MedicalProfile
from app.reports.models import GeneratedReport
from app.reports.pdf_generator import build_report_pdf
from app.reports.schemas import (
    GenerateReportRequestSchema,
    GeneratedReportSchema,
    GeneratedReportWithUrlSchema,
)

blp = Blueprint("reports", __name__, url_prefix="/api/v1/reports", description="PDF doctor report export")

_DOWNLOAD_EXPIRES_SECONDS = 7 * 24 * 3600  # "Shared links expire after 7 days" (VitaChat copy)


@blp.route("")
class Reports(MethodView):
    """Past reports generated for this account."""

    @jwt_required()
    @blp.response(200, GeneratedReportSchema(many=True))
    def get(self):
        return (
            GeneratedReport.query.filter_by(user_id=get_jwt_identity())
            .order_by(GeneratedReport.created_at.desc())
            .all()
        )


@blp.route("/generate")
class GenerateReport(MethodView):
    @jwt_required()
    @blp.arguments(GenerateReportRequestSchema)
    @blp.response(201, GeneratedReportWithUrlSchema)
    def post(self, data):
        user_id = get_jwt_identity()
        user = User.query.get_or_404(user_id)

        end = data.get("end") or date.today()
        start = data.get("start") or (end - timedelta(days=30))
        day_start = datetime.combine(start, time.min)
        day_end = datetime.combine(end, time.max)

        profile = MedicalProfile.query.filter_by(user_id=user_id, is_current=True).first()
        allergies = Allergy.query.filter_by(user_id=user_id).all()
        labs = (
            LabResult.query.filter(
                LabResult.user_id == user_id, LabResult.taken_at >= day_start, LabResult.taken_at <= day_end
            )
            .order_by(LabResult.taken_at.asc())
            .all()
        )
        entries = (
            LogEntry.query.filter(
                LogEntry.user_id == user_id, LogEntry.timestamp >= day_start, LogEntry.timestamp <= day_end
            )
            .order_by(LogEntry.timestamp.asc())
            .all()
        )
        aggregates = (
            DailyAggregate.query.filter(
                DailyAggregate.user_id == user_id, DailyAggregate.date >= start, DailyAggregate.date <= end
            )
            .order_by(DailyAggregate.date.asc())
            .all()
        )

        pdf_bytes, page_count = build_report_pdf(
            user_name=user.full_name or "",
            user_email=user.email,
            start=start,
            end=end,
            conditions=profile.conditions if profile else [],
            allergies=[a.to_dict() for a in allergies],
            medications=profile.medications if profile else [],
            baseline_vitals=profile.baseline_vitals if profile else {},
            lab_results=[l.to_dict() for l in labs],
            log_entries=[e.to_dict() for e in entries],
            daily_aggregates=[a.to_dict() for a in aggregates],
        )

        storage_key = f"reports/{user_id}/{start.isoformat()}_{end.isoformat()}_{date.today().isoformat()}.pdf"
        upload_bytes(storage_key, pdf_bytes, "application/pdf")

        report = GeneratedReport(
            user_id=user_id, storage_key=storage_key, range_start=start, range_end=end, page_count=page_count
        )
        db.session.add(report)
        db.session.commit()

        return {
            **report.to_dict(),
            "download_url": presign_download(storage_key, expires_in=_DOWNLOAD_EXPIRES_SECONDS),
            "expires_in_seconds": _DOWNLOAD_EXPIRES_SECONDS,
        }


@blp.route("/<string:report_id>")
class ReportDetail(MethodView):
    @jwt_required()
    @blp.response(200, GeneratedReportWithUrlSchema)
    def get(self, report_id):
        """Re-presigns a fresh download link for an existing report."""
        report = GeneratedReport.query.filter_by(id=report_id, user_id=get_jwt_identity()).first_or_404()
        return {
            **report.to_dict(),
            "download_url": presign_download(report.storage_key, expires_in=_DOWNLOAD_EXPIRES_SECONDS),
            "expires_in_seconds": _DOWNLOAD_EXPIRES_SECONDS,
        }

    @jwt_required()
    @blp.response(204)
    def delete(self, report_id):
        """Revoke: removes the record so no further download links can be
        issued for it. (The already-uploaded object isn't swept from the
        bucket — out of scope for this pass.)"""
        report = GeneratedReport.query.filter_by(id=report_id, user_id=get_jwt_identity()).first_or_404()
        db.session.delete(report)
        db.session.commit()
