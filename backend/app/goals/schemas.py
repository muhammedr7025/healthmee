from marshmallow import Schema, fields, validate


class GoalSchema(Schema):
    id = fields.String(dump_only=True)
    type = fields.String(required=True)
    target_value = fields.Dict(required=True)
    start_value = fields.Dict(required=False, allow_none=True)
    start_date = fields.Date(dump_only=True)
    target_date = fields.Date(required=False, allow_none=True)
    status = fields.String(
        required=False, load_default="active", validate=validate.OneOf(["active", "completed", "abandoned"])
    )
