from datetime import date, timedelta

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.analytics.models import DailyAggregate
from app.analytics.schemas import DailyAggregateSchema, TrendsQuerySchema, TrendsResponseSchema

blp = Blueprint("analytics", __name__, url_prefix="/api/v1", description="Today summary & trends")


@blp.route("/today")
class Today(MethodView):
    @jwt_required()
    @blp.response(200, DailyAggregateSchema)
    def get(self):
        user_id = get_jwt_identity()
        today = date.today()
        aggregate = DailyAggregate.query.filter_by(user_id=user_id, date=today).first()
        if aggregate is None:
            return {
                "date": today.isoformat(),
                "total_calories": 0,
                "activity_minutes": 0,
                "sleep_hours": None,
                "mood_score": None,
                "water_ml": 0,
                "log_count": 0,
            }
        return aggregate


@blp.route("/trends")
class Trends(MethodView):
    @jwt_required()
    @blp.arguments(TrendsQuerySchema, location="query")
    @blp.response(200, TrendsResponseSchema)
    def get(self, args):
        user_id = get_jwt_identity()
        end = args.get("end") or date.today()
        start = args.get("start") or (end - timedelta(days=30))

        days = (
            DailyAggregate.query.filter(
                DailyAggregate.user_id == user_id,
                DailyAggregate.date >= start,
                DailyAggregate.date <= end,
            )
            .order_by(DailyAggregate.date.asc())
            .all()
        )

        return {"days": days, "callouts": _build_callouts(days)}


def _build_callouts(days: list[DailyAggregate]) -> list[str]:
    """Simple correlation surfacing (PRD §7.4/§10): compare mood on low-sleep
    vs. well-rested days. A lightweight heuristic, not a statistical model —
    good enough to prompt the user to look closer, per the "passive trend
    narration" differentiator (PRD §4.5).
    """
    low_sleep_moods = [d.mood_score for d in days if d.sleep_hours is not None and d.sleep_hours < 6 and d.mood_score]
    rested_moods = [d.mood_score for d in days if d.sleep_hours is not None and d.sleep_hours >= 7 and d.mood_score]

    callouts = []
    if low_sleep_moods and rested_moods:
        low_avg = sum(low_sleep_moods) / len(low_sleep_moods)
        rested_avg = sum(rested_moods) / len(rested_moods)
        if low_avg < rested_avg - 0.5:
            callouts.append("Your mood tends to dip after low-sleep nights — want to see the pattern?")
    return callouts
