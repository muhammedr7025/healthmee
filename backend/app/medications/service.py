from datetime import date

from app.medications.models import MedicationDose, MedicationSchedule


def due_slots(schedule: MedicationSchedule, day: date) -> list[str]:
    if not schedule.active:
        return []
    if schedule.days_of_week and day.weekday() not in schedule.days_of_week:
        return []
    return sorted(schedule.times or [])


def day_plan(user_id: str, day: date) -> dict:
    """Every dose due on `day` (a local calendar day) with its status —
    "pending" until marked. Adherence is taken ÷ due, None when nothing is
    scheduled so the score can leave medicines out rather than count 0."""
    schedules = (
        MedicationSchedule.query.filter_by(user_id=user_id, active=True)
        .order_by(MedicationSchedule.created_at.asc())
        .all()
    )
    marks = {
        (d.schedule_id, d.scheduled_time): d
        for d in MedicationDose.query.filter_by(user_id=user_id, scheduled_date=day).all()
    }

    items = []
    for schedule in schedules:
        for slot in due_slots(schedule, day):
            mark = marks.get((schedule.id, slot))
            items.append(
                {
                    "schedule_id": schedule.id,
                    "name": schedule.name,
                    "dose": schedule.dose,
                    "time": slot,
                    "status": mark.status if mark else "pending",
                    "marked_at": mark.marked_at.isoformat() if mark else None,
                }
            )
    items.sort(key=lambda item: (item["time"], item["name"]))

    total = len(items)
    taken = sum(1 for item in items if item["status"] == "taken")
    return {
        "date": day.isoformat(),
        "items": items,
        "taken": taken,
        "total": total,
        "adherence_pct": round(100 * taken / total) if total else None,
    }
