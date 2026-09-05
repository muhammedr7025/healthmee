from flask import current_app

from app.accounts.models import User
from app.common.llm import get_llm_provider
from app.common.llm.mock_provider import MockProvider
from app.extensions import db
from app.logging.models import LogEntry
from app.logging.registry import get_type, get_type_catalog, sanitize_payload, validate_payload
from app.media.models import MediaAsset
from app.media.storage import download_bytes


def _extract_with_fallback(text: str, image_bytes: bytes | None, image_mime_type: str | None):
    """Run the configured provider, falling back to the offline keyword
    extractor if it errors.

    The free Gemini tier allows only 15 requests/minute and 500/day, so
    hitting a limit mid-day is a realistic Tuesday — and losing what someone
    just told us because of that would be the worst possible failure. A
    degraded entry beats no entry.
    """
    provider = get_llm_provider()
    try:
        return provider.extract(
            text, get_type_catalog(), image_bytes=image_bytes, image_mime_type=image_mime_type
        )
    except Exception:
        current_app.logger.exception("LLM extraction failed; falling back to the offline extractor")
        if isinstance(provider, MockProvider):
            raise  # nothing left to fall back to
        return MockProvider().extract(
            text, get_type_catalog(), image_bytes=image_bytes, image_mime_type=image_mime_type
        )


def process_message(user: User, text: str, media_asset_id: str | None = None) -> dict:
    """LLM extraction -> per-type validation -> per-type handlers, in that
    order (dev-prompt §6). Invalid entries are dropped rather than failing
    the whole message, since a message can contain several loggable things.

    A `media_asset_id` (VitaChat photo logging) is resolved to real image
    bytes here and handed to the provider's vision path — providers without
    vision support (MockProvider, or a real provider given a non-image
    asset) just ignore the bytes and fall back to text-only extraction.
    """
    image_bytes = None
    image_mime_type = None
    if media_asset_id:
        asset = MediaAsset.query.filter_by(id=media_asset_id, user_id=user.id).first()
        if asset and asset.kind == "photo":
            try:
                image_bytes = download_bytes(asset.storage_key)
                image_mime_type = asset.content_type
            except Exception:
                image_bytes = None  # object storage hiccup — degrade to text-only rather than failing the message

    result = _extract_with_fallback(text, image_bytes, image_mime_type)

    created_entries: list[LogEntry] = []
    all_alerts = []
    validation_errors: list[str] = []
    touched_dates = set()

    for extracted in result.entries:
        # A model routinely gets one optional field wrong in a way that
        # still reads as reasonable ("very poor" for sleep quality, "anxious"
        # for mood) — sanitize drops just that field rather than losing the
        # whole entry over it. Required-field problems still fail below.
        payload, dropped_fields = sanitize_payload(extracted.type, extracted.payload)
        validation_errors.extend(dropped_fields)

        errors = validate_payload(extracted.type, payload)
        if errors:
            validation_errors.extend(errors)
            continue

        log_entry = LogEntry(
            user_id=user.id,
            type=extracted.type,
            structured_payload=payload,
            raw_text=text,
            summary=extracted.summary,
            media_asset_id=media_asset_id,
        )
        db.session.add(log_entry)
        db.session.flush()  # assign id/timestamp defaults before handlers run

        definition = get_type(extracted.type)
        for handler in definition.handlers:
            all_alerts.extend(handler(user, log_entry))

        created_entries.append(log_entry)
        touched_dates.add(log_entry.timestamp.date())

    db.session.commit()

    if touched_dates:
        from app.analytics.tasks import recompute_daily_aggregate

        for date in touched_dates:
            recompute_daily_aggregate.delay(user.id, date.isoformat())

    return {
        "entries": [e.to_dict() for e in created_entries],
        "alerts": [a.to_dict() for a in all_alerts],
        "reply": result.reply,
        "validation_errors": validation_errors,
    }
