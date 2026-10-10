"""Builds the Trends "read" period summary — real stats from DailyAggregate,
turned into prose via the pluggable LLM provider's narrate() (deterministic
fallback in mock mode, exactly like extraction) — plus everything the app
renders around that prose: how this period compares with the one before
(deltas, momentum), achievements, readings worth showing a doctor, and what
to try next. Those are rules, not the model, so they're identical offline
and never invent a number.
"""

import hashlib
import json
from datetime import date, timedelta

from app.analytics.models import DailyAggregate, NarrativeCache
from app.analytics.targets import ACTIVITY_GOAL_MINUTES_PER_WEEK, WATER_GOAL_ML
from app.common.llm import get_llm_provider
from app.extensions import db

PERIODS = {
    "today": 1,
    "week": 7,
    "month": 30,
}


def build_period_narrative(
    user_id: str, period: str, custom_start: date | None, custom_end: date | None, today: date | None = None
) -> dict:
    end = custom_end or today or date.today()
    if period == "custom" and custom_start:
        start = custom_start
    else:
        start = end - timedelta(days=PERIODS.get(period, 7) - 1)

    length = (end - start).days + 1
    previous_end = start - timedelta(days=1)
    previous_start = previous_end - timedelta(days=length - 1)

    days = _days_between(user_id, start, end)
    previous_days = _days_between(user_id, previous_start, previous_end)

    stats = _compute_stats(days, start, end)
    previous = _compute_stats(previous_days, previous_start, previous_end)
    deltas = _deltas(stats, previous)
    summary = _narrate_cached(user_id, period, stats)

    return {
        "period": period,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "summary": summary,
        "stats": stats,
        "previous": previous,
        "deltas": deltas,
        "momentum": _momentum(stats, previous, deltas),
        "wins": _wins(stats),
        "watch": _watch(stats),
        "achievements": _achievements(stats),
        "risks": _risks(stats),
        "recommendations": _recommendations(stats, deltas),
    }


def _days_between(user_id: str, start: date, end: date) -> list[DailyAggregate]:
    return (
        DailyAggregate.query.filter(
            DailyAggregate.user_id == user_id,
            DailyAggregate.date >= start,
            DailyAggregate.date <= end,
        )
        .order_by(DailyAggregate.date.asc())
        .all()
    )


def _narrate_cached(user_id: str, period: str, stats: dict) -> str:
    """Reuse a previous summary while the underlying numbers are unchanged.

    Opening the Trends tab refetches this, and on the free Gemini tier
    (500 requests/day) regenerating identical prose every time someone taps
    between tabs would burn the daily quota for nothing. Keying the cache on
    a hash of the stats means it refreshes exactly when there's something new
    to say, with no staleness window to tune.
    """
    fingerprint = hashlib.sha256(
        json.dumps({"period": period, **stats}, sort_keys=True, default=str).encode()
    ).hexdigest()

    cached = NarrativeCache.query.filter_by(user_id=user_id, period=period).first()
    if cached is not None and cached.stats_fingerprint == fingerprint:
        return cached.summary

    summary = get_llm_provider().narrate(_build_prompt(stats), stats)

    if cached is None:
        cached = NarrativeCache(user_id=user_id, period=period)
        db.session.add(cached)
    cached.stats_fingerprint = fingerprint
    cached.summary = summary
    db.session.commit()
    return summary


def _mean(values: list[float]) -> float | None:
    return sum(values) / len(values) if values else None


def _compute_stats(days: list[DailyAggregate], start: date, end: date) -> dict:
    days_total = (end - start).days + 1
    logged_days = [d for d in days if d.log_count > 0]

    sleep_values = [d.sleep_hours for d in days if d.sleep_hours is not None]
    mood_values = [d.mood_score for d in days if d.mood_score is not None]
    weights = [d.weight_kg for d in days if d.weight_kg is not None]
    vitals_days = [
        d for d in days if any(v is not None for v in (d.weight_kg, d.systolic, d.glucose_mg_dl, d.heart_rate_bpm))
    ]

    return {
        "days_total": days_total,
        "days_logged": len(logged_days),
        "log_count": sum(d.log_count for d in days),
        "avg_sleep": _mean(sleep_values),
        "sleep_days": len(sleep_values),
        "avg_mood": _mean(mood_values),
        "total_activity_minutes": sum(d.activity_minutes for d in days),
        "avg_calories": _mean([d.total_calories for d in days]) if days else None,
        "avg_water_ml": _mean([d.water_ml for d in logged_days]) if logged_days else None,
        "avg_weight_kg": _mean(weights),
        "weight_change_kg": (weights[-1] - weights[0]) if len(weights) >= 2 else None,
        "avg_systolic": _mean([d.systolic for d in days if d.systolic is not None]),
        "avg_diastolic": _mean([d.diastolic for d in days if d.diastolic is not None]),
        "avg_glucose_mg_dl": _mean([d.glucose_mg_dl for d in days if d.glucose_mg_dl is not None]),
        "avg_heart_rate_bpm": _mean([d.heart_rate_bpm for d in days if d.heart_rate_bpm is not None]),
        "vitals_days": len(vitals_days),
    }


