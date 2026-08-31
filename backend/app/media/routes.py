from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.media.models import MediaAsset
from app.media.schemas import PresignRequestSchema, PresignResponseSchema
from app.media.storage import presign_upload

blp = Blueprint("media", __name__, url_prefix="/api/v1/media", description="Signed media uploads")


@blp.route("/presign")
class Presign(MethodView):
    @jwt_required()
    @blp.arguments(PresignRequestSchema)
    @blp.response(201, PresignResponseSchema)
    def post(self, data):
        user_id = get_jwt_identity()
        presigned = presign_upload(user_id, data["content_type"], data["kind"])

        asset = MediaAsset(
            user_id=user_id,
            kind=data["kind"],
            storage_key=presigned["storage_key"],
            content_type=data["content_type"],
        )
        db.session.add(asset)
        db.session.commit()

        return {**presigned, "media_asset_id": asset.id}
