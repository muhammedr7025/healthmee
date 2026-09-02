from datetime import date, timedelta


def test_register_and_list_devices(auth_client):
    resp = auth_client.post("/api/v1/push/devices", json={"token": "fcm-token-1", "platform": "android"})
    assert resp.status_code == 201

    resp = auth_client.get("/api/v1/push/devices")
    assert len(resp.get_json()) == 1
    assert resp.get_json()[0]["platform"] == "android"


def test_registering_same_token_twice_updates_not_duplicates(auth_client):
    auth_client.post("/api/v1/push/devices", json={"token": "fcm-token-1", "platform": "android"})
    auth_client.post("/api/v1/push/devices", json={"token": "fcm-token-1", "platform": "ios"})

    resp = auth_client.get("/api/v1/push/devices")
    assert len(resp.get_json()) == 1
    assert resp.get_json()[0]["platform"] == "ios"


def test_delete_device(auth_client):
    resp = auth_client.post("/api/v1/push/devices", json={"token": "fcm-token-1"})
    device_id = resp.get_json()["id"]

    resp = auth_client.delete(f"/api/v1/push/devices/{device_id}")
    assert resp.status_code == 204
    assert auth_client.get("/api/v1/push/devices").get_json() == []


def test_quiet_nudge_fires_when_no_log_today_and_evening(app, auth_client):
    from datetime import datetime, timezone

    from app.push import scheduler

    me = auth_client.get("/api/v1/auth/me").get_json()
    auth_client.patch("/api/v1/notification-preferences", json={"quiet_nudges": True})

    with app.app_context():
        evening = datetime(2026, 9, 2, 21, 0, tzinfo=timezone.utc)
        scheduler._maybe_send_quiet_nudge(me["id"], evening.date())

    resp = auth_client.get("/api/v1/push/log")
    body = resp.get_json()
    assert len(body) == 1
    assert body[0]["kind"] == "quiet_nudge"
    assert body[0]["delivery_mode"] == "mock"


def test_quiet_nudge_does_not_fire_twice_same_day(app, auth_client):
    from app.push import scheduler

    me = auth_client.get("/api/v1/auth/me").get_json()
    with app.app_context():
        scheduler._maybe_send_quiet_nudge(me["id"], date(2026, 9, 2))
        scheduler._maybe_send_quiet_nudge(me["id"], date(2026, 9, 2))

    resp = auth_client.get("/api/v1/push/log")
    assert len(resp.get_json()) == 1


def test_quiet_nudge_skipped_if_already_logged_today(app, auth_client):
    from app.extensions import db
    from app.analytics.models import DailyAggregate
    from app.push import scheduler

    me = auth_client.get("/api/v1/auth/me").get_json()
    today = date(2026, 9, 2)
    with app.app_context():
        db.session.add(DailyAggregate(user_id=me["id"], date=today, log_count=2))
        db.session.commit()
        scheduler._maybe_send_quiet_nudge(me["id"], today)

    assert auth_client.get("/api/v1/push/log").get_json() == []


def test_streak_milestone_fires_at_seven_days(app, auth_client):
    from app.extensions import db
    from app.analytics.models import DailyAggregate
    from app.push import scheduler

    me = auth_client.get("/api/v1/auth/me").get_json()
    today = date(2026, 9, 2)
    with app.app_context():
        for i in range(7):
            db.session.add(DailyAggregate(user_id=me["id"], date=today - timedelta(days=i), log_count=1))
        db.session.commit()
        scheduler._maybe_send_streak_milestone(me["id"], today)

    resp = auth_client.get("/api/v1/push/log")
    body = resp.get_json()
    assert len(body) == 1
    assert body[0]["kind"] == "streak_milestone"
    assert "7" in body[0]["body"]


def test_streak_milestone_does_not_refire_same_streak(app, auth_client):
    from app.extensions import db
    from app.analytics.models import DailyAggregate
    from app.push import scheduler

    me = auth_client.get("/api/v1/auth/me").get_json()
    today = date(2026, 9, 2)
    with app.app_context():
        for i in range(7):
            db.session.add(DailyAggregate(user_id=me["id"], date=today - timedelta(days=i), log_count=1))
        db.session.commit()
        scheduler._maybe_send_streak_milestone(me["id"], today)
        scheduler._maybe_send_streak_milestone(me["id"], today)

    assert len(auth_client.get("/api/v1/push/log").get_json()) == 1
