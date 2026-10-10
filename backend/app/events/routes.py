from datetime import timezone

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.events.models import ProductEvent
from app.events.schemas import EventBatchResponseSchema, EventBatchSchema
from app.events.service import _bounded
from app.extensions import db, limiter, user_or_ip

blp = Blueprint("events", __name__, url_prefix="/api/v1/events", description="Product analytics events from the app")


@blp.route("")
class Events(MethodView):
    decorators = [limiter.limit("120/minute", key_func=user_or_ip)]

    @jwt_required()
    @blp.arguments(EventBatchSchema)
    @blp.response(202, EventBatchResponseSchema)
    def post(self, data):
        """The app batches events (≤50) and sends them every few seconds or
        when it goes to the background. Accepted means stored; nothing here
        can fail the user's real work, so bad rows are dropped, not 4xx'd."""
        user_id = get_jwt_identity()
        rows = []
        for event in data["events"]:
            client_ts = event.get("client_ts")
            if client_ts is not None and client_ts.tzinfo is not None:
                client_ts = client_ts.astimezone(timezone.utc).replace(tzinfo=None)
            rows.append(
                ProductEvent(
                    user_id=user_id,
                    name=event["name"],
                    props=_bounded(event.get("props") or {}),
                    platform=data["platform"],
                    app_version=data.get("app_version"),
                    session_id=data.get("session_id"),
                    client_ts=client_ts,
                )
            )
        db.session.add_all(rows)
        db.session.commit()
        return {"accepted": len(rows)}
