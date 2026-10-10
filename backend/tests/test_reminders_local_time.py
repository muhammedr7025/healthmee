"""Reminders fire on the user's clock, and medicines actually get one."""

from datetime import datetime, timezone

from app.accounts.models import User
from app.extensions import db
from app.push import scheduler


def _set_offset(app, user_id, minutes):
    with app.app_context():
        user = User.query.get(user_id)
        user.tz_offset_minutes = minutes
        db.session.commit()


def test_quiet_nudge_uses_the_users_local_evening(app, auth_client, monkeypatch):
    me = auth_client.get("/api/v1/auth/me").get_json()
    _set_offset(app, me["id"], 330)  # IST

    class _Clock(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 10, 11, 9, 0, tzinfo=timezone.utc)  # 14:30 IST — too early

    monkeypatch.setattr(scheduler, "datetime", _Clock)
    with app.app_context():
        scheduler.check_reminders.run()
    assert auth_client.get("/api/v1/push/log").get_json() == []

    class _Evening(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 10, 11, 15, 0, tzinfo=timezone.utc)  # 20:30 IST

    monkeypatch.setattr(scheduler, "datetime", _Evening)
    with app.app_context():
        scheduler.check_reminders.run()
    log = auth_client.get("/api/v1/push/log").get_json()
    assert [p["kind"] for p in log] == ["quiet_nudge"]


def test_users_without_a_preferences_row_still_get_defaults(app, auth_client, monkeypatch):
    me = auth_client.get("/api/v1/auth/me").get_json()
    _set_offset(app, me["id"], 0)

    class _Evening(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 10, 11, 21, 0, tzinfo=timezone.utc)

    monkeypatch.setattr(scheduler, "datetime", _Evening)
    with app.app_context():
        scheduler.check_reminders.run()
    assert any(p["kind"] == "quiet_nudge" for p in auth_client.get("/api/v1/push/log").get_json())


def test_medication_reminder_fires_once_in_its_window_and_not_after_marking(app, auth_client):
    me = auth_client.get("/api/v1/auth/me").get_json()
    _set_offset(app, me["id"], 330)
    sid = auth_client.post("/api/v1/medications", json={"name": "Metformin", "dose": "500 mg", "times": ["08:00", "20:00"]}).get_json()["id"]

    with app.app_context():
        scheduler._maybe_send_medication_reminders(me["id"], datetime(2026, 10, 11, 7, 50))  # not due yet
        assert auth_client.get("/api/v1/push/log").get_json() == []

        scheduler._maybe_send_medication_reminders(me["id"], datetime(2026, 10, 11, 8, 4))
        scheduler._maybe_send_medication_reminders(me["id"], datetime(2026, 10, 11, 8, 9))  # beat ran again
    log = auth_client.get("/api/v1/push/log").get_json()
    assert len(log) == 1
    assert log[0]["kind"] == "medication" and "Metformin" in log[0]["body"] and "500 mg" in log[0]["body"]

    # Evening dose taken before the window: no reminder.
    auth_client.post(f"/api/v1/medications/{sid}/doses", json={"date": "2026-10-11", "time": "20:00", "status": "taken"})
    with app.app_context():
        scheduler._maybe_send_medication_reminders(me["id"], datetime(2026, 10, 11, 20, 3))
    assert len(auth_client.get("/api/v1/push/log").get_json()) == 1


def test_weekly_medicine_is_silent_on_other_days(app, auth_client):
    me = auth_client.get("/api/v1/auth/me").get_json()
    auth_client.post("/api/v1/medications", json={"name": "Vitamin D", "times": ["09:00"], "days_of_week": [0]})  # Mondays
    with app.app_context():
        scheduler._maybe_send_medication_reminders(me["id"], datetime(2026, 10, 11, 9, 2))  # a Sunday
    assert auth_client.get("/api/v1/push/log").get_json() == []
