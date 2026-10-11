"""The golden set: real-shaped messages and what the extractor must make of
them. Runs against the offline extractor in CI so a regex tweak can't
silently change what a message logs; scripts/eval_live.py runs the same
file against the configured real provider."""

import json
from pathlib import Path

import pytest

CASES = json.loads((Path(__file__).parent / "golden" / "messages.json").read_text())


@pytest.mark.parametrize("case", CASES, ids=[c["text"] for c in CASES])
def test_golden_message(auth_client, case):
    resp = auth_client.post("/api/v1/chat/messages", json={"text": case["text"]})
    assert resp.status_code == 201, resp.get_json()
    body = resp.get_json()

    assert sorted(e["type"] for e in body["entries"]) == sorted(case["types"]), body["entries"]
    for type_name, expected in (case.get("expect") or {}).items():
        payload = next(e["payload"] for e in body["entries"] if e["type"] == type_name)
        for key, value in expected.items():
            assert payload.get(key) == value, f"{case['text']!r}: {type_name}.{key} = {payload.get(key)!r}, expected {value!r}"
    if case.get("question"):
        assert body["question"], "expected a clarifying question"
