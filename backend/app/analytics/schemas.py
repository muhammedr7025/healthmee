from marshmallow import Schema, fields


class DailyAggregateSchema(Schema):
    date = fields.String(dump_only=True)
    total_calories = fields.Float(dump_only=True)
    activity_minutes = fields.Float(dump_only=True)
    sleep_hours = fields.Float(dump_only=True, allow_none=True)
    mood_score = fields.Float(dump_only=True, allow_none=True)
    water_ml = fields.Float(dump_only=True)
    log_count = fields.Integer(dump_only=True)


class TrendsQuerySchema(Schema):
    start = fields.Date(required=False, allow_none=True)
    end = fields.Date(required=False, allow_none=True)


class TrendsResponseSchema(Schema):
    days = fields.List(fields.Nested(DailyAggregateSchema), dump_only=True)
    callouts = fields.List(fields.String(), dump_only=True)
