"""Builds the Trends "read" period summary — real stats from DailyAggregate,
turned into prose via the pluggable LLM provider's narrate() (deterministic
fallback in mock mode, exactly like extraction).
"""

import hashlib
import json
from datetime import date, timedelta

from app.analytics.models import DailyAggregate, NarrativeCache
from app.common.llm import get_llm_provider
from app.extensions import db

PERIODS = {
    "today": 1,
    "week": 7,
    "month": 30,
}


def build_period_narrative(user_id: str, period: str, custom_start: date | None, custom_end: date | None) -> dict:
    end = custom_end or date.today()
    if period == "custom" and custom_start:
        start = custom_start
    else:
        start = end - timedelta(days=PERIODS.get(period, 7) - 1)

    days = (
        DailyAggregate.query.filter(
            DailyAggregate.user_id == user_id,
            DailyAggregate.date >= start,
            DailyAggregate.date <= end,
        )
        .order_by(DailyAggregate.date.asc())
        .all()
    )

    stats = _compute_stats(days, start, end)
    summary = _narrate_cached(user_id, period, stats)

    return {
        "period": period,
        "start": start.isoformat(),
        "end": end.isoformat(),
        "summary": summary,
        "stats": stats,
        "wins": _wins(stats),
        "watch": _watch(stats),
    }


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


def _compute_stats(days: list[DailyAggregate], start: date, end: date) -> dict:
    days_total = (end - start).days + 1
    logged_days = [d for d in days if d.log_count > 0]

    sleep_values = [d.sleep_hours for d in days if d.sleep_hours is not None]
    mood_values = [d.mood_score for d in days if d.mood_score is not None]

    return {
        "days_total": days_total,
        "days_logged": len(logged_days),
        "log_count": sum(d.log_count for d in days),
        "avg_sleep": sum(sleep_values) / len(sleep_values) if sleep_values else None,
        "avg_mood": sum(mood_values) / len(mood_values) if mood_values else None,
        "total_activity_minutes": sum(d.activity_minutes for d in days),
        "avg_calories": sum(d.total_calories for d in days) / len(days) if days else None,
    }


def _build_prompt(stats: dict) -> str:
    return (
        "Write a short, warm, non-clinical summary of this person's health journal for the period. "
        f"They logged something on {stats['days_logged']} of {stats['days_total']} days "
        f"({stats['log_count']} entries). "
        + (f"Average sleep was {stats['avg_sleep']:.1f} hours a night. " if stats["avg_sleep"] is not None else "")
        + (f"Average mood score was {stats['avg_mood']:.1f} out of 5. " if stats["avg_mood"] is not None else "")
        + f"Total activity was {round(stats['total_activity_minutes'])} minutes. "
        "Do not diagnose or give medical advice — just reflect the pattern back to them."
    )


def _wins(stats: dict) -> list[str]:
    wins = []
    if stats["avg_sleep"] is not None and stats["avg_sleep"] >= 7:
        wins.append(f"Averaging {stats['avg_sleep']:.1f}h of sleep a night — right in a healthy range.")
    if stats["days_total"] and stats["days_logged"] / stats["days_total"] >= 0.7:
        wins.append(f"Logged {stats['days_logged']} of {stats['days_total']} days — a strong habit.")
    if stats["avg_mood"] is not None and stats["avg_mood"] >= 3.5:
        wins.append("Mood has trended positive across this period.")
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
