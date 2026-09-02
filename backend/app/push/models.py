from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class DeviceToken(db.Model, TimestampMixin):
    """A push-registered device. `token` is the FCM registration token the
    Flutter app gets from firebase_messaging once that's wired up client-side
    — this table is ready for it, but nothing populates it yet without a
    Firebase project configured (see PushProvider).
    """

    __tablename__ = "device_tokens"
    __table_args__ = (db.UniqueConstraint("user_id", "token", name="uq_device_tokens_user_token"),)

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    token = db.Column(db.String(512), nullable=False)
    platform = db.Column(db.String(20), nullable=False, default="unknown")  # ios|android|unknown

    def to_dict(self) -> dict:
        return {"id": self.id, "platform": self.platform, "created_at": self.created_at.isoformat()}


class PushLog(db.Model, TimestampMixin):
    """One row per reminder the scheduler decided to send — in mock mode
    (no Firebase credentials) this IS the delivery: nothing goes to a real
    device, but the decision logic runs for real and is inspectable here,
    same "log what would have happened" contract as mock billing.
    """

    __tablename__ = "push_logs"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    kind = db.Column(db.String(30), nullable=False)  # quiet_nudge|streak_milestone
    title = db.Column(db.String(255), nullable=False)
    body = db.Column(db.Text, nullable=False)
    delivery_mode = db.Column(db.String(10), nullable=False)  # mock|fcm
    dedupe_key = db.Column(db.String(255), nullable=False)  # e.g. "quiet_nudge:2026-09-02" — one per user per day/kind

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "kind": self.kind,
            "title": self.title,
            "body": self.body,
            "delivery_mode": self.delivery_mode,
            "created_at": self.created_at.isoformat(),
        }
