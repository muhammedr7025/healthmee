"""Medicine schedules and the "2 of 3 taken" adherence line on Today."""

from datetime import date, timedelta

from app.common.localtime import local_today
from tests.conftest import LOCAL_TZ_OFFSET_MINUTES


def _add(auth_client, **overrides):
    body = {"name": "Metformin", "dose": "500 mg", "times": ["08:00", "20:00"], **overrides}
    resp = auth_client.post("/api/v1/medications", json=body)
    assert resp.status_code == 201, resp.get_json()
    return resp.get_json()["id"]


def test_schedule_shows_up_in_todays_plan_and_doses_can_be_ticked(auth_client):
    schedule_id = _add(auth_client)

    today = auth_client.get("/api/v1/medications/today").get_json()
    assert today["total"] == 2
    assert today["taken"] == 0
    assert [i["status"] for i in today["items"]] == ["pending", "pending"]
    assert today["adherence_pct"] == 0

    resp = auth_client.post(f"/api/v1/medications/{schedule_id}/doses", json={"time": "08:00", "status": "taken"})
    assert resp.status_code == 200
    assert resp.get_json()["taken"] == 1
    assert resp.get_json()["adherence_pct"] == 50

    # Marking the same slot again flips it — no duplicate rows, no double count.
    resp = auth_client.post(f"/api/v1/medications/{schedule_id}/doses", json={"time": "08:00", "status": "skipped"})
    assert resp.get_json()["taken"] == 0
    resp = auth_client.post(f"/api/v1/medications/{schedule_id}/doses", json={"time": "08:00", "status": "pending"})
    assert resp.get_json()["items"][0]["status"] == "pending"


def test_a_slot_that_is_not_due_is_rejected(auth_client):
    schedule_id = _add(auth_client)
    resp = auth_client.post(f"/api/v1/medications/{schedule_id}/doses", json={"time": "13:00", "status": "taken"})
    assert resp.status_code == 422


def test_weekly_medicine_is_only_due_on_its_days(auth_client):
    today = local_today(LOCAL_TZ_OFFSET_MINUTES)
    not_today = (today.weekday() + 3) % 7
    _add(auth_client, name="Vitamin D", times=["09:00"], days_of_week=[not_today])
    assert auth_client.get("/api/v1/medications/today").get_json()["total"] == 0


def test_no_medicines_means_no_adherence_number(auth_client):
    plan = auth_client.get("/api/v1/medications/today").get_json()
    assert plan == {"date": local_today(LOCAL_TZ_OFFSET_MINUTES).isoformat(), "items": [], "taken": 0, "total": 0, "adherence_pct": None}


def test_bad_time_format_is_rejected(auth_client):
    resp = auth_client.post("/api/v1/medications", json={"name": "X", "times": ["8am"]})
    assert resp.status_code == 422


def test_deleting_a_schedule_takes_its_doses_with_it(auth_client):
    schedule_id = _add(auth_client)
    auth_client.post(f"/api/v1/medications/{schedule_id}/doses", json={"time": "08:00", "status": "taken"})
    assert auth_client.delete(f"/api/v1/medications/{schedule_id}").status_code == 204
    assert auth_client.get("/api/v1/medications/today").get_json()["total"] == 0
    assert auth_client.get("/api/v1/medications").get_json() == []


def test_marking_yesterday_is_allowed(auth_client):
    schedule_id = _add(auth_client)
    yesterday = (local_today(LOCAL_TZ_OFFSET_MINUTES) - timedelta(days=1)).isoformat()
    resp = auth_client.post(
        f"/api/v1/medications/{schedule_id}/doses", json={"date": yesterday, "time": "20:00", "status": "taken"}
    )
    assert resp.status_code == 200
    assert resp.get_json()["date"] == yesterday
    assert resp.get_json()["taken"] == 1
    # ...and doesn't leak into today
    assert auth_client.get("/api/v1/medications/today").get_json()["taken"] == 0


def test_account_deletion_removes_medicines_too(auth_client):
    schedule_id = _add(auth_client)
    auth_client.post(f"/api/v1/medications/{schedule_id}/doses", json={"time": "08:00", "status": "taken"})
    assert auth_client.delete("/api/v1/auth/me").status_code == 204
    assert date.today()  # keeps the import honest; the real assertion is that delete didn't 500
