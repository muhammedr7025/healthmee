"""Seeing what happens: product events, the LLM call log, request ids, the
health check and the type catalog."""

from datetime import date, datetime

from app.events.models import LlmCall, ProductEvent
from app.extensions import db


def test_client_events_are_stored_in_a_batch(auth_client, app):
    resp = auth_client.post(
        "/api/v1/events",
        json={
            "platform": "ios",
            "app_version": "1.0.0+4",
            "session_id": "s1",
            "events": [
                {"name": "screen_view", "props": {"screen": "today"}, "client_ts": "2026-10-11T10:00:00+05:30"},
                {"name": "quick_log_tap", "props": {"template": "water"}},
            ],
        },
    )
    assert resp.status_code == 202
    assert resp.get_json() == {"accepted": 2}

    with app.app_context():
        rows = ProductEvent.query.filter_by(platform="ios").order_by(ProductEvent.name).all()
        assert [r.name for r in rows] == ["quick_log_tap", "screen_view"]
        assert rows[1].app_version == "1.0.0+4"
        assert rows[1].client_ts == datetime(2026, 10, 11, 4, 30)  # stored as UTC
        assert rows[1].user_id is not None


def test_event_names_are_validated(auth_client):
    resp = auth_client.post("/api/v1/events", json={"platform": "ios", "events": [{"name": "Bad Name!"}]})
    assert resp.status_code == 422


def test_server_side_events_and_llm_calls_are_recorded(auth_client, app):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "drank 2 glasses of water"})
    assert resp.status_code == 201
    assert resp.get_json()["degraded"] is False

    with app.app_context():
        names = {e.name for e in ProductEvent.query.all()}
        assert {"signup", "login", "extraction_result"} <= names
        extraction = ProductEvent.query.filter_by(name="extraction_result").one()
        assert extraction.props["entries"] == 1 and extraction.props["types"] == ["hydration"]
        assert "water" not in str(extraction.props)  # ids and counts only, never the message

        call = LlmCall.query.filter_by(purpose="extract").one()
        assert call.provider == "mock" and call.output_entries == 1 and call.failed is False
        assert call.latency_ms >= 0


def test_corrections_and_deletions_are_events(auth_client, app):
    entry_id = auth_client.post("/api/v1/chat/messages", json={"text": "slept 7 hours"}).get_json()["entries"][0]["id"]
    auth_client.patch(f"/api/v1/log-entries/{entry_id}", json={"payload": {"hours": 6.5}})
    auth_client.delete(f"/api/v1/log-entries/{entry_id}")

    with app.app_context():
        corrected = ProductEvent.query.filter_by(name="entry_corrected").one()
        assert corrected.props == {"type": "sleep", "fields_changed": ["structured_payload"]}
        assert ProductEvent.query.filter_by(name="entry_deleted").one().props == {"type": "sleep"}


def test_every_response_carries_a_request_id(auth_client):
    resp = auth_client.get("/api/v1/today", headers={"X-Request-ID": "trace-123"})
    assert resp.headers["X-Request-ID"] == "trace-123"
    resp = auth_client.get("/api/v1/today")
    assert len(resp.headers["X-Request-ID"]) >= 8


def test_health_check_reports_its_dependencies(client):
    resp = client.get("/health")
    body = resp.get_json()
    assert body["db"] == "ok"
    assert "redis" in body and "migration" in body and body["llm_provider"] == "mock"
    assert resp.status_code in (200, 503)  # 503 when no Redis is running on the test machine


def test_log_types_catalog_drives_the_correction_sheet(auth_client):
    types = auth_client.get("/api/v1/log-types").get_json()
    by_name = {t["name"]: t for t in types}
    assert {"food", "sleep", "hydration", "vital", "mood"} <= set(by_name)
    hours = next(f for f in by_name["sleep"]["fields"] if f["name"] == "hours")
    assert hours == {"name": "hours", "type": "number", "required": True, "enum": None}
    kind = next(f for f in by_name["vital"]["fields"] if f["name"] == "kind")
    assert "blood_pressure" in kind["enum"]


def test_account_deletion_keeps_anonymised_events(auth_client, app):
    auth_client.post("/api/v1/chat/messages", json={"text": "drank water"})
    assert auth_client.delete("/api/v1/auth/me").status_code == 204
    with app.app_context():
        assert ProductEvent.query.count() > 0
        assert all(e.user_id is None for e in ProductEvent.query.all())
        assert all(c.user_id is None for c in LlmCall.query.all())
