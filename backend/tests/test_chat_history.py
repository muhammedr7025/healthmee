from datetime import timedelta

from app.common.models import utcnow
from app.logging.models import ChatMessage


def test_loggable_message_appears_in_history(auth_client):
    auth_client.post("/api/v1/chat/messages", json={"text": "had oatmeal and a banana for breakfast"})

    resp = auth_client.get("/api/v1/chat/messages")
    assert resp.status_code == 200
    kinds = [item["kind"] for item in resp.get_json()["items"]]
    assert kinds == ["user_text", "extract_card", "assistant_reply"]


def test_chitchat_message_with_no_entries_still_persists(auth_client):
    """The bug this closes: a message with nothing loggable in it produced
    no LogEntry, so it used to vanish completely on reopen."""
    auth_client.post("/api/v1/chat/messages", json={"text": "xyz random gibberish"})

    resp = auth_client.get("/api/v1/chat/messages")
    items = resp.get_json()["items"]
    assert items[0] == {"kind": "user_text", "text": "xyz random gibberish", "created_at": items[0]["created_at"]}


def test_no_welcome_back_message_right_after_chatting(auth_client):
    auth_client.post("/api/v1/chat/messages", json={"text": "had oatmeal"})

    resp = auth_client.get("/api/v1/chat/messages")
    assert resp.get_json()["welcome_back_message"] is None


def test_welcome_back_message_after_long_idle_gap(app, auth_client):
    auth_client.post("/api/v1/chat/messages", json={"text": "had oatmeal"})

    with app.app_context():
        ChatMessage.query.update({ChatMessage.created_at: utcnow() - timedelta(hours=8)})
        from app.extensions import db

        db.session.commit()

    resp = auth_client.get("/api/v1/chat/messages")
    assert resp.get_json()["welcome_back_message"]


def test_no_welcome_back_message_for_a_brand_new_thread(auth_client):
    resp = auth_client.get("/api/v1/chat/messages")
    data = resp.get_json()
    assert data["items"] == []
    assert data["welcome_back_message"] is None


def test_history_pages_backwards_with_a_cursor(auth_client):
    for i in range(6):
        auth_client.post("/api/v1/chat/messages", json={"text": f"drank water {i}"})

    first = auth_client.get("/api/v1/chat/messages?limit=4").get_json()
    assert first["has_more"] is True
    assert len(first["items"]) == 4
    # Newest page: the last user message is the most recent one.
    assert first["items"][-3]["text"] == "drank water 5" or any(i.get("text") == "drank water 5" for i in first["items"])

    oldest = first["items"][0]["created_at"]
    earlier = auth_client.get(f"/api/v1/chat/messages?limit=100&before={oldest}").get_json()
    assert earlier["welcome_back_message"] is None  # the nudge only belongs on the newest page
    assert all(i["created_at"] < oldest for i in earlier["items"])
    texts = [i.get("text") for i in earlier["items"] if i["kind"] == "user_text"]
    assert "drank water 0" in texts
    assert earlier["has_more"] is False
