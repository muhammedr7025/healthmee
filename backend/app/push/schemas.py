from marshmallow import Schema, fields, validate


class RegisterDeviceSchema(Schema):
    token = fields.String(required=True)
    platform = fields.String(required=False, load_default="unknown", validate=validate.OneOf(["ios", "android", "unknown"]))


class DeviceTokenSchema(Schema):
    id = fields.String(dump_only=True)
    platform = fields.String(dump_only=True)
    created_at = fields.String(dump_only=True)


class PushLogSchema(Schema):
    id = fields.String(dump_only=True)
    kind = fields.String(dump_only=True)
    title = fields.String(dump_only=True)
    body = fields.String(dump_only=True)
    delivery_mode = fields.String(dump_only=True)
    created_at = fields.String(dump_only=True)
