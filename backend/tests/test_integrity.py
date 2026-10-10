"""Data paths that were wrong in ways the old test setup couldn't see
(SQLite with foreign keys off) — each one reproduced on production first."""

from app.extensions import db
from app.media.models import MediaAsset


def _entry_id(auth_client, text):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": text})
    assert resp.status_code == 201
    return resp.get_json()["entries"][0]["id"]


def test_deleting_a_chat_created_entry_removes_its_card_and_keeps_the_thread(auth_client):
    entry_id = _entry_id(auth_client, "drank a glass of water")
    history = auth_client.get("/api/v1/chat/messages").get_json()["items"]
    assert any(i["kind"] == "extract_card" and i.get("entry_id") == entry_id for i in history)

    assert auth_client.delete(f"/api/v1/log-entries/{entry_id}").status_code == 204

    history = auth_client.get("/api/v1/chat/messages").get_json()["items"]
    kinds = [i["kind"] for i in history]
    assert "extract_card" not in kinds
    assert "user_text" in kinds and "assistant_reply" in kinds  # the conversation itself survives
    assert auth_client.get("/api/v1/logbook").get_json() == []
    assert auth_client.get("/api/v1/today").get_json()["water_ml"] == 0  # totals recomputed inline


def test_deleting_an_entry_that_raised_an_alert_keeps_the_alert(auth_client):
    auth_client.post("/api/v1/allergies", json={"name": "peanut", "severity": "severe"})
    entry_id = _entry_id(auth_client, "ate a peanut butter sandwich")
    alerts_before = auth_client.get("/api/v1/alerts").get_json()
    assert alerts_before, "the allergy alert should have fired"

    assert auth_client.delete(f"/api/v1/log-entries/{entry_id}").status_code == 204
    alerts_after = auth_client.get("/api/v1/alerts").get_json()
    assert len(alerts_after) == len(alerts_before)
    assert all(a["log_entry_id"] is None for a in alerts_after if a["trigger_type"] == "allergy")


def test_payload_edits_are_validated_against_the_type(auth_client):
    entry_id = _entry_id(auth_client, "slept 7 hours")

    bad = auth_client.patch(f"/api/v1/log-entries/{entry_id}", json={"payload": {"hours": "lots"}})
    assert bad.status_code == 422
    assert "hours" in bad.get_json()["message"]

    good = auth_client.patch(f"/api/v1/log-entries/{entry_id}", json={"payload": {"hours": "7.5"}})
    assert good.status_code == 200
    assert good.get_json()["payload"]["hours"] == 7.5  # numeric strings are coerced, not rejected
    assert auth_client.get("/api/v1/today").get_json()["sleep_hours"] == 7.5


def test_summary_edit_is_clipped_to_the_column(auth_client):
    entry_id = _entry_id(auth_client, "slept 7 hours")
    resp = auth_client.patch(f"/api/v1/log-entries/{entry_id}", json={"summary": "x" * 400})
    assert resp.status_code == 200
    assert len(resp.get_json()["summary"]) == 255


def test_account_deletion_works_after_a_password_reset_request(auth_client):
    assert auth_client.post("/api/v1/auth/password/reset-request", json={"email": "test@example.com"}).status_code == 202
    assert auth_client.delete("/api/v1/auth/me").status_code == 204


def test_someone_elses_media_id_is_not_attached_to_my_entry(client, app):
    client.post("/api/v1/auth/register", json={"email": "owner@example.com", "password": "password123"})
    owner = client.post("/api/v1/auth/login", json={"email": "owner@example.com", "password": "password123"}).get_json()
    with app.app_context():
        asset = MediaAsset(user_id=owner["user"]["id"], kind="photo", storage_key="photo/private.jpg", content_type="image/jpeg")
        db.session.add(asset)
        db.session.commit()
        foreign_asset_id = asset.id

    client.post("/api/v1/auth/register", json={"email": "other@example.com", "password": "password123"})
    other = client.post("/api/v1/auth/login", json={"email": "other@example.com", "password": "password123"}).get_json()
    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {other['access_token']}"

    resp = client.post("/api/v1/chat/messages", json={"text": "slept 7 hours", "media_asset_id": foreign_asset_id})
    assert resp.status_code == 201
    assert resp.get_json()["entries"][0]["media_asset_id"] is None
    history = client.get("/api/v1/chat/messages").get_json()["items"]
    assert all(i.get("media_asset_id") is None for i in history)

    lab = client.post(
        "/api/v1/lab-results",
        json={"test_name": "HbA1c", "value": "5.9", "taken_at": "2026-10-01T00:00:00Z", "media_asset_id": foreign_asset_id},
    )
    assert lab.status_code == 404


def test_refresh_token_issues_a_new_access_token(client):
    client.post("/api/v1/auth/register", json={"email": "r@example.com", "password": "password123"})
    tokens = client.post("/api/v1/auth/login", json={"email": "r@example.com", "password": "password123"}).get_json()
    assert tokens["refresh_token"]

    # The refresh token can't be used as an access token...
    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {tokens['refresh_token']}"
    assert client.get("/api/v1/auth/me").status_code in (401, 422)

    # ...but trades for a fresh pair that works.
    refreshed = client.post("/api/v1/auth/refresh").get_json()
    assert refreshed["access_token"] and refreshed["refresh_token"]
    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {refreshed['access_token']}"
    assert client.get("/api/v1/auth/me").status_code == 200
