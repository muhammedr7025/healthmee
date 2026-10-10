from marshmallow import Schema, fields, validate

from app.events.service import EVENT_NAME


class ClientEventSchema(Schema):
    name = fields.String(required=True, validate=validate.Regexp(EVENT_NAME, error="Event names are snake_case, 2–64 chars."))
    props = fields.Dict(required=False, load_default=dict)
    client_ts = fields.DateTime(required=False, allow_none=True)


class EventBatchSchema(Schema):
    platform = fields.String(required=True, validate=validate.OneOf(["ios", "android", "web", "other"]))
    app_version = fields.String(required=False, allow_none=True, validate=validate.Length(max=32))
    session_id = fields.String(required=False, allow_none=True, validate=validate.Length(max=64))
    events = fields.List(fields.Nested(ClientEventSchema), required=True, validate=validate.Length(min=1, max=50))


class EventBatchResponseSchema(Schema):
    accepted = fields.Integer(dump_only=True)
