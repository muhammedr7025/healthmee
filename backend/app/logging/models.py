from app.common.models import TimestampMixin, gen_uuid, utcnow
from app.extensions import db


class LogEntry(db.Model, TimestampMixin):
    """`type` is deliberately a free string, not a DB enum — new types are
    added by registering them in app/logging/registry.py, never by migrating
    this table (dev-prompt §6/§7 extensibility)."""

    __tablename__ = "log_entries"
    __table_args__ = (db.Index("ix_log_entries_user_type_ts", "user_id", "type", "timestamp"),)

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    type = db.Column(db.String(64), nullable=False)
    timestamp = db.Column(db.DateTime, nullable=False, default=utcnow)
    structured_payload = db.Column(db.JSON, nullable=False, default=dict)
    raw_text = db.Column(db.Text, nullable=True)
    summary = db.Column(db.String(255), nullable=True)
    media_asset_id = db.Column(db.String(36), db.ForeignKey("media_assets.id"), nullable=True)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "type": self.type,
            "timestamp": self.timestamp.isoformat(),
            "payload": self.structured_payload,
            "raw_text": self.raw_text,
            "summary": self.summary,
            "media_asset_id": self.media_asset_id,
        }
