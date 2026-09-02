from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.models import User
from app.caregiver.models import CaregiverLink
from app.caregiver.schemas import (
    CaregiverLinkSchema,
    CaregiverSummarySchema,
    InviteCaregiverSchema,
    UpdateCaregiverPermissionsSchema,
)
from app.extensions import db
from app.logging.models import LogEntry
from app.medical_profile.models import MedicalProfile

blp = Blueprint("caregiver", __name__, url_prefix="/api/v1/caregiver", description="Caregiver mode")


@blp.route("/links")
class CaregiverLinks(MethodView):
    """Links I (the owner) have invited, as the person being cared for."""

    @jwt_required()
    @blp.response(200, CaregiverLinkSchema(many=True))
    def get(self):
        return CaregiverLink.query.filter_by(owner_user_id=get_jwt_identity()).order_by(
            CaregiverLink.created_at.desc()
        ).all()

    @jwt_required()
    @blp.arguments(InviteCaregiverSchema)
    @blp.response(201, CaregiverLinkSchema)
    def post(self, data):
        owner_id = get_jwt_identity()
        owner = User.query.get_or_404(owner_id)

        if data["email"].lower() == owner.email.lower():
            abort(400, message="You can't invite yourself as a caregiver.")

        existing = CaregiverLink.query.filter_by(
            owner_user_id=owner_id, caregiver_email=data["email"].lower()
        ).filter(CaregiverLink.status.in_(["pending", "active"])).first()
        if existing:
            abort(409, message="This person already has a pending or active invite.")

        matching_user = User.query.filter_by(email=data["email"].lower()).first()

        link = CaregiverLink(
            owner_user_id=owner_id,
            caregiver_user_id=matching_user.id if matching_user else None,
            caregiver_email=data["email"].lower(),
            can_view_logs=data["can_view_logs"],
            can_view_trends_reports=data["can_view_trends_reports"],
            can_edit_profile=data["can_edit_profile"],
        )
        db.session.add(link)
        db.session.commit()
        return link


@blp.route("/links/<string:link_id>")
class CaregiverLinkDetail(MethodView):
    @jwt_required()
    @blp.arguments(UpdateCaregiverPermissionsSchema)
    @blp.response(200, CaregiverLinkSchema)
    def patch(self, data, link_id):
        link = CaregiverLink.query.filter_by(id=link_id, owner_user_id=get_jwt_identity()).first_or_404()
        for key, value in data.items():
            setattr(link, key, value)
        db.session.commit()
        return link

    @jwt_required()
    @blp.response(204)
    def delete(self, link_id):
        link = CaregiverLink.query.filter_by(id=link_id, owner_user_id=get_jwt_identity()).first_or_404()
        link.status = "revoked"
        db.session.commit()


@blp.route("/invitations")
class CaregiverInvitations(MethodView):
    """Invitations addressed to me, as a prospective caregiver."""

    @jwt_required()
    @blp.response(200, CaregiverLinkSchema(many=True))
    def get(self):
        user = User.query.get_or_404(get_jwt_identity())
        links = CaregiverLink.query.filter_by(caregiver_email=user.email.lower(), status="pending").all()
        return _with_owner_info(links)


@blp.route("/invitations/<string:link_id>/accept")
class AcceptInvitation(MethodView):
    @jwt_required()
    @blp.response(200, CaregiverLinkSchema)
    def post(self, link_id):
        user = User.query.get_or_404(get_jwt_identity())
        link = CaregiverLink.query.filter_by(id=link_id, caregiver_email=user.email.lower()).first_or_404()
        if link.status != "pending":
            abort(409, message="This invitation is no longer pending.")
        link.caregiver_user_id = user.id
        link.status = "active"
        db.session.commit()
        return link


@blp.route("/invitations/<string:link_id>/decline")
class DeclineInvitation(MethodView):
    @jwt_required()
    @blp.response(200, CaregiverLinkSchema)
    def post(self, link_id):
        user = User.query.get_or_404(get_jwt_identity())
        link = CaregiverLink.query.filter_by(id=link_id, caregiver_email=user.email.lower()).first_or_404()
        if link.status != "pending":
            abort(409, message="This invitation is no longer pending.")
        link.status = "declined"
        db.session.commit()
        return link


@blp.route("/access")
class CaregiverAccess(MethodView):
    """Owner accounts I (the caregiver) currently have active access to."""

    @jwt_required()
    @blp.response(200, CaregiverLinkSchema(many=True))
    def get(self):
        links = CaregiverLink.query.filter_by(caregiver_user_id=get_jwt_identity(), status="active").all()
        return _with_owner_info(links)


@blp.route("/access/<string:owner_user_id>/summary")
class CaregiverOwnerSummary(MethodView):
    @jwt_required()
    @blp.response(200, CaregiverSummarySchema)
    def get(self, owner_user_id):
        link = CaregiverLink.query.filter_by(
            owner_user_id=owner_user_id, caregiver_user_id=get_jwt_identity(), status="active"
        ).first_or_404()
        if not link.can_view_logs and not link.can_view_trends_reports:
            abort(403, message="This caregiver link doesn't grant viewing access.")

        owner = User.query.get_or_404(owner_user_id)
        profile = None
        if link.can_view_trends_reports:
            current = MedicalProfile.query.filter_by(user_id=owner_user_id, is_current=True).first()
            profile = current.to_dict() if current else None

        recent_logs = []
        if link.can_view_logs:
            entries = (
                LogEntry.query.filter_by(user_id=owner_user_id)
                .order_by(LogEntry.timestamp.desc())
                .limit(20)
                .all()
            )
            recent_logs = [e.to_dict() for e in entries]

        return {
            "owner_user_id": owner.id,
            "owner_email": owner.email,
            "owner_full_name": owner.full_name,
            "medical_profile": profile,
            "recent_logs": recent_logs,
            "permissions": {
                "can_view_logs": link.can_view_logs,
                "can_view_trends_reports": link.can_view_trends_reports,
                "can_edit_profile": link.can_edit_profile,
            },
        }


def _with_owner_info(links):
    out = []
    for link in links:
        d = link.to_dict()
        owner = User.query.get(link.owner_user_id)
        d["owner_email"] = owner.email if owner else None
        d["owner_full_name"] = owner.full_name if owner else None
        out.append(d)
    return out
