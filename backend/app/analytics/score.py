"""Today's health score — a number the user can check the working of.

Every point comes from one visible component with its own cap and a
one-line explanation, and the total is rescaled to 100 over the components
that apply *today* (medicines only count when some are scheduled), so an
empty medicine list can't drag the score down. This is a habit score —
"how well did I look after myself today" — not a clinical measure, and the
UI says so.
"""

from app.analytics.models import DailyAggregate
from app.analytics.targets import ACTIVITY_GOAL_MINUTES_PER_DAY as ACTIVITY_GOAL_MINUTES, WATER_GOAL_ML

DEFAULT_CALORIE_GOAL = 2000


def compute_today_score(aggregate: DailyAggregate | None, calorie_goal: float | None, medicines: dict | None) -> dict:
    components: list[dict] = []

    def add(key: str, label: str, points: float, max_points: int, detail: str) -> None:
        components.append(
            {"key": key, "label": label, "points": round(min(points, max_points)), "max": max_points, "detail": detail}
        )

    logs = aggregate.log_count if aggregate else 0
    sleep = aggregate.sleep_hours if aggregate else None
    water = aggregate.water_ml if aggregate else 0.0
    activity = aggregate.activity_minutes if aggregate else 0.0
    calories = aggregate.total_calories if aggregate else 0.0
    mood = aggregate.mood_score if aggregate else None

    add(
        "logging",
        "Checked in",
        20 if logs >= 3 else (10 if logs >= 1 else 0),
        20,
        f"{logs} log{'s' if logs != 1 else ''} today — one earns 10, three or more earn 20",
    )

    if sleep is None:
        add("sleep", "Sleep", 0, 20, "Not logged yet — 7–9 hours earns the full 20")
    elif 7 <= sleep <= 9:
        add("sleep", "Sleep", 20, 20, f"{sleep:g}h — right in the 7–9h range")
    elif 6 <= sleep < 7 or 9 < sleep <= 10:
        add("sleep", "Sleep", 12, 20, f"{sleep:g}h — close to the 7–9h range")
    else:
        add("sleep", "Sleep", 5, 20, f"{sleep:g}h — well outside the 7–9h range")

    add("water", "Water", 15 * min(water / WATER_GOAL_ML, 1), 15, f"{water / 1000:.1f} L of a {WATER_GOAL_ML / 1000:.1f} L goal")
    add("activity", "Movement", 20 * min(activity / ACTIVITY_GOAL_MINUTES, 1), 20, f"{round(activity)} of {ACTIVITY_GOAL_MINUTES} active minutes")

    goal = calorie_goal or DEFAULT_CALORIE_GOAL
    if calories <= 0:
        add("food", "Food", 0, 10, "No meals logged yet — logging within 60–120% of your goal earns 10")
    elif 0.6 * goal <= calories <= 1.2 * goal:
        add("food", "Food", 10, 10, f"{round(calories)} kcal, within 60–120% of your {round(goal)} kcal goal")
    else:
        add("food", "Food", 5, 10, f"{round(calories)} kcal, outside 60–120% of your {round(goal)} kcal goal")

    if mood is None:
        add("mood", "Mood", 0, 5, "Not logged yet — any mood check-in earns up to 5")
    else:
        add("mood", "Mood", 5 * (mood / 5), 5, f"Mood {mood:.1f} of 5")

    if medicines and medicines.get("total"):
        taken, total = medicines["taken"], medicines["total"]
        add("medicines", "Medicines", 10 * taken / total, 10, f"{taken} of {total} doses taken")
    else:
        add("medicines", "Medicines", 0, 0, "No medicines scheduled — not counted today")

    achievable = sum(c["max"] for c in components)
    earned = sum(c["points"] for c in components)
    score = round(100 * earned / achievable) if achievable else 0
    return {
        "score": score,
        "earned": earned,
        "achievable": achievable,
        "components": components,
        "mascot": _mascot_for(score, logs),
    }


def _mascot_for(score: int, logs: int) -> str:
    """Never a sad face over a number: a quiet day gets curiosity, not blame."""
    if logs == 0:
        return "curious"
    if score >= 80:
        return "celebrating"
    if score >= 60:
        return "proud"
    if score >= 40:
        return "happy"
    return "encouraging"
