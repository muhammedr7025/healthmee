"""Per-type side-effect handlers, run synchronously right after a LogEntry is
persisted and before the chat reply is sent (PRD §9 — allergy checks must run
before the reply is generated). Each handler returns any AlertLog rows it
created so the API response can surface them immediately.
"""

from app.accounts.models import User
from app.extensions import db
from app.logging.allergens import matching_allergens
from app.logging.models import LogEntry
from app.medical_profile.models import Allergy
from app.notifications.models import AlertLog


def allergy_check_handler(user: User, log_entry: LogEntry) -> list[AlertLog]:
    """Safety net behind the model: whole-word matching with everyday
    synonyms (groundnut → peanut, paneer → milk) across the food items, the
    allergens the model itself named, and the raw text. "nut" no longer
    fires inside "donut"."""
    allergies = Allergy.query.filter_by(user_id=user.id).all()
    if not allergies:
        return []

    payload = log_entry.structured_payload or {}
    texts = [*(payload.get("food_items") or []), *(payload.get("allergens") or []), log_entry.raw_text or ""]
    hits = matching_allergens([a.name for a in allergies], [str(t) for t in texts])

    alerts = []
    for name in hits:
        alert = AlertLog(
            user_id=user.id,
            log_entry_id=log_entry.id,
            trigger_type="allergy",
            severity="hard",
            message=f"This may contain {name}, which is in your allergy list. Please double-check before eating.",
        )
        db.session.add(alert)
        alerts.append(alert)
    return alerts


def symptom_disclaimer_handler(user: User, log_entry: LogEntry) -> list[AlertLog]:
    alert = AlertLog(
        user_id=user.id,
        log_entry_id=log_entry.id,
        trigger_type="symptom_disclaimer",
        severity="soft",
        message="This isn't a medical diagnosis — if it's concerning, please consult a doctor.",
    )
    db.session.add(alert)
    return [alert]
