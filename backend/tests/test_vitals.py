"""The `vital` log type: BP, sugar, weight, pulse typed into chat become
structured readings and roll up into the day's aggregate for Trends."""

import pytest

from app.analytics.tasks import recompute_daily_aggregate
from app.common.localtime import local_today
from tests.conftest import LOCAL_TZ_OFFSET_MINUTES


def _vitals(resp):
    return [e for e in resp.get_json()["entries"] if e["type"] == "vital"]


@pytest.mark.parametrize(
    "message,kind,value,extra",
    [
        ("bp 120/80 this morning", "blood_pressure", 120, {"diastolic": 80, "context": "morning"}),
        ("my blood pressure was 135 over 88", "blood_pressure", 135, {"diastolic": 88}),
        ("fasting sugar 110", "blood_glucose", 110, {"context": "fasting", "unit": "mg/dL"}),
        ("glucose 6.1 after lunch", "blood_glucose", 6.1, {"context": "post_meal", "unit": "mmol/L"}),
        ("weight 72.5 kg", "weight", 72.5, {"unit": "kg"}),
        ("weighed 160 lbs today", "weight", 160, {"unit": "lb"}),
        ("resting heart rate 62", "heart_rate", 62, {"context": "resting"}),
        ("spo2 97", "spo2", 97, {}),
        ("temp 101.2", "temperature", 101.2, {"unit": "°F"}),
    ],
)
def test_readings_become_vital_entries(auth_client, message, kind, value, extra):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": message})
    assert resp.status_code == 201
    vitals = _vitals(resp)
    assert len(vitals) == 1, f"expected one vital for {message!r}, got {resp.get_json()['entries']}"
    payload = vitals[0]["payload"]
    assert payload["kind"] == kind
    assert payload["value"] == value
    for key, expected in extra.items():
        assert payload[key] == expected


def test_a_reading_does_not_also_log_a_meal(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "had bp 120/80 this morning"})
    assert [e["type"] for e in resp.get_json()["entries"]] == ["vital"]


def test_a_date_is_not_a_blood_pressure(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "on 10/11 I felt great"})
    assert _vitals(resp) == []


def test_several_readings_in_one_message(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "bp 118/76, pulse 70, weight 70 kg"})
    kinds = sorted(e["payload"]["kind"] for e in _vitals(resp))
    assert kinds == ["blood_pressure", "heart_rate", "weight"]


def test_vitals_roll_up_into_the_day(auth_client, app):
    for text in ("bp 120/80", "bp 130/84", "fasting sugar 100", "sugar 150 after dinner", "weight 70 kg", "weight 71 kg"):
        auth_client.post("/api/v1/chat/messages", json={"text": text})
    me = auth_client.get("/api/v1/auth/me").get_json()

    with app.app_context():
        recompute_daily_aggregate.run(me["id"], local_today(LOCAL_TZ_OFFSET_MINUTES).isoformat(), LOCAL_TZ_OFFSET_MINUTES)

    today = auth_client.get("/api/v1/today").get_json()
    assert today["systolic"] == 125  # readings average
    assert today["diastolic"] == 82
    assert today["glucose_mg_dl"] == 100  # the fasting one wins over the post-meal one
    assert today["weight_kg"] == 71  # last weigh-in of the day
    assert today["heart_rate_bpm"] is None  # never measured — left blank, not zero
