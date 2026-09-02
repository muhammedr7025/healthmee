from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.notifications.models import AlertLog, NotificationPreference
from app.notifications.schemas import AlertLogSchema, NotificationPreferenceSchema

blp = Blueprint("notifications", __name__, url_prefix="/api/v1", description="Safety alerts & reminder preferences")


@blp.route("/notification-preferences")
class NotificationPreferences(MethodView):
    @jwt_required()
    @blp.response(200, NotificationPreferenceSchema)
    def get(self):
        user_id = get_jwt_identity()
        prefs = NotificationPreference.query.filter_by(user_id=user_id).first()
        if prefs is None:
            prefs = NotificationPreference(user_id=user_id)
            db.session.add(prefs)
            db.session.commit()
        return prefs

    @jwt_required()
    @blp.arguments(NotificationPreferenceSchema(partial=True))
    @blp.response(200, NotificationPreferenceSchema)
    def patch(self, data):
        user_id = get_jwt_identity()
        prefs = NotificationPreference.query.filter_by(user_id=user_id).first()
        if prefs is None:
            prefs = NotificationPreference(user_id=user_id)
            db.session.add(prefs)
        for key, value in data.items():
            setattr(prefs, key, value)
        db.session.commit()
        return prefs


@blp.route("/alerts")
class Alerts(MethodView):
    @jwt_required()
    @blp.response(200, AlertLogSchema(many=True))
    def get(self):
        return (
            AlertLog.query.filter_by(user_id=get_jwt_identity())
            .order_by(AlertLog.created_at.desc())
            .all()
        )


@blp.route("/alerts/<string:alert_id>/acknowledge")
class AcknowledgeAlert(MethodView):
    @jwt_required()
    @blp.response(200, AlertLogSchema)
    def post(self, alert_id):
        alert = AlertLog.query.filter_by(id=alert_id, user_id=get_jwt_identity()).first_or_404()
        alert.acknowledged = True
        db.session.commit()
        return alert
