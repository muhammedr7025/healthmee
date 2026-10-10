"""Reminders, evaluated in each user's *local* time.

Three triggers, all idempotent through PushLog dedupe keys so the beat can
run every few minutes:
- quiet nudge: nothing logged by 20:00 local;
- streak milestones at 7/14/30 days;
- medication reminders: a dose slot has come due in the last few minutes
  and hasn't been marked taken or skipped.

Users who never opened Settings have no NotificationPreference row; the
model's defaults (everything on) apply to them too.
"""

from datetime import date, datetime, timedelta, timezone
from types import SimpleNamespace

from app.accounts.models import User
from app.analytics.models import DailyAggregate
from app.common.localtime import to_local
from app.extensions import celery
from app.medications.models import MedicationDose, MedicationSchedule
from app.medications.service import due_slots
from app.notifications.models import NotificationPreference
from app.push import service

QUIET_NUDGE_LOCAL_HOUR = 20
MEDICATION_WINDOW = timedelta(minutes=15)
MILESTONES = (7, 14, 30)

_DEFAULT_PREFS = SimpleNamespace(medication_reminders=True, quiet_nudges=True, streak_milestones=True)


@celery.task(name="push.check_reminders")
def check_reminders() -> None:
    now_utc = datetime.now(timezone.utc)
    prefs_by_user = {p.user_id: p for p in NotificationPreference.query.all()}

    for user in User.query.all():
        prefs = prefs_by_user.get(user.id, _DEFAULT_PREFS)
        local_now = to_local(now_utc, user.tz_offset_minutes or 0)
        today = local_now.date()

        if prefs.quiet_nudges and local_now.hour >= QUIET_NUDGE_LOCAL_HOUR:
            _maybe_send_quiet_nudge(user.id, today)

        if prefs.streak_milestones:
            _maybe_send_streak_milestone(user.id, today)

        if prefs.medication_reminders:
            _maybe_send_medication_reminders(user.id, local_now)


def _maybe_send_quiet_nudge(user_id: str, today: date) -> None:
    todays_row = DailyAggregate.query.filter_by(user_id=user_id, date=today).first()
    if todays_row and todays_row.log_count > 0:
        return  # already logged something today — no nudge needed

    service.send(
        user_id=user_id,
        kind="quiet_nudge",
        title="MeMe",
        body="Haven't heard from you today — even a quick line keeps the picture accurate.",
        dedupe_key=f"quiet_nudge:{today.isoformat()}",
    )


def _maybe_send_streak_milestone(user_id: str, today: date) -> None:
    streak = _compute_streak(user_id, today)
    if streak not in MILESTONES:
        return

    service.send(
        user_id=user_id,
        kind="streak_milestone",
        title="MeMe",
        body=f"{streak} days logging in a row — nice consistency.",
        dedupe_key=f"streak_milestone:{streak}",
    )


def _maybe_send_medication_reminders(user_id: str, local_now: datetime) -> None:
    """One reminder per due slot, within MEDICATION_WINDOW of its time, and
    only while the dose is still unmarked."""
    today = local_now.date()
    schedules = MedicationSchedule.query.filter_by(user_id=user_id, active=True).all()
    if not schedules:
        return
    marked = {
        (d.schedule_id, d.scheduled_time)
        for d in MedicationDose.query.filter_by(user_id=user_id, scheduled_date=today).all()
    }
    for schedule in schedules:
        for slot in due_slots(schedule, today):
            hours, minutes = (int(part) for part in slot.split(":"))
            due = local_now.replace(hour=hours, minute=minutes, second=0, microsecond=0)
            if not (due <= local_now <= due + MEDICATION_WINDOW):
                continue
            if (schedule.id, slot) in marked:
                continue
            dose = f" ({schedule.dose})" if schedule.dose else ""
            service.send(
                user_id=user_id,
                kind="medication",
                title="MeMe",
                body=f"Time for {schedule.name}{dose}. Tap Taken on Today once you've had it.",
                dedupe_key=f"med:{schedule.id}:{today.isoformat()}:{slot}",
            )


def _compute_streak(user_id: str, today: date) -> int:
    lookback_start = today - timedelta(days=max(MILESTONES) + 5)
    rows = {
        r.date: r.log_count
        for r in DailyAggregate.query.filter(
            DailyAggregate.user_id == user_id, DailyAggregate.date >= lookback_start, DailyAggregate.date <= today
        ).all()
    }
    streak = 0
    day = today
    while rows.get(day, 0) > 0:
        streak += 1
        day -= timedelta(days=1)
    return streak
