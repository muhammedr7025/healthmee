"""Account-wide data operations that touch every domain table: full export
(Settings "Export my data") and full cascade delete (Settings "Delete my
account"). Kept in one place, rather than each domain package reaching into
the others, since both need the complete list of "everything tied to this
user" and that list needs to stay in sync as domains are added.
"""

from app.accounts.models import PasswordResetToken, User
from app.billing.models import Subscription
from app.caregiver.models import CaregiverLink
from app.extensions import db
from app.goals.models import Goal
from app.logging.models import ChatMessage, LogEntry
from app.media.models import MediaAsset
from app.media.storage import delete_objects
from app.medical_profile.models import Allergy, LabResult, MedicalProfile
from app.notifications.models import AlertLog, NotificationPreference
from app.push.models import DeviceToken, PushLog
from app.reports.models import GeneratedReport


def export_account_data(user_id: str) -> dict:
    user = User.query.get_or_404(user_id)

    return {
        "account": {
            "email": user.email,
            "full_name": user.full_name,
            "created_at": user.created_at.isoformat(),
        },
        "medical_profiles": [p.to_dict() for p in MedicalProfile.query.filter_by(user_id=user_id).all()],
        "allergies": [a.to_dict() for a in Allergy.query.filter_by(user_id=user_id).all()],
        "lab_results": [l.to_dict() for l in LabResult.query.filter_by(user_id=user_id).all()],
        "log_entries": [e.to_dict() for e in LogEntry.query.filter_by(user_id=user_id).all()],
        "chat_messages": [m.to_dict() for m in ChatMessage.query.filter_by(user_id=user_id).all()],
        "goals": [g.to_dict() for g in Goal.query.filter_by(user_id=user_id).all()],
        "alerts": [a.to_dict() for a in AlertLog.query.filter_by(user_id=user_id).all()],
        "caregiver_links": [
            c.to_dict()
            for c in CaregiverLink.query.filter(
                (CaregiverLink.owner_user_id == user_id) | (CaregiverLink.caregiver_user_id == user_id)
            ).all()
        ],
        # Everything else the account owns — a data export that left these out
        # wasn't an export.
        "medications": [_row(m) for m in _medications(user_id)],
        "medication_doses": [_row(d) for d in _doses(user_id)],
        "notification_preferences": [p.to_dict() for p in NotificationPreference.query.filter_by(user_id=user_id).all()],
        "devices": [d.to_dict() for d in DeviceToken.query.filter_by(user_id=user_id).all()],
        "reports": [_row(r) for r in GeneratedReport.query.filter_by(user_id=user_id).all()],
        "subscription": [_row(s) for s in Subscription.query.filter_by(user_id=user_id).all()],
        "push_log": [p.to_dict() for p in PushLog.query.filter_by(user_id=user_id).all()],
    }


def _row(obj) -> dict:
    """Column-wise dump for models without a to_dict, with datetimes as ISO."""
    out = {}
    for column in obj.__table__.columns:
        value = getattr(obj, column.name)
        out[column.name] = value.isoformat() if hasattr(value, "isoformat") else value
    return out


def _medications(user_id: str):
    from app.medications.models import MedicationSchedule

    return MedicationSchedule.query.filter_by(user_id=user_id).all()


def _doses(user_id: str):
    from app.medications.models import MedicationDose

    return MedicationDose.query.filter_by(user_id=user_id).all()


def delete_account(user_id: str) -> None:
    """Deletes every row tied to this user, in FK-safe (children-first)
    order, then the user row itself. Object storage (media assets already
    uploaded to MinIO/S3) is not swept — the DB rows referencing them are
    removed, but the underlying files aren't deleted from the bucket.
    """
    # Object keys first: the rows are about to go, and the files should go with them.
    storage_keys = [a.storage_key for a in MediaAsset.query.filter_by(user_id=user_id).all()]
    storage_keys += [r.storage_key for r in GeneratedReport.query.filter_by(user_id=user_id).all()]

    ChatMessage.query.filter_by(user_id=user_id).delete()
    AlertLog.query.filter_by(user_id=user_id).delete()
    LogEntry.query.filter_by(user_id=user_id).delete()
    Allergy.query.filter_by(user_id=user_id).delete()
    LabResult.query.filter_by(user_id=user_id).delete()
    MedicalProfile.query.filter_by(user_id=user_id).delete()
    Goal.query.filter_by(user_id=user_id).delete()
    MediaAsset.query.filter_by(user_id=user_id).delete()
    CaregiverLink.query.filter(
        (CaregiverLink.owner_user_id == user_id) | (CaregiverLink.caregiver_user_id == user_id)
    ).delete()
    Subscription.query.filter_by(user_id=user_id).delete()
    NotificationPreference.query.filter_by(user_id=user_id).delete()
    GeneratedReport.query.filter_by(user_id=user_id).delete()
    DeviceToken.query.filter_by(user_id=user_id).delete()
    PushLog.query.filter_by(user_id=user_id).delete()

    # DailyAggregate lives in app.analytics — imported lazily to avoid a
    # circular import (analytics doesn't otherwise depend on accounts).
    from app.analytics.models import DailyAggregate, NarrativeCache
    from app.medications.models import MedicationDose, MedicationSchedule

    DailyAggregate.query.filter_by(user_id=user_id).delete()
    NarrativeCache.query.filter_by(user_id=user_id).delete()
    MedicationDose.query.filter_by(user_id=user_id).delete()
    MedicationSchedule.query.filter_by(user_id=user_id).delete()
    PasswordResetToken.query.filter_by(user_id=user_id).delete()

    User.query.filter_by(id=user_id).delete()
    db.session.commit()

    delete_objects(storage_keys)
