def test_subscription_defaults_to_free(auth_client):
    resp = auth_client.get("/api/v1/billing/subscription")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["plan"] == "free"
    assert body["is_premium"] is False
    assert body["billing_mode"] == "mock"


def test_mock_checkout_upgrades_to_premium(auth_client):
    resp = auth_client.post("/api/v1/billing/checkout-session", json={})
    assert resp.status_code == 201
    body = resp.get_json()
    assert body["mode"] == "mock"
    assert body["subscription"]["is_premium"] is True

    resp = auth_client.get("/api/v1/billing/subscription")
    assert resp.get_json()["is_premium"] is True


def test_mock_portal_downgrades_to_free(auth_client):
    auth_client.post("/api/v1/billing/checkout-session", json={})
    resp = auth_client.post("/api/v1/billing/portal-session", json={})
    assert resp.status_code == 201
    assert resp.get_json()["subscription"]["is_premium"] is False


def test_logbook_free_tier_clamps_history(auth_client, app):
    from datetime import datetime, timedelta

    from app.extensions import db
    from app.logging.models import LogEntry

    with app.app_context():
        old_entry = LogEntry(
            user_id="dummy",
            type="mood",
            timestamp=datetime.utcnow() - timedelta(days=90),
            structured_payload={},
        )
        # use the real user id from the auth token instead of "dummy"
        me = auth_client.get("/api/v1/auth/me").get_json()
        old_entry.user_id = me["id"]
        db.session.add(old_entry)
        db.session.commit()

    resp = auth_client.get("/api/v1/logbook")
    assert resp.status_code == 200
    assert resp.get_json() == []  # older than the 30-day free window

    auth_client.post("/api/v1/billing/checkout-session", json={})
    resp = auth_client.get("/api/v1/logbook")
    assert len(resp.get_json()) == 1  # premium sees full history
