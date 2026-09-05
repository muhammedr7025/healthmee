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


class ChatMessage(db.Model, TimestampMixin):
    """One row per chat-thread bubble, so the thread survives an app
    restart. LogEntry alone isn't enough for this: a message with nothing
    loggable in it produces no LogEntry at all, and the assistant's warm
    reply text isn't stored anywhere else either — both would vanish on
    reopen without this table. extract_card/alert rows point at the
    LogEntry/AlertLog that already hold the real data rather than
    duplicating it, so an edit to an entry's summary is reflected the next
    time history loads.
    """

    __tablename__ = "chat_messages"
    __table_args__ = (db.Index("ix_chat_messages_user_created", "user_id", "created_at"),)

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False)
    # user_text|user_photo|assistant_reply|alert|extract_card
    kind = db.Column(db.String(20), nullable=False)
    text = db.Column(db.Text, nullable=True)
    media_asset_id = db.Column(db.String(36), db.ForeignKey("media_assets.id"), nullable=True)
    log_entry_id = db.Column(db.String(36), db.ForeignKey("log_entries.id"), nullable=True)
    alert_id = db.Column(db.String(36), db.ForeignKey("alert_logs.id"), nullable=True)

    log_entry = db.relationship("LogEntry")
    alert = db.relationship("AlertLog")

    def to_dict(self) -> dict:
        data = {"kind": self.kind, "text": self.text, "created_at": self.created_at.isoformat()}
        if self.kind == "user_photo":
            data["media_asset_id"] = self.media_asset_id
        elif self.kind == "extract_card" and self.log_entry is not None:
            data["entry_id"] = self.log_entry.id
            data["log_type"] = self.log_entry.type
            data["payload"] = self.log_entry.structured_payload
            data["summary"] = self.log_entry.summary
        elif self.kind == "alert" and self.alert is not None:
            data["message"] = self.alert.message
            data["severity"] = self.alert.severity
        return data
