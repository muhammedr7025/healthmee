"""The free Gemini tier allows 15 requests/minute and 500/day, so running
into a limit mid-day is routine. These cover the two things that must hold
when that happens: a user's log is never lost, and we don't spend quota
regenerating prose that hasn't changed.
"""

from app.common.llm.base import ExtractionResult, LLMProvider


class _ExplodingProvider(LLMProvider):
    """Stands in for a rate-limited / unreachable provider."""

    def extract(self, text, type_catalog, image_bytes=None, image_mime_type=None):
        raise RuntimeError("429 Resource has been exhausted (e.g. check quota)")


def test_entry_is_still_logged_when_the_provider_fails(auth_client, app, monkeypatch):
    monkeypatch.setattr(
        "app.logging.extraction.pipeline.get_llm_provider", lambda: _ExplodingProvider()
    )

    resp = auth_client.post("/api/v1/chat/messages", json={"text": "I slept 7 hours last night"})

    assert resp.status_code == 201
    entries = resp.get_json()["entries"]
    assert entries, "a provider failure must not discard the user's log"
    assert entries[0]["type"] == "sleep"
    assert entries[0]["payload"]["hours"] == 7.0


def test_narrative_is_not_regenerated_while_the_numbers_are_unchanged(auth_client, app, monkeypatch):
    calls = {"n": 0}

    class _CountingProvider(LLMProvider):
        def extract(self, text, type_catalog, image_bytes=None, image_mime_type=None):
            return ExtractionResult(entries=[], reply="")

        def narrate(self, prompt, stats):
            calls["n"] += 1
            return f"summary #{calls['n']}"

    monkeypatch.setattr("app.analytics.narrative.get_llm_provider", lambda: _CountingProvider())

    first = auth_client.get("/api/v1/trends/narrative?period=week").get_json()["summary"]
    second = auth_client.get("/api/v1/trends/narrative?period=week").get_json()["summary"]

    assert first == second
    assert calls["n"] == 1, "repeat views should reuse the cached summary, not spend quota"


def test_narrative_regenerates_once_the_numbers_move(auth_client, app, monkeypatch):
    calls = {"n": 0}

    class _CountingProvider(LLMProvider):
        def extract(self, text, type_catalog, image_bytes=None, image_mime_type=None):
            return ExtractionResult(entries=[], reply="")

        def narrate(self, prompt, stats):
            calls["n"] += 1
            return f"summary #{calls['n']}"

    monkeypatch.setattr("app.analytics.narrative.get_llm_provider", lambda: _CountingProvider())

    auth_client.get("/api/v1/trends/narrative?period=week")

    # a new log changes the underlying stats
    from datetime import date

    from app.analytics.models import DailyAggregate
    from app.extensions import db

    me = auth_client.get("/api/v1/auth/me").get_json()
    db.session.add(DailyAggregate(user_id=me["id"], date=date.today(), log_count=3, sleep_hours=7.0))
    db.session.commit()

    auth_client.get("/api/v1/trends/narrative?period=week")
    assert calls["n"] == 2, "a real change in the data should produce a fresh summary"
