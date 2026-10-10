from marshmallow import Schema, fields, validate

_TIME = validate.Regexp(r"^([01]\d|2[0-3]):[0-5]\d$", error="Times must look like 08:00 or 20:30.")


class MedicationScheduleSchema(Schema):
    id = fields.String(dump_only=True)
    name = fields.String(required=True, validate=validate.Length(min=1, max=255))
    dose = fields.String(required=False, allow_none=True, validate=validate.Length(max=64))
    times = fields.List(fields.String(validate=_TIME), required=True, validate=validate.Length(min=1, max=8))
    days_of_week = fields.List(
        fields.Integer(validate=validate.Range(min=0, max=6)), required=False, allow_none=True, load_default=None
    )
    active = fields.Boolean(required=False, load_default=True)
    notes = fields.String(required=False, allow_none=True)


class MedicationScheduleUpdateSchema(Schema):
    name = fields.String(required=False, validate=validate.Length(min=1, max=255))
    dose = fields.String(required=False, allow_none=True, validate=validate.Length(max=64))
    times = fields.List(fields.String(validate=_TIME), required=False, validate=validate.Length(min=1, max=8))
    days_of_week = fields.List(fields.Integer(validate=validate.Range(min=0, max=6)), required=False, allow_none=True)
    active = fields.Boolean(required=False)
    notes = fields.String(required=False, allow_none=True)


class DoseMarkSchema(Schema):
    date = fields.Date(required=False, allow_none=True)  # local day; default today
    time = fields.String(required=True, validate=_TIME)
    status = fields.String(required=True, validate=validate.OneOf(["taken", "skipped", "pending"]))


class DoseItemSchema(Schema):
    schedule_id = fields.String(dump_only=True)
    name = fields.String(dump_only=True)
    dose = fields.String(dump_only=True, allow_none=True)
    time = fields.String(dump_only=True)
    status = fields.String(dump_only=True)
    marked_at = fields.String(dump_only=True, allow_none=True)


class DayPlanSchema(Schema):
    date = fields.String(dump_only=True)
    items = fields.List(fields.Nested(DoseItemSchema), dump_only=True)
    taken = fields.Integer(dump_only=True)
    total = fields.Integer(dump_only=True)
    adherence_pct = fields.Integer(dump_only=True, allow_none=True)
