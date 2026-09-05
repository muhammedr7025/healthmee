"""OCR and Gemini extraction both parse JSON out of free-form model output.
Models wrap it in ``` fences or add a sentence around it more often than not,
and a raw json.loads on that returns nothing — which looked exactly like
"OCR isn't working".
"""

import pytest

from app.common.llm.json_utils import parse_json_loose


@pytest.mark.parametrize(
    "raw",
    [
        '[{"test_name": "HbA1c", "value": "5.4", "unit": "%"}]',
        '```json\n[{"test_name": "HbA1c", "value": "5.4", "unit": "%"}]\n```',
        '```\n[{"test_name": "HbA1c", "value": "5.4", "unit": "%"}]\n```',
        'Here are the values I could read:\n[{"test_name": "HbA1c", "value": "5.4", "unit": "%"}]',
    ],
)
def test_parses_arrays_however_the_model_wraps_them(raw):
    assert parse_json_loose(raw) == [{"test_name": "HbA1c", "value": "5.4", "unit": "%"}]


def test_tolerates_a_trailing_comma():
    raw = '{"entries": [{"test_name": "HbA1c", "value": "5.4",},], "reply": "ok",}'
    assert parse_json_loose(raw) == {"entries": [{"test_name": "HbA1c", "value": "5.4"}], "reply": "ok"}


def test_parses_fenced_object():
    raw = '```json\n{"entries": [], "reply": "Got it."}\n```'
    assert parse_json_loose(raw) == {"entries": [], "reply": "Got it."}


@pytest.mark.parametrize("raw", ["", "   ", "no json at all"])
def test_raises_on_unparseable_rather_than_returning_junk(raw):
    with pytest.raises((ValueError, Exception)):
        parse_json_loose(raw)


class _FakeResponse:
    def __init__(self, text):
        self.text = text


class _FakeModel:
    def __init__(self, name, system_instruction=None, generation_config=None):
        _FakeGenai.last_generation_config = generation_config
        self._reply = _FakeGenai.next_reply

    def generate_content(self, content):
        return _FakeResponse(self._reply)


class _FakeGenai:
    last_generation_config = None
    next_reply = "{}"
    GenerativeModel = _FakeModel


def _gemini_with_fake_genai():
    """Builds the provider without running __init__ (which would import and
    configure the real google.generativeai)."""
    from app.common.llm.gemini_provider import GeminiProvider

    provider = object.__new__(GeminiProvider)
    provider._genai = _FakeGenai
    provider._model_name = "gemini-test"
    return provider


def test_gemini_extraction_does_not_send_a_response_schema():
    """Gemini rejects an OBJECT response_schema with no properties — which is
    exactly what the per-type `payload` field is. Sending one made every chat
    message fail."""
    _FakeGenai.next_reply = '{"entries": [], "reply": "ok"}'
    provider = _gemini_with_fake_genai()

    provider.extract("had lunch", [{"name": "food", "description": "d", "schema": {}}])

    assert "response_schema" not in (_FakeGenai.last_generation_config or {})
    assert _FakeGenai.last_generation_config["response_mime_type"] == "application/json"


def test_gemini_extraction_survives_a_fenced_reply():
    _FakeGenai.next_reply = '```json\n{"entries": [{"type": "food", "payload": {"food_items": ["dal"]}, "summary": "dal"}], "reply": "Logged."}\n```'
    provider = _gemini_with_fake_genai()

    result = provider.extract("had dal", [{"name": "food", "description": "d", "schema": {}}])

    assert len(result.entries) == 1
    assert result.entries[0].type == "food"
    assert result.reply == "Logged."


class _FakeModelSequence:
    """Like _FakeModel, but returns a different reply on each successive call
    — for testing the one-retry-on-malformed-JSON behavior, which a fixed
    reply can't exercise (both attempts would fail or both would succeed)."""

    def __init__(self, name, system_instruction=None, generation_config=None):
        _FakeGenaiSequence.last_generation_config = generation_config

    def generate_content(self, content):
        reply = _FakeGenaiSequence.replies[_FakeGenaiSequence.calls]
        _FakeGenaiSequence.calls += 1
        return _FakeResponse(reply)


class _FakeGenaiSequence:
    replies: list[str] = []
    calls = 0
    last_generation_config = None
    GenerativeModel = _FakeModelSequence


def _gemini_with_fake_sequence(replies):
    from app.common.llm.gemini_provider import GeminiProvider

    _FakeGenaiSequence.replies = replies
    _FakeGenaiSequence.calls = 0
    provider = object.__new__(GeminiProvider)
    provider._genai = _FakeGenaiSequence
    provider._model_name = "gemini-test"
    return provider


def test_gemini_extraction_retries_once_on_malformed_json_then_succeeds():
    provider = _gemini_with_fake_sequence([
        '{"entries": [{"type": "food",}',  # malformed — missing closing braces
        '{"entries": [{"type": "food", "payload": {"food_items": ["dal"]}, "summary": "dal"}], "reply": "Logged."}',
    ])

    result = provider.extract("had dal", [{"name": "food", "description": "d", "schema": {}}])

    assert _FakeGenaiSequence.calls == 2
    assert len(result.entries) == 1
    assert result.reply == "Logged."


def test_gemini_extraction_gives_up_after_two_malformed_replies():
    provider = _gemini_with_fake_sequence([
        "not json at all",
        "still not json",
    ])

    with pytest.raises(Exception):
        provider.extract("had dal", [{"name": "food", "description": "d", "schema": {}}])

    assert _FakeGenaiSequence.calls == 2  # exactly one retry, not an unbounded loop


def test_gemini_extraction_raises_so_the_pipeline_can_fall_back():
    """Errors deliberately propagate rather than being swallowed here: the
    pipeline catches them and re-runs the offline extractor, so a rate-limited
    message still gets logged. Swallowing it here would return zero entries and
    quietly lose what the user just said. See test_llm_resilience.py."""
    import pytest as _pytest

    _FakeGenai.next_reply = "the model said something unparseable"
    provider = _gemini_with_fake_genai()

    with _pytest.raises(Exception):
        provider.extract("had dal", [{"name": "food", "description": "d", "schema": {}}])
