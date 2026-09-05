import hashlib
import secrets
from datetime import timedelta, timezone

from werkzeug.security import check_password_hash, generate_password_hash

from app.common.models import TimestampMixin, gen_uuid, utcnow
from app.extensions import db


class User(db.Model, TimestampMixin):
    __tablename__ = "users"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    full_name = db.Column(db.String(255), nullable=True)
    onboarding_completed = db.Column(db.Boolean, default=False, nullable=False)

    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)


class PasswordResetToken(db.Model, TimestampMixin):
    """A one-time code emailed to prove the requester controls the account's
    inbox. Stored as a hash (like a password) rather than the plaintext code,
    so a DB read alone can't be used to reset someone's password.
    """

    __tablename__ = "password_reset_tokens"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    token_hash = db.Column(db.String(64), nullable=False, index=True)
    expires_at = db.Column(db.DateTime, nullable=False)
    used_at = db.Column(db.DateTime, nullable=True)
    # A 6-digit code only has a million possibilities — capping attempts
    # keeps someone from just brute-forcing it within the expiry window.
    attempts = db.Column(db.Integer, nullable=False, default=0)

    EXPIRES_AFTER = timedelta(minutes=30)
    MAX_ATTEMPTS = 8

    @staticmethod
    def _hash(raw_token: str) -> str:
        return hashlib.sha256(raw_token.encode()).hexdigest()

    @classmethod
    def issue(cls, user_id: str) -> tuple["PasswordResetToken", str]:
        """Returns the persisted row plus the one-time plaintext code — the
        only point at which the plaintext exists, since it's never stored."""
        raw_token = f"{secrets.randbelow(1_000_000):06d}"
        row = cls(user_id=user_id, token_hash=cls._hash(raw_token), expires_at=utcnow() + cls.EXPIRES_AFTER)
        return row, raw_token

    @classmethod
    def find_valid(cls, user_id: str, raw_token: str) -> "PasswordResetToken | None":
        """Scoped to the user the caller claims to be (resolved from the
        email on the confirm request) — a guessed code that happens to
        match some other user's token shouldn't reset a different account.
        A wrong guess still consumes an attempt even when it hits the right
        row, so this must be called at most once per submitted code.
        """
        row = (
            cls.query.filter_by(user_id=user_id, used_at=None)
            .filter(cls.attempts < cls.MAX_ATTEMPTS)
            .order_by(cls.created_at.desc())
            .first()
        )
        if row is None:
            return None
        if row.expires_at.replace(tzinfo=timezone.utc) < utcnow():
            return None
        if row.token_hash != cls._hash(raw_token):
            row.attempts += 1
            return None
        return row
