"""Per-type side-effect handlers, run synchronously right after a LogEntry is
persisted and before the chat reply is sent (PRD §9 — allergy checks must run
before the reply is generated). Each handler returns any AlertLog rows it
created so the API response can surface them immediately.
"""

from app.accounts.models import User
from app.extensions import db
from app.logging.models import LogEntry
from app.medical_profile.models import Allergy
from app.notifications.models import AlertLog


def allergy_check_handler(user: User, log_entry: LogEntry) -> list[AlertLog]:
    allergies = Allergy.query.filter_by(user_id=user.id).all()
    if not allergies:
        return []

    # Keyword match against the logged food text — good enough for an MVP
    # safety net; a real allergen ontology/ingredient lookup is future work.
    haystack = " ".join(log_entry.structured_payload.get("food_items", [])).lower()
    haystack += " " + (log_entry.raw_text or "").lower()

    alerts = []
    for allergy in allergies:
        if allergy.name.lower() in haystack:
            alert = AlertLog(
                user_id=user.id,
                log_entry_id=log_entry.id,
                trigger_type="allergy",
                severity="hard",
                message=f"This may contain {allergy.name}, which is in your allergy list. Please double-check before eating.",
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
