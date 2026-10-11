"""MeMe should know who it's talking to: allergies first, their day and
goals in the reply, Hinglish understood, a question when a reading is half
there, and an export/delete that covers everything."""

from datetime import date

from app.accounts.models import User
from app.common.llm.prompting import build_system_prompt
from app.logging.allergens import matching_allergens
from app.logging.extraction.context import build_user_context
from app.logging.registry import get_type_catalog


def test_user_context_reaches_the_prompt(auth_client, app):
    auth_client.post("/api/v1/allergies", json={"name": "peanut", "severity": "severe"})
    auth_client.post("/api/v1/goals", json={"type": "water", "target_value": {"value": 2.5, "unit": "L"}})
    auth_client.post("/api/v1/chat/messages", json={"text": "drank 2 glasses of water"})
    me = auth_client.get("/api/v1/auth/me").get_json()

    with app.app_context():
        user = User.query.get(me["id"])
        context = build_user_context(user, date.today())
        prompt = build_system_prompt(get_type_catalog(), user_context=context)

    assert context["allergies"] == ["peanut"]
    assert context["goals"] == ["daily water → 2.5 L"]
    assert context["today"]["water_l"] == 0.5
    assert context["recent"] == ["500 ml water"]
    assert "ALWAYS check every food against these: peanut" in prompt
    assert "0.5 L water" in prompt
    assert "clarifying_question" in prompt
    assert "roti/chapati ~70 kcal" in prompt


def test_allergen_matching_uses_whole_words_and_synonyms():
    assert matching_allergens(["nut"], ["had a donut"]) == []
    assert matching_allergens(["peanut"], ["groundnut chutney"]) == ["peanut"]
    assert matching_allergens(["Milk"], ["paneer butter masala"]) == ["Milk"]
    assert matching_allergens(["wheat"], ["2 roti khaya"]) == ["wheat"]
    assert matching_allergens(["egg"], ["eggplant curry"]) == []  # whole word, not prefix
    assert matching_allergens(["shellfish"], ["prawn biryani"]) == ["shellfish"]


def test_allergen_warning_comes_first_in_the_reply_and_on_the_entry(auth_client):
    auth_client.post("/api/v1/allergies", json={"name": "peanut", "severity": "severe"})
    body = auth_client.post("/api/v1/chat/messages", json={"text": "ate dosa with groundnut chutney for breakfast"}).get_json()
    assert body["reply"].startswith("Heads up")
    food = next(e for e in body["entries"] if e["type"] == "food")
    assert food["payload"]["allergens"] == ["peanut"]
    assert any(a["trigger_type"] == "allergy" for a in body["alerts"])


def test_a_donut_does_not_trigger_a_nut_allergy(auth_client):
    auth_client.post("/api/v1/allergies", json={"name": "nut", "severity": "severe"})
    body = auth_client.post("/api/v1/chat/messages", json={"text": "ate a donut for breakfast"}).get_json()
    assert body["alerts"] == []
    assert not body["reply"].startswith("Heads up")


def test_hinglish_messages_are_understood(auth_client):
    body = auth_client.post("/api/v1/chat/messages", json={"text": "subah 2 roti khaya aur paani piya"}).get_json()
    types = sorted(e["type"] for e in body["entries"])
    assert types == ["food", "hydration"]
    water = next(e for e in body["entries"] if e["type"] == "hydration")
    assert water["payload"]["beverage"] == "water"


def test_half_a_blood_pressure_gets_a_question_not_a_guess(auth_client):
    body = auth_client.post("/api/v1/chat/messages", json={"text": "bp 120 this morning"}).get_json()
    assert body["entries"] == []
    assert "lower" in body["question"]
    history = auth_client.get("/api/v1/chat/messages").get_json()["items"]
    replies = [i["text"] for i in history if i["kind"] == "assistant_reply"]
    assert any("lower" in r for r in replies)  # the question survives a restart


def test_export_covers_medicines_and_delete_sweeps_storage(auth_client, app, monkeypatch):
    from app.extensions import db
    from app.media.models import MediaAsset

    me = auth_client.get("/api/v1/auth/me").get_json()
    auth_client.post("/api/v1/medications", json={"name": "Metformin", "times": ["08:00"]})
    with app.app_context():
        db.session.add(MediaAsset(user_id=me["id"], kind="photo", storage_key="photo/x.jpg", content_type="image/jpeg"))
        db.session.commit()

    export = auth_client.get("/api/v1/auth/me/export").get_json()
    for key in ("medications", "medication_doses", "notification_preferences", "devices", "reports", "subscription"):
        assert key in export
    assert export["medications"][0]["name"] == "Metformin"

    swept = []
    monkeypatch.setattr("app.accounts.data_service.delete_objects", lambda keys: swept.extend(keys))
    assert auth_client.delete("/api/v1/auth/me").status_code == 204
    assert swept == ["photo/x.jpg"]


def test_question_is_not_asked_twice():
    from app.logging.extraction.pipeline import _without_duplicate_question as dedupe

    reply = "Morning BP 120 noted. Could you also share the diastolic number so I can log the full reading?"
    assert dedupe(reply, "What was the lower number?") == "Morning BP 120 noted."
    # No clarifying question: a conversational question in the reply is fine and stays.
    assert dedupe("Logged the donut. How is your Sunday shaping up?", None) == "Logged the donut. How is your Sunday shaping up?"
    # A reply that was only the question leaves the question bubble to carry it.
    assert dedupe("What was the lower number?", "What was the lower number?") == ""
