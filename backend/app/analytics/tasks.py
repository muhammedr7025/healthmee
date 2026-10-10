from collections.abc import Iterable
from datetime import date

from flask import current_app
from sqlalchemy.exc import IntegrityError

from app.accounts.models import User
from app.analytics.models import DailyAggregate
from app.common.localtime import local_day_bounds_utc
from app.extensions import celery, db
from app.logging.models import LogEntry


def recompute_days(user_id: str, days: Iterable[date], tz_offset_minutes: int | None) -> None:
    """Recompute the given local days right now, in the request.

    One small query per day, so the Today screen is correct the moment the
    chat response lands — no worker lag to race against, and nothing that
    can fail because Redis is down after the entry was already committed.
    The Celery task below stays for scheduled reconciliation. A recompute
    failure is logged, never raised: the entry is saved, the totals catch
    up on the next write.
    """
    for day in days:
        try:
            recompute_daily_aggregate.run(user_id, day.isoformat(), tz_offset_minutes)
        except IntegrityError:
            # Two requests created this day's row at the same moment; the other
            # one won, so redo the numbers on top of it.
            db.session.rollback()
            try:
                recompute_daily_aggregate.run(user_id, day.isoformat(), tz_offset_minutes)
            except Exception:
                db.session.rollback()
                current_app.logger.exception("aggregate recompute failed twice for %s on %s", user_id, day)
        except Exception:
            db.session.rollback()
            current_app.logger.exception("aggregate recompute failed for %s on %s", user_id, day)


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

    entries = (
        LogEntry.query.filter(
            LogEntry.user_id == user_id,
            LogEntry.timestamp >= start,
            LogEntry.timestamp < end,
        )
        .order_by(LogEntry.timestamp.asc())
        .all()
    )

    total_calories = 0.0
    activity_minutes = 0.0
    sleep_hours = None
    mood_scores = []
    water_ml = 0.0
    vitals = _VitalsRollup()

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
        elif entry.type == "vital":
            vitals.add(payload)

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
    vitals.apply(aggregate)

    db.session.commit()


_LB_TO_KG = 0.45359237
_MMOL_L_TO_MG_DL = 18.0


def _num(value) -> float | None:
    try:
        return float(value) if value is not None else None
    except (TypeError, ValueError):
        return None


def _mean(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


class _VitalsRollup:
    """Collapses a day's vital readings into one number per measure for the
    Trends line. Weight is the last reading of the day (you don't average
    weigh-ins); blood pressure and heart rate are averaged (one high clinic
    reading shouldn't define the day); glucose prefers the fasting reading
    when there is one, since that's the number people and their doctors
    actually track, else the day's average. Units are normalised to kg and
    mg/dL so the chart has one axis — entries are given in order, so "last"
    means latest.
    """

    def __init__(self) -> None:
        self.weight_kg: float | None = None
        self.systolic: list[float] = []
        self.diastolic: list[float] = []
        self.glucose: list[float] = []
        self.fasting_glucose: list[float] = []
        self.heart_rate: list[float] = []

    def add(self, payload: dict) -> None:
        value = _num(payload.get("value"))
        if value is None:
            return
        kind = payload.get("kind")
        unit = (payload.get("unit") or "").lower()

        if kind == "weight":
            self.weight_kg = value * _LB_TO_KG if unit in ("lb", "lbs", "pound", "pounds") else value
        elif kind == "blood_pressure":
            self.systolic.append(value)
            diastolic = _num(payload.get("diastolic"))
            if diastolic is not None:
                self.diastolic.append(diastolic)
        elif kind == "blood_glucose":
            # A reading under 30 can only be mmol/L (a 25 mg/dL person is not texting).
            mg_dl = value * _MMOL_L_TO_MG_DL if unit.startswith("mmol") or value < 30 else value
            (self.fasting_glucose if payload.get("context") == "fasting" else self.glucose).append(mg_dl)
        elif kind == "heart_rate":
            self.heart_rate.append(value)

    def apply(self, aggregate: DailyAggregate) -> None:
        aggregate.weight_kg = self.weight_kg
        aggregate.systolic = _mean(self.systolic)
        aggregate.diastolic = _mean(self.diastolic)
        glucose = _mean(self.fasting_glucose)
        aggregate.glucose_mg_dl = glucose if glucose is not None else _mean(self.glucose)
        aggregate.heart_rate_bpm = _mean(self.heart_rate)
