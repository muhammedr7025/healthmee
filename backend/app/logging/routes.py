from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.accounts.models import User
from app.logging.extraction.pipeline import process_message
from app.logging.models import LogEntry
from app.logging.schemas import ChatMessageSchema, ChatResponseSchema, LogbookQuerySchema, LogEntrySchema

blp = Blueprint("logging", __name__, url_prefix="/api/v1", description="Chat logging & logbook")


@blp.route("/chat/messages")
class ChatMessages(MethodView):
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
        query = LogEntry.query.filter_by(user_id=get_jwt_identity())
        if args.get("type"):
            query = query.filter(LogEntry.type == args["type"])
        if args.get("start"):
            query = query.filter(LogEntry.timestamp >= args["start"])
        if args.get("end"):
            query = query.filter(LogEntry.timestamp <= args["end"])

        query = query.order_by(LogEntry.timestamp.desc())
        page = query.paginate(page=args["page"], per_page=args["per_page"], error_out=False)
        return page.items
