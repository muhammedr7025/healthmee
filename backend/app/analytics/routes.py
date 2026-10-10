from datetime import timedelta

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.accounts.models import User
from app.analytics.models import DailyAggregate
from app.analytics.narrative import build_period_narrative
from app.analytics.schemas import (
    DailyAggregateSchema,
    NarrativeQuerySchema,
    NarrativeResponseSchema,
    TodayScoreSchema,
    TrendsQuerySchema,
    TrendsResponseSchema,
)
from app.analytics.score import compute_today_score
from app.common.localtime import local_today, user_tz_offset
from app.goals.models import Goal
from app.medications.service import day_plan

blp = Blueprint("analytics", __name__, url_prefix="/api/v1", description="Today summary & trends")


@blp.route("/today")
class Today(MethodView):
    @jwt_required()
    @blp.response(200, DailyAggregateSchema)
    def get(self):
        user = User.query.get_or_404(get_jwt_identity())
        user_id = user.id
        today = local_today(user_tz_offset(user))
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


@blp.route("/today/score")
class TodayScore(MethodView):
    """A habit score for today with its working shown — see analytics/score.py."""

    @jwt_required()
    @blp.response(200, TodayScoreSchema)
    def get(self):
        user = User.query.get_or_404(get_jwt_identity())
        today = local_today(user_tz_offset(user))
        aggregate = DailyAggregate.query.filter_by(user_id=user.id, date=today).first()
        calorie_goal = _calorie_goal(user.id)
        return compute_today_score(aggregate, calorie_goal, day_plan(user.id, today))


def _calorie_goal(user_id: str) -> float | None:
    goal = Goal.query.filter_by(user_id=user_id, type="calories", status="active").first()
    value = (goal.target_value or {}).get("value") if goal else None
    return float(value) if isinstance(value, (int, float)) else None


@blp.route("/trends/narrative")
class TrendsNarrative(MethodView):
    """The "read" tab (VitaChat Trends): an LLM-written reflection of the
    period's real stats. Deterministic (no network call) in mock mode —
    same offline-safe contract as chat extraction.
    """

    @jwt_required()
    @blp.arguments(NarrativeQuerySchema, location="query")
    @blp.response(200, NarrativeResponseSchema)
    def get(self, args):
        user = User.query.get_or_404(get_jwt_identity())
        return build_period_narrative(
            user.id, args["period"], args.get("start"), args.get("end"), today=local_today(user_tz_offset(user))
        )


@blp.route("/trends")
class Trends(MethodView):
    @jwt_required()
    @blp.arguments(TrendsQuerySchema, location="query")
    @blp.response(200, TrendsResponseSchema)
    def get(self, args):
        user = User.query.get_or_404(get_jwt_identity())
        user_id = user.id
        end = args.get("end") or local_today(user_tz_offset(user))
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
