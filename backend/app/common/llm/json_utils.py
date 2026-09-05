"""Tolerant JSON parsing for LLM responses.

Models routinely wrap JSON in ```json fences or prepend a sentence, even when
told not to. Rather than let that turn into a 500 on a user's chat message,
pull the outermost JSON value out of whatever came back.
"""

import json
import re

_FENCE_START = re.compile(r"^\s*```(?:json)?\s*", re.IGNORECASE)
_FENCE_END = re.compile(r"\s*```\s*$")


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

    return json.loads(cleaned)
