"""Water logging used to be impossible: app/analytics/tasks.py aggregated a
`hydration` type that was never registered in app/logging/types.py, and the
mock extractor sent "drank water" down the food branch. The water stat was
therefore permanently zero. These lock the whole path down.
"""

import pytest


def test_hydration_type_is_registered(app):
    from app.logging.registry import get_type

    definition = get_type("hydration")
    assert definition is not None
    assert "volume_ml" in definition.schema


@pytest.mark.parametrize(
    "message,expected_ml",
    [
        ("drank 2 glasses of water", 500),
        ("had a 500ml bottle of water", 500),
        ("drank 1 litre of water", 1000),
        ("drank water", 250),  # no quantity = one glass
    ],
)
def test_water_messages_log_as_hydration(auth_client, message, expected_ml):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": message})
    assert resp.status_code == 201
    entries = resp.get_json()["entries"]
    hydration = [e for e in entries if e["type"] == "hydration"]
    assert hydration, f"no hydration entry for {message!r} (got {[e['type'] for e in entries]})"
    assert hydration[0]["payload"]["volume_ml"] == expected_ml


def test_drink_only_message_does_not_also_log_food(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "drank 2 glasses of water"})
    types = [e["type"] for e in resp.get_json()["entries"]]
    assert "hydration" in types
    assert "food" not in types


def test_meal_with_a_drink_logs_both(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "had rice for lunch and drank a glass of water"})
    types = [e["type"] for e in resp.get_json()["entries"]]
    assert "hydration" in types
    assert "food" in types


def test_hydration_reaches_the_daily_water_stat(auth_client):
    """The end-to-end path the user actually sees: log water -> aggregate ->
    Today's water_ml."""
    from datetime import date

    from app.analytics.tasks import recompute_daily_aggregate

    auth_client.post("/api/v1/chat/messages", json={"text": "drank 2 glasses of water"})
    me = auth_client.get("/api/v1/auth/me").get_json()

    # .run() executes the task body in the test's existing app context —
    # calling the task directly would push a fresh one, which for an
    # in-memory SQLite test DB means a new connection with no tables.
    recompute_daily_aggregate.run(me["id"], date.today().isoformat())

    resp = auth_client.get("/api/v1/today")
    assert resp.get_json()["water_ml"] == 500
