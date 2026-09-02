"""The two reminder triggers that have real, well-defined data to fire on.
Medication-time reminders are deliberately NOT implemented here: medications
are stored as free-text strings (MedicalProfile.medications), with no time
data attached, so there's nothing to schedule against without a data-model
change. The Settings toggle exists for when that lands; until then this
scheduler only handles quiet-nudge and streak-milestone.
"""

from datetime import date, datetime, timedelta, timezone

from app.accounts.models import User
from app.analytics.models import DailyAggregate
from app.extensions import celery, db
from app.notifications.models import NotificationPreference
from app.push import service

QUIET_NUDGE_HOUR_UTC = 20  # fires once the day has reached this UTC hour
MILESTONES = (7, 14, 30)


@celery.task(name="push.check_reminders")
def check_reminders() -> None:
    now = datetime.now(timezone.utc)
    today = now.date()

    prefs_by_user = {p.user_id: p for p in NotificationPreference.query.all()}
    for user in User.query.all():
        prefs = prefs_by_user.get(user.id)
        if prefs is None:
            continue  # no row yet = defaults, but nothing to act on until they've opened Settings once

        if prefs.quiet_nudges and now.hour >= QUIET_NUDGE_HOUR_UTC:
            _maybe_send_quiet_nudge(user.id, today)

        if prefs.streak_milestones:
            _maybe_send_streak_milestone(user.id, today)


def _maybe_send_quiet_nudge(user_id: str, today: date) -> None:
    todays_row = DailyAggregate.query.filter_by(user_id=user_id, date=today).first()
    if todays_row and todays_row.log_count > 0:
        return  # already logged something today — no nudge needed

    service.send(
        user_id=user_id,
        kind="quiet_nudge",
        title="Mo",
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
        title="Mo",
        body=f"{streak} days logging in a row — nice consistency.",
        dedupe_key=f"streak_milestone:{streak}",
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
