from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class Goal(db.Model, TimestampMixin):
    __tablename__ = "goals"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    type = db.Column(db.String(64), nullable=False)  # weight|blood_pressure|calories|activity|custom
    target_value = db.Column(db.JSON, nullable=False, default=dict)  # e.g. {"value": 70, "unit": "kg"}
    start_value = db.Column(db.JSON, nullable=True)
    start_date = db.Column(db.Date, nullable=False)
    target_date = db.Column(db.Date, nullable=True)
    status = db.Column(db.String(20), nullable=False, default="active")  # active|completed|abandoned

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "type": self.type,
            "target_value": self.target_value,
            "start_value": self.start_value,
            "start_date": self.start_date.isoformat(),
            "target_date": self.target_date.isoformat() if self.target_date else None,
            "status": self.status,
        }
