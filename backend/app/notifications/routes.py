from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.notifications.models import AlertLog
from app.notifications.schemas import AlertLogSchema

blp = Blueprint("notifications", __name__, url_prefix="/api/v1/alerts", description="Safety alerts")


@blp.route("")
class Alerts(MethodView):
    @jwt_required()
    @blp.response(200, AlertLogSchema(many=True))
    def get(self):
        return (
            AlertLog.query.filter_by(user_id=get_jwt_identity())
            .order_by(AlertLog.created_at.desc())
            .all()
        )


@blp.route("/<string:alert_id>/acknowledge")
class AcknowledgeAlert(MethodView):
    @jwt_required()
    @blp.response(200, AlertLogSchema)
    def post(self, alert_id):
        alert = AlertLog.query.filter_by(id=alert_id, user_id=get_jwt_identity()).first_or_404()
        alert.acknowledged = True
        db.session.commit()
        return alert