_DELTA_KEYS = (
    "days_logged",
    "avg_sleep",
    "avg_mood",
    "total_activity_minutes",
    "avg_water_ml",
    "avg_weight_kg",
    "avg_systolic",
    "avg_glucose_mg_dl",
)


def _deltas(stats: dict, previous: dict) -> dict:
    """This period minus the one before, per stat; None where either side
    has nothing to compare."""
    out = {}
    for key in _DELTA_KEYS:
        now, before = stats.get(key), previous.get(key)
        comparable = now is not None and before is not None and (key == "days_logged" or previous["days_logged"] > 0)
        out[key] = (now - before) if comparable else None
    return out


def _momentum(stats: dict, previous: dict, deltas: dict) -> dict:
    """Direction of travel versus the previous period, from the habits that
    are under the user's control (logging, sleep, movement, water)."""
    if stats["days_logged"] == 0:
        return {"label": "starting", "detail": "Nothing logged yet this period."}
    if previous["days_logged"] == 0:
        return {"label": "starting", "detail": "First period with logs — next time there'll be something to compare."}

    score = 0
    if deltas["days_logged"] is not None:
        score += 1 if deltas["days_logged"] > 0 else (-1 if deltas["days_logged"] < 0 else 0)
    if deltas["avg_sleep"] is not None and abs(deltas["avg_sleep"]) >= 0.3:
        score += 1 if deltas["avg_sleep"] > 0 else -1
    if deltas["total_activity_minutes"] is not None and abs(deltas["total_activity_minutes"]) >= 20:
        score += 1 if deltas["total_activity_minutes"] > 0 else -1
    if deltas["avg_water_ml"] is not None and abs(deltas["avg_water_ml"]) >= 200:
        score += 1 if deltas["avg_water_ml"] > 0 else -1

    if score >= 2:
        return {"label": "building", "detail": "More of the good habits than last period."}
    if score <= -2:
        return {"label": "slipping", "detail": "A few habits dipped versus last period — nothing a steady week won't fix."}
    return {"label": "steady", "detail": "About the same as last period."}


def _build_prompt(stats: dict) -> str:
    return (
        "Write a short, warm, non-clinical summary of this person's health journal for the period. "
        f"They logged something on {stats['days_logged']} of {stats['days_total']} days "
        f"({stats['log_count']} entries). "
        + (f"Average sleep was {stats['avg_sleep']:.1f} hours a night. " if stats["avg_sleep"] is not None else "")
        + (f"Average mood score was {stats['avg_mood']:.1f} out of 5. " if stats["avg_mood"] is not None else "")
        + f"Total activity was {round(stats['total_activity_minutes'])} minutes. "
        + (f"Water averaged {stats['avg_water_ml'] / 1000:.1f} litres a day. " if stats["avg_water_ml"] else "")
        + (f"Weight averaged {stats['avg_weight_kg']:.1f} kg. " if stats["avg_weight_kg"] is not None else "")
        + (
            f"Blood pressure averaged {stats['avg_systolic']:.0f}/{stats['avg_diastolic']:.0f}. "
            if stats["avg_systolic"] is not None and stats["avg_diastolic"] is not None
            else ""
        )
        + "Do not diagnose or give medical advice — just reflect the pattern back to them."
    )


def _wins(stats: dict) -> list[str]:
    wins = []
    if stats["avg_sleep"] is not None and stats["avg_sleep"] >= 7:
        wins.append(f"Averaging {stats['avg_sleep']:.1f}h of sleep a night — right in a healthy range.")
    if stats["days_total"] and stats["days_logged"] / stats["days_total"] >= 0.7:
        wins.append(f"Logged {stats['days_logged']} of {stats['days_total']} days — a strong habit.")
    if stats["avg_mood"] is not None and stats["avg_mood"] >= 3.5:
        wins.append("Mood has trended positive across this period.")
    if stats["avg_water_ml"] and stats["avg_water_ml"] >= WATER_GOAL_ML:
        wins.append(f"Water averaged {stats['avg_water_ml'] / 1000:.1f} L a day — hydration's on track.")
    return wins


