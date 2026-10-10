"""User-local calendar days.

The server runs in UTC; the user is wherever they are (IST, +5:30, for the
first users). "Today" has to mean *their* today — bucketing by the server's
clock put anything logged between midnight and 05:30 IST on yesterday's
Today screen. The app sends its UTC offset on every request
(X-Timezone-Offset, minutes east of UTC) and the last-seen value is kept on
the user, so background tasks — which have no request to read — agree with
the API about which day an entry belongs to.
"""

from datetime import date, datetime, time, timedelta, timezone

from flask import has_request_context, request

HEADER = "X-Timezone-Offset"
_MAX_OFFSET_MINUTES = 14 * 60


def request_tz_offset(default: int = 0) -> int | None:
    """The offset the client sent, or `default` when there's no request or
    no (valid) header. Returns None only when explicitly asked to by passing
    default=None, so callers can tell "absent" from "UTC"."""
    if not has_request_context():
        return default
    raw = request.headers.get(HEADER)
    if raw is None:
        return default
    try:
        minutes = int(raw)
    except ValueError:
        return default
    return max(-_MAX_OFFSET_MINUTES, min(_MAX_OFFSET_MINUTES, minutes))


def user_tz_offset(user) -> int:
    """The offset to use for this user right now: the request's header if it
    sent one (remembering it on the user when it changed), else the last
    one we saw, else UTC."""
    from app.extensions import db

    sent = request_tz_offset(default=None)
    if sent is not None and sent != (user.tz_offset_minutes or 0):
        user.tz_offset_minutes = sent
        db.session.commit()
    if sent is not None:
        return sent
    return user.tz_offset_minutes or 0


def to_local(dt_utc: datetime, offset_minutes: int) -> datetime:
    """Naive local wall-clock time for a UTC datetime (naive or aware)."""
    if dt_utc.tzinfo is not None:
        dt_utc = dt_utc.astimezone(timezone.utc).replace(tzinfo=None)
    return dt_utc + timedelta(minutes=offset_minutes)


def to_utc(dt_local: datetime, offset_minutes: int) -> datetime:
    """Naive UTC for a naive local wall-clock time — the form LogEntry.timestamp
    is stored in."""
    return dt_local.replace(tzinfo=None) - timedelta(minutes=offset_minutes)


def local_now(offset_minutes: int) -> datetime:
    return to_local(datetime.now(timezone.utc), offset_minutes)


def local_today(offset_minutes: int) -> date:
    return local_now(offset_minutes).date()


def local_date_of(dt_utc: datetime, offset_minutes: int) -> date:
    return to_local(dt_utc, offset_minutes).date()


def local_day_bounds_utc(day: date, offset_minutes: int) -> tuple[datetime, datetime]:
    """[start, end) in naive UTC for one local calendar day."""
    start = to_utc(datetime.combine(day, time.min), offset_minutes)
    return start, start + timedelta(days=1)
