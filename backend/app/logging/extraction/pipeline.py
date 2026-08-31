from app.accounts.models import User
from app.common.llm import get_llm_provider
from app.extensions import db
from app.logging.models import LogEntry
from app.logging.registry import get_type, get_type_catalog, validate_payload


def process_message(user: User, text: str, media_asset_id: str | None = None) -> dict:
    """LLM extraction -> per-type validation -> per-type handlers, in that
    order (dev-prompt §6). Invalid entries are dropped rather than failing
    the whole message, since a message can contain several loggable things.
    """
    provider = get_llm_provider()
    result = provider.extract(text, get_type_catalog())

    created_entries: list[LogEntry] = []
    all_alerts = []
    validation_errors: list[str] = []
    touched_dates = set()

    for extracted in result.entries:
        errors = validate_payload(extracted.type, extracted.payload)
        if errors:
            validation_errors.extend(errors)
            continue

        log_entry = LogEntry(
            user_id=user.id,
            type=extracted.type,
            structured_payload=extracted.payload,
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
