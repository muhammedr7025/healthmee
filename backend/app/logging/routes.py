from datetime import datetime, timedelta, timezone

from flask import current_app
from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.models import User
from app.billing.service import is_premium
from app.events.service import track
from app.extensions import db, limiter, user_or_ip
from app.logging.chat_history import get_chat_history
from app.logging.extraction.pipeline import process_message
from app.logging.models import ChatMessage, LogEntry
from app.logging.registry import get_type_catalog, sanitize_payload, validate_payload
from app.logging.schemas import (
    ChatHistoryQuerySchema,
    ChatHistorySchema,
    ChatMessageSchema,
    ChatResponseSchema,
    LogbookQuerySchema,
    LogEntrySchema,
    LogEntryUpdateSchema,
    LogTypeSchema,
)
from app.notifications.models import AlertLog

blp = Blueprint("logging", __name__, url_prefix="/api/v1", description="Chat logging & logbook")


@blp.route("/log-types")
class LogTypes(MethodView):
    """The type catalog the extractor works from, for the app's typed
    correction sheet — so a wrong calorie estimate can be fixed as a number
    and an enum as a choice, never as free text."""

    @jwt_required()
    @blp.response(200, LogTypeSchema(many=True))
    def get(self):
        return [
            {
                "name": t["name"],
                "description": t["description"],
                "fields": [
                    {"name": name, "type": spec["type"], "required": bool(spec.get("required")), "enum": spec.get("enum")}
                    for name, spec in t["schema"].items()
                ],
            }
            for t in get_type_catalog()
        ]


@blp.route("/chat/messages")
class ChatMessages(MethodView):
    # Every message is an LLM call; this is the cost ceiling per user.
    decorators = [limiter.limit("60/minute;600/day", methods=["POST"], key_func=user_or_ip)]

    @jwt_required()
    @blp.arguments(ChatHistoryQuerySchema, location="query")
    @blp.response(200, ChatHistorySchema)
    def get(self, args):
        return get_chat_history(get_jwt_identity(), args["limit"], before=args.get("before"))

    @jwt_required()
    @blp.arguments(ChatMessageSchema)
    @blp.response(201, ChatResponseSchema)
    def post(self, data):
        user = User.query.get_or_404(get_jwt_identity())
        return process_message(user, data["text"], data.get("media_asset_id"))


@blp.route("/logbook")
class Logbook(MethodView):
    @jwt_required()
    @blp.arguments(LogbookQuerySchema, location="query")
    @blp.response(200, LogEntrySchema(many=True))
    def get(self, args):
        user_id = get_jwt_identity()
        query = LogEntry.query.filter_by(user_id=user_id)
        if args.get("type"):
            query = query.filter(LogEntry.type == args["type"])

        # Timestamps are stored as naive UTC; a client bound like
        # 2026-10-11T00:00:00+05:30 has to be converted, not just stripped.
        start = _naive_utc(args.get("start"))
        end = _naive_utc(args.get("end"))
        if not is_premium(user_id):
            # Free tier: history capped at FREE_TIER_LOGBOOK_DAYS (paywall
            # "Unlimited history instead of 30 days"). Clamp rather than
            # reject, so a wider request just silently gets the free window.
            free_tier_cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(
                days=current_app.config["FREE_TIER_LOGBOOK_DAYS"]
            )
            start = max(start, free_tier_cutoff) if start else free_tier_cutoff
        if start:
            query = query.filter(LogEntry.timestamp >= start)
        if end:
            query = query.filter(LogEntry.timestamp <= end)

        query = query.order_by(LogEntry.timestamp.desc())
        page = query.paginate(page=args["page"], per_page=args["per_page"], error_out=False)
        return page.items


def _naive_utc(value: datetime | None) -> datetime | None:
    if value is None or value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


@blp.route("/log-entries/<string:entry_id>")
class LogEntryDetail(MethodView):
    """Backs the chat confirmation card's "Edit" action (dev-prompt: entries
    are saved immediately on extraction, so "editing" corrects the saved row
    rather than confirming a pending one)."""

    @jwt_required()
    @blp.arguments(LogEntryUpdateSchema)
    @blp.response(200, LogEntrySchema)
    def patch(self, data, entry_id):
        user_id = get_jwt_identity()
        entry = LogEntry.query.filter_by(id=entry_id, user_id=user_id).first_or_404()

        if "structured_payload" in data:
            # Same gate as extraction: an edit that doesn't fit the type's
            # schema would otherwise sit in the row and crash every recompute
            # of that day (float("lots")).
            payload, _dropped = sanitize_payload(entry.type, data["structured_payload"])
            errors = validate_payload(entry.type, payload)
            if errors:
                abort(422, message=f"That edit doesn't fit a {entry.type} entry: " + "; ".join(errors))
            data["structured_payload"] = payload
        if data.get("summary"):
            data["summary"] = data["summary"][:255]

        for key, value in data.items():
            setattr(entry, key, value)
        db.session.commit()
        _recompute(user_id, entry.timestamp)
        track(
            "entry_corrected",
            user_id,
            type=entry.type,
            fields_changed=sorted(k for k in ("summary", "raw_text", "structured_payload") if k in data),
        )
        return entry

    @jwt_required()
    @blp.response(204)
    def delete(self, entry_id):
        user_id = get_jwt_identity()
        entry = LogEntry.query.filter_by(id=entry_id, user_id=user_id).first_or_404()
        entry_timestamp = entry.timestamp
        # The chat card for this entry goes with it; alerts it raised stay as
        # a safety record, just no longer pointing at a row that's gone.
        entry_type = entry.type
        ChatMessage.query.filter_by(log_entry_id=entry.id).delete()
        AlertLog.query.filter_by(log_entry_id=entry.id).update({"log_entry_id": None})
        db.session.delete(entry)
        db.session.commit()
        _recompute(user_id, entry_timestamp)
        track("entry_deleted", user_id, type=entry_type)


def _recompute(user_id: str, timestamp_utc) -> None:
    from app.analytics.tasks import recompute_days
    from app.common.localtime import local_date_of, user_tz_offset

    offset = user_tz_offset(User.query.get_or_404(user_id))
    recompute_days(user_id, [local_date_of(timestamp_utc, offset)], offset)
