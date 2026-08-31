from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class AlertLog(db.Model, TimestampMixin):
    __tablename__ = "alert_logs"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    log_entry_id = db.Column(db.String(36), db.ForeignKey("log_entries.id"), nullable=True)
    trigger_type = db.Column(db.String(64), nullable=False)  # allergy|goal_conflict|...
    severity = db.Column(db.String(10), nullable=False)  # hard|soft
    message = db.Column(db.Text, nullable=False)
    acknowledged = db.Column(db.Boolean, nullable=False, default=False)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "log_entry_id": self.log_entry_id,
            "trigger_type": self.trigger_type,
            "severity": self.severity,
            "message": self.message,
            "acknowledged": self.acknowledged,
            "created_at": self.created_at.isoformat(),
        }
