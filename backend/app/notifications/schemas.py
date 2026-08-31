from marshmallow import Schema, fields


class AlertLogSchema(Schema):
    id = fields.String(dump_only=True)
    log_entry_id = fields.String(dump_only=True, allow_none=True)
    trigger_type = fields.String(dump_only=True)
    severity = fields.String(dump_only=True)
    message = fields.String(dump_only=True)
    acknowledged = fields.Boolean()
    created_at = fields.String(dump_only=True)
