from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class GeneratedReport(db.Model, TimestampMixin):
    """One row per PDF actually generated — lets Reports list past exports
    and revoke a share link (deletes the row; the presign simply won't be
    re-issued, and the object itself can be swept by bucket lifecycle rules).
    """

    __tablename__ = "generated_reports"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    storage_key = db.Column(db.String(512), nullable=False)
    range_start = db.Column(db.Date, nullable=False)
    range_end = db.Column(db.Date, nullable=False)
    page_count = db.Column(db.Integer, nullable=False, default=1)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "range_start": self.range_start.isoformat(),
            "range_end": self.range_end.isoformat(),
            "page_count": self.page_count,
            "created_at": self.created_at.isoformat(),
        }
