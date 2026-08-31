from app.logging.models import LogEntry


def test_food_message_creates_log_entry(app, auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "had oatmeal and a banana for breakfast"})
    assert resp.status_code == 201
    data = resp.get_json()
    assert data["entries"]
    assert data["entries"][0]["type"] == "food"
    assert "reply" in data

    with app.app_context():
        assert LogEntry.query.count() == 1


def test_sleep_message_extracts_hours(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "I slept 7 hours last night"})
    data = resp.get_json()
    sleep_entries = [e for e in data["entries"] if e["type"] == "sleep"]
    assert sleep_entries
    assert sleep_entries[0]["payload"]["hours"] == 7.0


def test_unrecognized_message_returns_no_entries(auth_client):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": "xyz random gibberish"})
    data = resp.get_json()
    assert data["entries"] == []
    assert data["reply"]
