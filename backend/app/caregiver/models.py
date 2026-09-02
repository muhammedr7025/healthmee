from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class CaregiverLink(db.Model, TimestampMixin):
    """A permission-scoped link from one account (the owner, i.e. the person
    being cared for) to another (the caregiver). Invited by email — the
    invitee doesn't need an account yet; `caregiver_user_id` is filled in
    once they sign up and accept (dev-prompt: caregiver mode, Phase 2).
    """

    __tablename__ = "caregiver_links"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    owner_user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    caregiver_user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=True, index=True)
    caregiver_email = db.Column(db.String(255), nullable=False, index=True)

    status = db.Column(db.String(20), nullable=False, default="pending")  # pending|active|declined|revoked

    can_view_logs = db.Column(db.Boolean, nullable=False, default=True)
    can_view_trends_reports = db.Column(db.Boolean, nullable=False, default=True)
    can_edit_profile = db.Column(db.Boolean, nullable=False, default=False)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "owner_user_id": self.owner_user_id,
            "caregiver_user_id": self.caregiver_user_id,
            "caregiver_email": self.caregiver_email,
            "status": self.status,
            "can_view_logs": self.can_view_logs,
            "can_view_trends_reports": self.can_view_trends_reports,
            "can_edit_profile": self.can_edit_profile,
            "created_at": self.created_at.isoformat(),
        }
