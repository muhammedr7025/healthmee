"""Email delivery: mock mode (no SMTP host configured — logs the message,
no network call) vs real SMTP. Same pluggable-provider shape as
app/common/llm/factory.py and app/push/service.py.
"""

import smtplib
from email.message import EmailMessage

from flask import current_app


def _mode() -> str:
    return "smtp" if current_app.config.get("SMTP_HOST") else "mock"


def send(to_email: str, subject: str, body: str) -> None:
    if _mode() == "smtp":
        _send_smtp(to_email, subject, body)
        return

    # No SMTP configured — nothing left to fail on, so the caller (e.g. a
    # password-reset request) can proceed as if delivery succeeded. Logged
    # rather than silently dropped so the code is still retrievable in dev.
    current_app.logger.info("email (mock, not delivered) to=%s subject=%r\n%s", to_email, subject, body)


def _send_smtp(to_email: str, subject: str, body: str) -> None:
    cfg = current_app.config
    message = EmailMessage()
    message["From"] = cfg["SMTP_FROM_EMAIL"]
    message["To"] = to_email
    message["Subject"] = subject
    message.set_content(body)

    with smtplib.SMTP(cfg["SMTP_HOST"], cfg["SMTP_PORT"]) as smtp:
        if cfg.get("SMTP_USE_TLS", True):
            smtp.starttls()
        if cfg.get("SMTP_USERNAME"):
            smtp.login(cfg["SMTP_USERNAME"], cfg["SMTP_PASSWORD"])
        smtp.send_message(message)
