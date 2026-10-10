import json
import re

from flask import current_app

from app.events.models import LlmCall, ProductEvent
from app.extensions import db

EVENT_NAME = re.compile(r"^[a-z][a-z0-9_]{1,63}$")
MAX_PROPS_BYTES = 4096


def track(name: str, user_id: str | None = None, *, platform: str = "server", commit: bool = True, **props) -> None:
    """Record a product event. Never raises: analytics must not be able to
    break the request it describes."""
    try:
        row = ProductEvent(user_id=user_id, name=name, props=_bounded(props), platform=platform)
        db.session.add(row)
        if commit:
            db.session.commit()
    except Exception:
        db.session.rollback()
        current_app.logger.exception("track(%s) failed", name)


def record_llm_call(
    *,
    purpose: str,
    provider: str,
    model: str | None,
    latency_ms: int,
    user_id: str | None = None,
    input_chars: int | None = None,
    has_media: bool = False,
    output_entries: int | None = None,
    dropped_entries: int | None = None,
    fell_back: bool = False,
    failed: bool = False,
    usage: dict | None = None,
    commit: bool = True,
) -> None:
    try:
        db.session.add(
            LlmCall(
                user_id=user_id,
                purpose=purpose,
                provider=provider,
                model=model,
                latency_ms=latency_ms,
                input_chars=input_chars,
                has_media=has_media,
                output_entries=output_entries,
                dropped_entries=dropped_entries,
                fell_back=fell_back,
                failed=failed,
                usage_input=(usage or {}).get("input_tokens"),
                usage_output=(usage or {}).get("output_tokens"),
            )
        )
        if commit:
            db.session.commit()
    except Exception:
        db.session.rollback()
        current_app.logger.exception("record_llm_call(%s) failed", purpose)


def _bounded(props: dict) -> dict:
    """Keep a runaway client from storing a novel per event."""
    if not isinstance(props, dict):
        return {}
    encoded = json.dumps(props, default=str)
    if len(encoded) <= MAX_PROPS_BYTES:
        return json.loads(encoded)
    return {"_truncated": True, "_bytes": len(encoded)}
