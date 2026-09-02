from marshmallow import Schema, fields


class ChatMessageSchema(Schema):
    text = fields.String(required=True)
    media_asset_id = fields.String(required=False, allow_none=True)


class LogEntrySchema(Schema):
    id = fields.String(dump_only=True)
    type = fields.String(dump_only=True)
    timestamp = fields.String(dump_only=True)
    payload = fields.Dict(dump_only=True, attribute="structured_payload")
    raw_text = fields.String(dump_only=True, allow_none=True)
    summary = fields.String(dump_only=True, allow_none=True)
    media_asset_id = fields.String(dump_only=True, allow_none=True)


class LogEntryUpdateSchema(Schema):
    summary = fields.String(required=False, allow_none=True)
    raw_text = fields.String(required=False, allow_none=True)
    structured_payload = fields.Dict(required=False, attribute="structured_payload", data_key="payload")


class ChatResponseSchema(Schema):
    entries = fields.List(fields.Dict(), dump_only=True)
    alerts = fields.List(fields.Dict(), dump_only=True)
    reply = fields.String(dump_only=True)
    validation_errors = fields.List(fields.String(), dump_only=True)


class LogbookQuerySchema(Schema):
    type = fields.String(required=False, allow_none=True)
    start = fields.DateTime(required=False, allow_none=True)
    end = fields.DateTime(required=False, allow_none=True)
    page = fields.Integer(required=False, load_default=1)
    per_page = fields.Integer(required=False, load_default=50)
