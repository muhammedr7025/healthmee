from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from flask_smorest import abort

from app.extensions import db, limiter, user_or_ip
from app.media.models import MediaAsset
from app.media.schemas import PresignRequestSchema, PresignResponseSchema
from app.media.storage import presign_upload

blp = Blueprint("media", __name__, url_prefix="/api/v1/media", description="Signed media uploads")

# What each kind may be. The storage key's extension is derived from the
# content type, so this also keeps arbitrary extensions out of the bucket.
ALLOWED_CONTENT_TYPES = {
    "photo": {"image/jpeg", "image/png", "image/heic", "image/heif", "image/webp"},
    "video": {"video/mp4", "video/quicktime"},
    "document": {"application/pdf"},
}


@blp.route("/presign")
class Presign(MethodView):
    decorators = [limiter.limit("60/hour", key_func=user_or_ip)]

    @jwt_required()
    @blp.arguments(PresignRequestSchema)
    @blp.response(201, PresignResponseSchema)
    def post(self, data):
        user_id = get_jwt_identity()
        content_type = data["content_type"].lower().split(";")[0].strip()
        if content_type not in ALLOWED_CONTENT_TYPES[data["kind"]]:
            abort(422, message=f"{content_type} isn't an accepted type for a {data['kind']}.")
        presigned = presign_upload(user_id, content_type, data["kind"])

        asset = MediaAsset(
            user_id=user_id,
            kind=data["kind"],
            storage_key=presigned["storage_key"],
            content_type=data["content_type"],
        )
        db.session.add(asset)
        db.session.commit()

        return {**presigned, "media_asset_id": asset.id}
