"""Account-wide data operations that touch every domain table: full export
(Settings "Export my data") and full cascade delete (Settings "Delete my
account"). Kept in one place, rather than each domain package reaching into
the others, since both need the complete list of "everything tied to this
user" and that list needs to stay in sync as domains are added.
"""

from app.accounts.models import User
from app.billing.models import Subscription
from app.caregiver.models import CaregiverLink
from app.extensions import db
from app.goals.models import Goal
from app.logging.models import LogEntry
from app.media.models import MediaAsset
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
        "goals": [g.to_dict() for g in Goal.query.filter_by(user_id=user_id).all()],
        "alerts": [a.to_dict() for a in AlertLog.query.filter_by(user_id=user_id).all()],
        "caregiver_links": [
            c.to_dict()
            for c in CaregiverLink.query.filter(
                (CaregiverLink.owner_user_id == user_id) | (CaregiverLink.caregiver_user_id == user_id)
            ).all()
        ],
    }


def delete_account(user_id: str) -> None:
    """Deletes every row tied to this user, in FK-safe (children-first)
    order, then the user row itself. Object storage (media assets already
    uploaded to MinIO/S3) is not swept — the DB rows referencing them are
    removed, but the underlying files aren't deleted from the bucket.
    """
    LogEntry.query.filter_by(user_id=user_id).delete()
    AlertLog.query.filter_by(user_id=user_id).delete()
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
    from app.analytics.models import DailyAggregate

    DailyAggregate.query.filter_by(user_id=user_id).delete()

    User.query.filter_by(id=user_id).delete()
    db.session.commit()
