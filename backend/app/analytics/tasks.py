from datetime import date

from app.accounts.models import User
from app.analytics.models import DailyAggregate
from app.common.localtime import local_day_bounds_utc
from app.extensions import celery, db
from app.logging.models import LogEntry


@celery.task(name="analytics.recompute_daily_aggregate")
def recompute_daily_aggregate(user_id: str, date_iso: str, tz_offset_minutes: int | None = None) -> None:
    """`date_iso` is a *local* calendar day for this user. Callers with a
    request in hand pass the offset they used; anything else falls back to
    the last offset the user's app reported."""
    day = date.fromisoformat(date_iso)
    if tz_offset_minutes is None:
        user = User.query.get(user_id)
        tz_offset_minutes = (user.tz_offset_minutes if user else 0) or 0
    start, end = local_day_bounds_utc(day, tz_offset_minutes)

    entries = LogEntry.query.filter(
        LogEntry.user_id == user_id,
        LogEntry.timestamp >= start,
        LogEntry.timestamp < end,
    ).all()

    total_calories = 0.0
    activity_minutes = 0.0
    sleep_hours = None
    mood_scores = []
    water_ml = 0.0

    mood_scale = {"sad": 1, "stressed": 2, "tired": 2, "calm": 4, "happy": 5}

    for entry in entries:
        payload = entry.structured_payload or {}
        if entry.type == "food":
            total_calories += float(payload.get("estimated_calories") or 0)
        elif entry.type == "activity":
            activity_minutes += float(payload.get("duration_minutes") or 0)
            total_calories -= float(payload.get("estimated_calories_burned") or 0)
        elif entry.type == "sleep":
            sleep_hours = float(payload.get("hours") or 0)
        elif entry.type == "mood":
            score = mood_scale.get(payload.get("mood"))
            if score:
                mood_scores.append(score)
        elif entry.type == "hydration":
            water_ml += float(payload.get("volume_ml") or 0)

    aggregate = DailyAggregate.query.filter_by(user_id=user_id, date=day).first()
    if aggregate is None:
        aggregate = DailyAggregate(user_id=user_id, date=day)
        db.session.add(aggregate)

    aggregate.total_calories = max(total_calories, 0.0)
    aggregate.activity_minutes = activity_minutes
    aggregate.sleep_hours = sleep_hours
    aggregate.mood_score = sum(mood_scores) / len(mood_scores) if mood_scores else None
    aggregate.water_ml = water_ml
    aggregate.log_count = len(entries)

    db.session.commit()
