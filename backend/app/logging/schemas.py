from marshmallow import Schema, fields, validate


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


class LogTypeFieldSchema(Schema):
    name = fields.String(dump_only=True)
    type = fields.String(dump_only=True)  # str|number|bool|list[str]|list[number]|dict
    required = fields.Boolean(dump_only=True)
    enum = fields.List(fields.String(), dump_only=True, allow_none=True)


class LogTypeSchema(Schema):
    name = fields.String(dump_only=True)
    description = fields.String(dump_only=True)
    fields = fields.List(fields.Nested(LogTypeFieldSchema), dump_only=True)


class ChatResponseSchema(Schema):
    entries = fields.List(fields.Dict(), dump_only=True)
    alerts = fields.List(fields.Dict(), dump_only=True)
    # True when the real model failed and the offline extractor logged this
    # turn instead — the app asks the user to glance at the card.
    degraded = fields.Boolean(dump_only=True)
    reply = fields.String(dump_only=True)
    validation_errors = fields.List(fields.String(), dump_only=True)


class ChatHistoryQuerySchema(Schema):
    # Bounded: history is unbounded now that it persists, and each photo row
    # costs a presigned-URL signing call — an unbounded limit was a cheap way
    # to make the API do an arbitrary amount of work.
    limit = fields.Integer(required=False, load_default=200, validate=validate.Range(min=1, max=500))


class ChatHistorySchema(Schema):
    items = fields.List(fields.Dict(), dump_only=True)
    welcome_back_message = fields.String(dump_only=True, allow_none=True)


class LogbookQuerySchema(Schema):
    type = fields.String(required=False, allow_none=True)
    start = fields.DateTime(required=False, allow_none=True)
    end = fields.DateTime(required=False, allow_none=True)
    page = fields.Integer(required=False, load_default=1, validate=validate.Range(min=1))
    per_page = fields.Integer(required=False, load_default=50, validate=validate.Range(min=1, max=200))