def _watch(stats: dict) -> list[str]:
    watch = []
    if stats["avg_sleep"] is not None and stats["avg_sleep"] < 6:
        watch.append(f"Sleep averaged {stats['avg_sleep']:.1f}h a night — on the short side.")
    if stats["avg_mood"] is not None and stats["avg_mood"] < 2.5:
        watch.append("Mood has skewed low across this period.")
    if stats["days_total"] and stats["days_logged"] / stats["days_total"] < 0.3:
        watch.append("Only a few days logged — patterns will get clearer with more.")
    return watch


def _activity_goal(stats: dict) -> float:
    return ACTIVITY_GOAL_MINUTES_PER_WEEK * stats["days_total"] / 7


def _achievements(stats: dict) -> list[str]:
    out = []
    if stats["days_total"] >= 3 and stats["days_logged"] == stats["days_total"]:
        out.append(f"Logged every one of the {stats['days_total']} days.")
    if stats["days_total"] >= 7 and stats["total_activity_minutes"] >= _activity_goal(stats):
        out.append(f"{round(stats['total_activity_minutes'])} active minutes — past the 150-a-week mark.")
    if stats["sleep_days"] >= 3 and stats["avg_sleep"] is not None and 7 <= stats["avg_sleep"] <= 9:
        out.append(f"Sleep stayed in the 7–9h range across {stats['sleep_days']} nights.")
    if stats["vitals_days"] >= 3:
        out.append(f"Tracked a vital reading on {stats['vitals_days']} days.")
    return out


def _risks(stats: dict) -> list[str]:
    """Readings outside the usual ranges, worded as something to take to a
    doctor — never as a diagnosis. Thresholds are the common screening
    cut-offs (BP 140/90, fasting glucose 100 / 126)."""
    out = []
    systolic, diastolic = stats["avg_systolic"], stats["avg_diastolic"]
    if systolic is not None and (systolic >= 140 or (diastolic is not None and diastolic >= 90)):
        reading = f"{systolic:.0f}/{diastolic:.0f}" if diastolic is not None else f"{systolic:.0f}"
        out.append(f"Blood pressure averaged {reading} — above the usual range; worth showing your doctor.")
    glucose = stats["avg_glucose_mg_dl"]
    if glucose is not None and glucose >= 126:
        out.append(f"Blood sugar averaged {glucose:.0f} mg/dL — above the usual range; worth a conversation with your doctor.")
    elif glucose is not None and glucose >= 100:
        out.append(f"Blood sugar averaged {glucose:.0f} mg/dL — a little above the usual fasting range; keep an eye on it.")
    change = stats["weight_change_kg"]
    if change is not None and abs(change) >= 2:
        direction = "up" if change > 0 else "down"
        out.append(f"Weight moved {direction} {abs(change):.1f} kg over the period — a quick change worth mentioning to your doctor.")
    if stats["sleep_days"] >= 3 and stats["avg_sleep"] is not None and stats["avg_sleep"] < 6:
        out.append(f"Sleep averaged {stats['avg_sleep']:.1f}h — consistently short; worth raising if it continues.")
    return out


def _recommendations(stats: dict, deltas: dict) -> list[str]:
    """At most three concrete, small next steps, from what's furthest from
    its goal."""
    out = []
    if stats["days_logged"] == 0:
        return ["Tell MeMe one thing today — even \"had lunch\" starts the picture."]

    if stats["avg_water_ml"] is not None and stats["avg_water_ml"] < 100:
        out.append('Tell MeMe when you drink — even "had a glass of water" counts — nothing\'s been tracked this period.')
    elif stats["avg_water_ml"] is not None and stats["avg_water_ml"] < WATER_GOAL_ML:
        out.append(
            f"Add one more glass of water a day — you averaged {stats['avg_water_ml'] / 1000:.1f} L "
            f"against a {WATER_GOAL_ML / 1000:.1f} L goal."
        )
    if stats["days_total"] >= 7 and stats["total_activity_minutes"] < _activity_goal(stats):
        short = round(_activity_goal(stats) - stats["total_activity_minutes"])
        out.append(f"A 20-minute walk on three days would close the {short}-minute gap to 150 active minutes a week.")
    if stats["avg_sleep"] is not None and stats["avg_sleep"] < 7:
        out.append("Try a consistent lights-out time — your average is under the 7h mark.")
    if stats["days_total"] and stats["days_logged"] / stats["days_total"] < 0.7:
        out.append("Log something on more days — one line a day keeps the trends honest.")
    if deltas.get("avg_mood") is not None and deltas["avg_mood"] <= -0.5:
        out.append("Mood dipped versus last period — a short note on what's been going on helps MeMe spot the pattern.")
    return out[:3]
