def test_patch_and_delete_log_entry(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "I slept 7 hours last night"})
    entry = resp.get_json()["entries"][0]
    entry_id = entry["id"]

    resp = auth_client.patch(f"/api/v1/log-entries/{entry_id}", json={"summary": "Slept 7.5h, corrected"})
    assert resp.status_code == 200
    assert resp.get_json()["summary"] == "Slept 7.5h, corrected"
    assert resp.get_json()["payload"] == {"hours": 7.0}  # structured_payload -> payload must survive dump

    resp = auth_client.get("/api/v1/logbook")
    assert resp.get_json()[0]["summary"] == "Slept 7.5h, corrected"
    assert resp.get_json()[0]["payload"] == {"hours": 7.0}

    resp = auth_client.delete(f"/api/v1/log-entries/{entry_id}")
    assert resp.status_code == 204

    resp = auth_client.get("/api/v1/logbook")
    assert resp.get_json() == []


def test_cannot_edit_another_users_entry(client):
    client.post("/api/v1/auth/register", json={"email": "a1@example.com", "password": "password123"})
    token_a = client.post("/api/v1/auth/login", json={"email": "a1@example.com", "password": "password123"}).get_json()["access_token"]
    client.post("/api/v1/auth/register", json={"email": "b1@example.com", "password": "password123"})
    token_b = client.post("/api/v1/auth/login", json={"email": "b1@example.com", "password": "password123"}).get_json()["access_token"]

    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {token_a}"
    resp = client.post("/api/v1/chat/messages", json={"text": "I slept 7 hours last night"})
    entry_id = resp.get_json()["entries"][0]["id"]

    client.environ_base["HTTP_AUTHORIZATION"] = f"Bearer {token_b}"
    resp = client.patch(f"/api/v1/log-entries/{entry_id}", json={"summary": "hijacked"})
    assert resp.status_code == 404
