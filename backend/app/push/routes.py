from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.push.models import DeviceToken, PushLog
from app.push.schemas import DeviceTokenSchema, PushLogSchema, RegisterDeviceSchema

blp = Blueprint("push", __name__, url_prefix="/api/v1/push", description="Push notification device registration")


@blp.route("/devices")
class Devices(MethodView):
    @jwt_required()
    @blp.response(200, DeviceTokenSchema(many=True))
    def get(self):
        return DeviceToken.query.filter_by(user_id=get_jwt_identity()).all()

    @jwt_required()
    @blp.arguments(RegisterDeviceSchema)
    @blp.response(201, DeviceTokenSchema)
    def post(self, data):
        user_id = get_jwt_identity()
        existing = DeviceToken.query.filter_by(user_id=user_id, token=data["token"]).first()
        if existing:
            existing.platform = data["platform"]
            db.session.commit()
            return existing

        device = DeviceToken(user_id=user_id, token=data["token"], platform=data["platform"])
        db.session.add(device)
        db.session.commit()
        return device


@blp.route("/devices/<string:device_id>")
class DeviceDetail(MethodView):
    @jwt_required()
    @blp.response(204)
    def delete(self, device_id):
        device = DeviceToken.query.filter_by(id=device_id, user_id=get_jwt_identity()).first_or_404()
        db.session.delete(device)
        db.session.commit()


@blp.route("/log")
class Log(MethodView):
    """Recent reminders the scheduler has sent (or, in mock mode, recorded)
    for this account — lets the app show something real even without a
    Firebase project connected, instead of the toggle being a no-op."""

    @jwt_required()
    @blp.response(200, PushLogSchema(many=True))
    def get(self):
        return (
            PushLog.query.filter_by(user_id=get_jwt_identity())
            .order_by(PushLog.created_at.desc())
            .limit(20)
            .all()
        )
