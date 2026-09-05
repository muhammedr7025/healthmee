"""Reproduces exactly what live Gemini returned for "slept badly, maybe 5
hours": a sleep entry with quality="very poor", which isn't in our enum. Before
sanitize_payload existed, validate_payload rejected the whole entry and the
5 hours were never logged — with no error surfaced to the user, since
dropped entries just don't appear.
"""

from app.common.llm.base import ExtractedEntry, ExtractionResult, LLMProvider
from app.logging.models import LogEntry


class _RealisticButWrongProvider(LLMProvider):
    def extract(self, text, type_catalog, image_bytes=None, image_mime_type=None):
        return ExtractionResult(
            entries=[
                ExtractedEntry(type="sleep", payload={"hours": 5.0, "quality": "very poor"}, summary="Slept 5h, very poor"),
            ],
            reply="Logged.",
        )


def test_sleep_hours_survive_an_invalid_quality_label(auth_client, monkeypatch):
    monkeypatch.setattr(
        "app.logging.extraction.pipeline.get_llm_provider", lambda: _RealisticButWrongProvider()
    )

    resp = auth_client.post("/api/v1/chat/messages", json={"text": "slept badly, maybe 5 hours"})

    assert resp.status_code == 201
    body = resp.get_json()
    assert body["entries"], "the sleep entry must survive, not disappear silently"
    assert body["entries"][0]["type"] == "sleep"
    assert body["entries"][0]["payload"] == {"hours": 5.0}  # "quality" dropped, "hours" kept
    assert any("quality" in e for e in body["validation_errors"])  # but it's not silent either

    entry = LogEntry.query.filter_by(type="sleep").first()
    assert entry.structured_payload == {"hours": 5.0}
