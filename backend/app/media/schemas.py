from marshmallow import Schema, fields, validate


class PresignRequestSchema(Schema):
    content_type = fields.String(required=True)
    # "document" is a PDF (lab reports from a hospital portal); photo/video
    # are camera captures.
    kind = fields.String(required=True, validate=validate.OneOf(["photo", "video", "document"]))


class PresignResponseSchema(Schema):
    upload_url = fields.String(dump_only=True)
    storage_key = fields.String(dump_only=True)
    media_asset_id = fields.String(dump_only=True)


class MediaAssetSchema(Schema):
    id = fields.String(dump_only=True)
    kind = fields.String(dump_only=True)
    storage_key = fields.String(dump_only=True)
    content_type = fields.String(dump_only=True, allow_none=True)
