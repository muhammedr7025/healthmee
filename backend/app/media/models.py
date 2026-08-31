from app.common.models import TimestampMixin, gen_uuid
from app.extensions import db


class MediaAsset(db.Model, TimestampMixin):
    __tablename__ = "media_assets"

    id = db.Column(db.String(36), primary_key=True, default=gen_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    kind = db.Column(db.String(20), nullable=False)  # photo|video
    storage_key = db.Column(db.String(512), nullable=False)
    content_type = db.Column(db.String(128), nullable=True)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "kind": self.kind,
            "storage_key": self.storage_key,
            "content_type": self.content_type,
            "created_at": self.created_at.isoformat(),
        }
