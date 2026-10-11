"""What the extraction model is told about the person it's talking to.

Without this the model saw only the message and the clock: it would
cheerfully confirm a meal containing a listed allergen, couldn't say "that's
your third coffee today", and guessed portions without knowing the cuisine.
Kept short (a few hundred tokens) and never echoed back to the user.
"""

from datetime import date

from app.analytics.models import DailyAggregate
from app.goals.models import Goal
from app.logging.models import LogEntry
from app.medical_profile.models import Allergy, MedicalProfile

GOAL_LABELS = {
    "weight": "weight",
    "blood_pressure": "blood pressure",
    "activity": "daily activity minutes",
    "calories": "daily calories",
    "water": "daily water",
}


def build_user_context(user, today: date) -> dict:
    profile = MedicalProfile.query.filter_by(user_id=user.id, is_current=True).first()
    allergies = [a.name for a in Allergy.query.filter_by(user_id=user.id).all()]
    goals = Goal.query.filter_by(user_id=user.id, status="active").all()
    aggregate = DailyAggregate.query.filter_by(user_id=user.id, date=today).first()
    recent = LogEntry.query.filter_by(user_id=user.id).order_by(LogEntry.timestamp.desc()).limit(3).all()

    return {
        "name": (user.full_name or "").strip().split(" ")[0] or None,
        "allergies": allergies,
        "conditions": list(profile.conditions or []) if profile else [],
        "medications": list(profile.medications or []) if profile else [],
        "goals": [_goal_text(g) for g in goals],
        "today": {
            "date": today.isoformat(),
            "kcal": round(aggregate.total_calories) if aggregate else 0,
            "water_l": round((aggregate.water_ml if aggregate else 0) / 1000, 1),
            "activity_min": round(aggregate.activity_minutes) if aggregate else 0,
            "sleep_h": aggregate.sleep_hours if aggregate else None,
            "log_count": aggregate.log_count if aggregate else 0,
        },
        "recent": [e.summary or e.type for e in recent],
        # Offset-based: the first users are in India; a locale preference can replace this later.
        "locale": "India" if (user.tz_offset_minutes or 0) == 330 else "their own country",
    }


def _goal_text(goal: Goal) -> str:
    target = goal.target_value or {}
    label = GOAL_LABELS.get(goal.type, goal.type)
    value = target.get("value")
    unit = target.get("unit", "")
    return f"{label} → {value} {unit}".strip() if value is not None else label
