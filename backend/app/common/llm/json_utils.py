"""Tolerant JSON parsing for LLM responses.

Models routinely wrap JSON in ```json fences or prepend a sentence, even when
told not to, and occasionally emit a trailing comma. None of that should turn
into a 500 (or a silently dropped log entry) — pull the outermost JSON value
out of whatever came back and tidy the one syntax error that's common enough
to bother with. Anything else raises, and the caller (the extraction
pipeline) falls back to the offline extractor rather than losing the entry.
"""

import json
import re

_FENCE_START = re.compile(r"^\s*```(?:json)?\s*", re.IGNORECASE)
_FENCE_END = re.compile(r"\s*```\s*$")
_TRAILING_COMMA = re.compile(r",(\s*[}\]])")


def parse_json_loose(text: str):
    cleaned = _FENCE_END.sub("", _FENCE_START.sub("", (text or "").strip())).strip()
    if not cleaned:
        raise ValueError("empty LLM response")

    # Trim any prose either side of the actual JSON value.
    starts = [i for i in (cleaned.find("{"), cleaned.find("[")) if i != -1]
    if starts:
        cleaned = cleaned[min(starts) :]
    end = max(cleaned.rfind("}"), cleaned.rfind("]"))
    if end != -1:
        cleaned = cleaned[: end + 1]

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        # A trailing comma before a closing bracket is the one malformation
        # common enough across providers to fix rather than fail on.
        return json.loads(_TRAILING_COMMA.sub(r"\1", cleaned))
