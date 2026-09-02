"""Push delivery: mock mode (no FCM credentials — logs the decision to
PushLog, no network call) vs real Firebase Cloud Messaging. Same pluggable-
provider shape as app/common/llm/factory.py and app/billing/service.py.
"""

from flask import current_app

from app.extensions import db
from app.push.models import DeviceToken, PushLog


def _mode() -> str:
    return "fcm" if current_app.config.get("FCM_CREDENTIALS_JSON") else "mock"


def already_sent_today(user_id: str, dedupe_key: str) -> bool:
    return PushLog.query.filter_by(user_id=user_id, dedupe_key=dedupe_key).first() is not None


def send(user_id: str, kind: str, title: str, body: str, dedupe_key: str) -> PushLog | None:
    """Sends (or, in mock mode, records) a push. Returns None if this
    dedupe_key was already sent — callers should compute a key that's
    stable per user per day per kind (e.g. "quiet_nudge:2026-09-02") so the
    beat schedule can run frequently without spamming.
    """
    if already_sent_today(user_id, dedupe_key):
        return None

    mode = _mode()
    log = PushLog(user_id=user_id, kind=kind, title=title, body=body, delivery_mode=mode, dedupe_key=dedupe_key)

    if mode == "fcm":
        tokens = [t.token for t in DeviceToken.query.filter_by(user_id=user_id).all()]
        if tokens:
            _send_fcm(tokens, title, body)
        # No registered device is not an error — the log row still records
        # that the reminder logic fired; it just had nowhere to deliver to.

    db.session.add(log)
    db.session.commit()
    return log


def _send_fcm(tokens: list[str], title: str, body: str) -> None:
    import firebase_admin
    from firebase_admin import credentials, messaging

    if not firebase_admin._apps:
        cred = credentials.Certificate(current_app.config["FCM_CREDENTIALS_JSON"])
        firebase_admin.initialize_app(cred)

    for token in tokens:
        try:
            messaging.send(messaging.Message(notification=messaging.Notification(title=title, body=body), token=token))
        except Exception:
            continue  # a dead/unregistered token shouldn't block the rest
