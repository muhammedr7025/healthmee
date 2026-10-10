"""Two things that used to be wrong about *when* a log lands:

1. "Yesterday I had 2 chapati for dinner" was filed at the moment it was
   typed, not yesterday evening.
2. "Today" was the server's UTC day. For a user in IST that meant anything
   logged between midnight and 05:30 showed up under yesterday.
"""

from datetime import date, datetime, timedelta

from app.analytics.tasks import recompute_daily_aggregate
from app.common.localtime import local_today, to_local
from app.logging.models import LogEntry
from tests.conftest import LOCAL_TZ_OFFSET_MINUTES


def _local(dt_utc):
    return to_local(dt_utc, LOCAL_TZ_OFFSET_MINUTES)


def test_yesterdays_dinner_is_filed_yesterday_evening(auth_client, app):
    auth_client.post("/api/v1/chat/messages", json={"text": "Yesterday I had 2 chapati for dinner"})

    with app.app_context():
        entry = LogEntry.query.filter_by(type="food").one()
        when = _local(entry.timestamp)

    assert when.date() == local_today(LOCAL_TZ_OFFSET_MINUTES) - timedelta(days=1)
    assert (when.hour, when.minute) == (20, 0)


def test_explicit_clock_time_is_honoured(auth_client, app):
    auth_client.post("/api/v1/chat/messages", json={"text": "had an apple at 4pm"})

    with app.app_context():
        when = _local(LogEntry.query.filter_by(type="food").one().timestamp)
    assert (when.hour, when.minute) == (16, 0)


def test_undated_message_is_filed_now(auth_client, app):
    before = datetime.utcnow() - timedelta(minutes=1)
    auth_client.post("/api/v1/chat/messages", json={"text": "had an apple"})

    with app.app_context():
        entry = LogEntry.query.filter_by(type="food").one()
    assert entry.timestamp >= before


def test_last_nights_sleep_stays_on_today(auth_client, app):
    """A night's sleep is reported the morning after — it must not get
    shoved onto yesterday just because the word 'night' is in the message."""
    auth_client.post("/api/v1/chat/messages", json={"text": "slept 7 hours last night"})

    with app.app_context():
        when = _local(LogEntry.query.filter_by(type="sleep").one().timestamp)
    assert when.date() == local_today(LOCAL_TZ_OFFSET_MINUTES)


def test_yesterdays_entry_lands_in_yesterdays_aggregate_not_todays(auth_client, app):
    auth_client.post("/api/v1/chat/messages", json={"text": "yesterday I drank 2 glasses of water at 6pm"})
    me = auth_client.get("/api/v1/auth/me").get_json()
    today = local_today(LOCAL_TZ_OFFSET_MINUTES)
    yesterday = today - timedelta(days=1)

    with app.app_context():
        recompute_daily_aggregate.run(me["id"], today.isoformat(), LOCAL_TZ_OFFSET_MINUTES)
        recompute_daily_aggregate.run(me["id"], yesterday.isoformat(), LOCAL_TZ_OFFSET_MINUTES)

    assert auth_client.get("/api/v1/today").get_json()["water_ml"] == 0
    trends = auth_client.get(f"/api/v1/trends?start={yesterday.isoformat()}&end={yesterday.isoformat()}").get_json()
    assert trends["days"][0]["water_ml"] == 500


def test_today_follows_the_clients_timezone_not_the_servers(client):
    """Same account, two different offsets: 'today' must move with the
    client. Picks the two offsets that straddle the current UTC moment so
    the dates differ regardless of when the test runs."""
    client.post("/api/v1/auth/register", json={"email": "tz@example.com", "password": "password123"})
    token = client.post("/api/v1/auth/login", json={"email": "tz@example.com", "password": "password123"}).get_json()[
        "access_token"
    ]
    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {token}"

    client.environ_base["HTTP_X_TIMEZONE_OFFSET"] = "840"  # UTC+14
    east = client.get("/api/v1/today").get_json()["date"]
    client.environ_base["HTTP_X_TIMEZONE_OFFSET"] = "-720"  # UTC-12
    west = client.get("/api/v1/today").get_json()["date"]

    assert east == local_today(840).isoformat()
    assert west == local_today(-720).isoformat()
    assert date.fromisoformat(east) > date.fromisoformat(west)
