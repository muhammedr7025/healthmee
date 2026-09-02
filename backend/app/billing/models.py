from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class Subscription(db.Model, TimestampMixin):
    """One row per user. `plan`/`status` are the source of truth for feature
    gating (app/billing/service.py:is_premium) regardless of whether billing
    is running against real Stripe or in mock mode.
    """

    __tablename__ = "subscriptions"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, unique=True, index=True)

    plan = db.Column(db.String(20), nullable=False, default="free")  # free|premium
    status = db.Column(db.String(20), nullable=False, default="none")  # none|active|trialing|canceled|past_due
    billing_mode = db.Column(db.String(10), nullable=False, default="mock")  # mock|stripe

    stripe_customer_id = db.Column(db.String(255), nullable=True)
    stripe_subscription_id = db.Column(db.String(255), nullable=True)
    current_period_end = db.Column(db.DateTime, nullable=True)
    cancel_at_period_end = db.Column(db.Boolean, nullable=False, default=False)

    def to_dict(self) -> dict:
        return {
            "plan": self.plan,
            "status": self.status,
            "billing_mode": self.billing_mode,
            "is_premium": self.plan == "premium" and self.status in ("active", "trialing"),
            "current_period_end": self.current_period_end.isoformat() if self.current_period_end else None,
            "cancel_at_period_end": self.cancel_at_period_end,
        }
