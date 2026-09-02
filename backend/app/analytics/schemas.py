from marshmallow import Schema, fields, validate


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


class NarrativeQuerySchema(Schema):
    period = fields.String(required=False, load_default="week", validate=validate.OneOf(["today", "week", "month", "custom"]))
    start = fields.Date(required=False, allow_none=True)
    end = fields.Date(required=False, allow_none=True)


class NarrativeStatsSchema(Schema):
    days_total = fields.Integer(dump_only=True)
    days_logged = fields.Integer(dump_only=True)
    log_count = fields.Integer(dump_only=True)
    avg_sleep = fields.Float(dump_only=True, allow_none=True)
    avg_mood = fields.Float(dump_only=True, allow_none=True)
    total_activity_minutes = fields.Float(dump_only=True)
    avg_calories = fields.Float(dump_only=True, allow_none=True)


class NarrativeResponseSchema(Schema):
    period = fields.String(dump_only=True)
    start = fields.String(dump_only=True)
    end = fields.String(dump_only=True)
    summary = fields.String(dump_only=True)
    stats = fields.Nested(NarrativeStatsSchema, dump_only=True)
    wins = fields.List(fields.String(), dump_only=True)
    watch = fields.List(fields.String(), dump_only=True)
