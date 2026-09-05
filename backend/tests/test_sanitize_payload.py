"""A model reliably answers "very poor" for sleep quality or "anxious" for
mood — plausible-sounding values that don't match our enums. Rejecting the
whole entry over one bad optional field used to discard what actually
mattered (e.g. the hours slept). sanitize_payload salvages the entry instead.
"""

from app.logging.registry import sanitize_payload, validate_payload


def test_drops_invalid_optional_enum_but_keeps_required_data(app):
    cleaned, dropped = sanitize_payload("sleep", {"hours": 5.0, "quality": "very poor"})
    assert cleaned == {"hours": 5.0}
    assert dropped and "quality" in dropped[0]
    assert validate_payload("sleep", cleaned) == []  # now passes


def test_valid_optional_field_is_left_alone(app):
    cleaned, dropped = sanitize_payload("sleep", {"hours": 7.0, "quality": "good"})
    assert cleaned == {"hours": 7.0, "quality": "good"}
    assert dropped == []


def test_invalid_required_field_is_not_silently_dropped(app):
    """Sanitizing must never remove a required field — an entry missing one
    is meaningless, so it should still fail validate_payload afterward."""
    cleaned, dropped = sanitize_payload("sleep", {"hours": "a lot"})
    assert "hours" in cleaned  # untouched
    assert dropped == []  # sanitize doesn't touch required fields
    assert validate_payload("sleep", cleaned) != []  # still rejected, correctly


def test_mood_with_invalid_enum_is_salvaged(app):
    cleaned, dropped = sanitize_payload("mood", {"mood": "anxious", "intensity": 7})
    # "anxious" isn't one of our enum values and mood is required, so it's
    # left in place for validate_payload to reject — this documents that
    # required-enum mismatches are a real, still-open gap (see the prompt fix
    # in prompting.py, which is the actual fix: tell the model the enum).
    assert cleaned["mood"] == "anxious"
    assert validate_payload("mood", cleaned) != []


def test_unknown_type_reports_error_without_raising():
    cleaned, dropped = sanitize_payload("not_a_real_type", {"x": 1})
    assert dropped and "Unknown log type" in dropped[0]
    assert cleaned == {"x": 1}
