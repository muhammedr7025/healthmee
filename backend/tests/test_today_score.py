"""Today's health score: every point traceable to a visible component."""

from app.analytics.tasks import recompute_daily_aggregate
from app.common.localtime import local_today
from tests.conftest import LOCAL_TZ_OFFSET_MINUTES


def _score(auth_client):
    resp = auth_client.get("/api/v1/today/score")
    assert resp.status_code == 200
    return resp.get_json()


def test_empty_day_scores_zero_but_shows_the_working(auth_client):
    body = _score(auth_client)
    assert body["score"] == 0
    assert body["mascot"] == "curious"  # a quiet day isn't a bad day
    keys = [c["key"] for c in body["components"]]
    assert keys == ["logging", "sleep", "water", "activity", "food", "mood", "medicines"]
    # Medicines aren't counted when none are scheduled — the total adjusts rather than penalising.
    meds = next(c for c in body["components"] if c["key"] == "medicines")
    assert meds["max"] == 0
    assert body["achievable"] == 90


def test_a_good_day_scores_high_and_each_component_explains_itself(auth_client, app):
    for text in (
        "slept 8 hours",
        "drank 2.5 litres of water",
        "ran for 40 minutes",
        "feeling happy",
    ):
        auth_client.post("/api/v1/chat/messages", json={"text": text})
    me = auth_client.get("/api/v1/auth/me").get_json()
    with app.app_context():
        recompute_daily_aggregate.run(me["id"], local_today(LOCAL_TZ_OFFSET_MINUTES).isoformat(), LOCAL_TZ_OFFSET_MINUTES)

    body = _score(auth_client)
    by_key = {c["key"]: c for c in body["components"]}
    assert by_key["logging"]["points"] == 20
    assert by_key["sleep"]["points"] == 20 and "8h" in by_key["sleep"]["detail"]
    assert by_key["water"]["points"] == 15
    assert by_key["mood"]["points"] == 5
    assert body["score"] == round(100 * body["earned"] / body["achievable"])
    assert body["score"] >= 60


def test_medicines_count_once_scheduled(auth_client):
    auth_client.post("/api/v1/medications", json={"name": "Metformin", "times": ["08:00", "20:00"]})
    body = _score(auth_client)
    meds = next(c for c in body["components"] if c["key"] == "medicines")
    assert meds["max"] == 10 and meds["points"] == 0 and "0 of 2" in meds["detail"]
    assert body["achievable"] == 100
