def test_export_includes_real_data(auth_client):
    auth_client.post("/api/v1/chat/messages", json={"text": "I slept 7 hours last night"})
    auth_client.post("/api/v1/allergies", json={"name": "Peanut", "severity": "severe"})

    resp = auth_client.get("/api/v1/auth/me/export")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["account"]["email"] == "test@example.com"
    assert len(body["log_entries"]) == 1
    assert body["allergies"][0]["name"] == "Peanut"


def test_delete_account_removes_everything(auth_client, app):
    auth_client.post("/api/v1/chat/messages", json={"text": "I slept 7 hours last night"})
    auth_client.post("/api/v1/allergies", json={"name": "Peanut", "severity": "severe"})

    resp = auth_client.delete("/api/v1/auth/me")
    assert resp.status_code == 204

    # the token is now for a deleted user — every subsequent call 404s
    resp = auth_client.get("/api/v1/auth/me")
    assert resp.status_code == 404

    with app.app_context():
        from app.accounts.models import User
        from app.logging.models import LogEntry
        from app.medical_profile.models import Allergy

        assert User.query.count() == 0
        assert LogEntry.query.count() == 0
        assert Allergy.query.count() == 0
