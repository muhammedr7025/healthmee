"""Product analytics and AI call logs, kept in our own Postgres.

Events carry ids and counts, never message text or health values — the
point is to see *that* someone logged, corrected, retried or rated, not
what they said. PHI stays in the domain tables.
"""

from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class ProductEvent(db.Model, TimestampMixin):
    __tablename__ = "product_events"
    __table_args__ = (
        db.Index("ix_product_events_name_created", "name", "created_at"),
        db.Index("ix_product_events_user_created", "user_id", "created_at"),
    )

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    name = db.Column(db.String(64), nullable=False)
    props = db.Column(db.JSON, nullable=False, default=dict)
    platform = db.Column(db.String(20), nullable=False, default="server")  # ios|android|server
    app_version = db.Column(db.String(32), nullable=True)
    session_id = db.Column(db.String(64), nullable=True)
    client_ts = db.Column(db.DateTime, nullable=True)  # when the device says it happened


class LlmCall(db.Model, TimestampMixin):
    """One row per model call: who paid for it, how long it took, what came
    back. This is the data behind "fallback rate", "p95 latency" and
    "cost per user" — none of which existed before."""

    __tablename__ = "llm_calls"
    __table_args__ = (
        db.Index("ix_llm_calls_created", "created_at"),
        db.Index("ix_llm_calls_user_created", "user_id", "created_at"),
    )

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    purpose = db.Column(db.String(20), nullable=False)  # extract|narrate|lab_report
    provider = db.Column(db.String(20), nullable=False)  # anthropic|openai|gemini|mock
    model = db.Column(db.String(64), nullable=True)
    latency_ms = db.Column(db.Integer, nullable=False)
    input_chars = db.Column(db.Integer, nullable=True)
    has_media = db.Column(db.Boolean, nullable=False, default=False)
    output_entries = db.Column(db.Integer, nullable=True)
    dropped_entries = db.Column(db.Integer, nullable=True)
    fell_back = db.Column(db.Boolean, nullable=False, default=False)
    failed = db.Column(db.Boolean, nullable=False, default=False)
    usage_input = db.Column(db.Integer, nullable=True)
    usage_output = db.Column(db.Integer, nullable=True)
