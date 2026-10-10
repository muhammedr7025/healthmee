from marshmallow import Schema, fields, validate


class DailyAggregateSchema(Schema):
    date = fields.String(dump_only=True)
    total_calories = fields.Float(dump_only=True)
    activity_minutes = fields.Float(dump_only=True)
    sleep_hours = fields.Float(dump_only=True, allow_none=True)
    mood_score = fields.Float(dump_only=True, allow_none=True)
    water_ml = fields.Float(dump_only=True)
    log_count = fields.Integer(dump_only=True)
    weight_kg = fields.Float(dump_only=True, allow_none=True)
    systolic = fields.Float(dump_only=True, allow_none=True)
    diastolic = fields.Float(dump_only=True, allow_none=True)
    glucose_mg_dl = fields.Float(dump_only=True, allow_none=True)
    heart_rate_bpm = fields.Float(dump_only=True, allow_none=True)


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
    sleep_days = fields.Integer(dump_only=True)
    avg_mood = fields.Float(dump_only=True, allow_none=True)
    total_activity_minutes = fields.Float(dump_only=True)
    avg_calories = fields.Float(dump_only=True, allow_none=True)
    avg_water_ml = fields.Float(dump_only=True, allow_none=True)
    avg_weight_kg = fields.Float(dump_only=True, allow_none=True)
    weight_change_kg = fields.Float(dump_only=True, allow_none=True)
    avg_systolic = fields.Float(dump_only=True, allow_none=True)
    avg_diastolic = fields.Float(dump_only=True, allow_none=True)
    avg_glucose_mg_dl = fields.Float(dump_only=True, allow_none=True)
    avg_heart_rate_bpm = fields.Float(dump_only=True, allow_none=True)
    vitals_days = fields.Integer(dump_only=True)


class MomentumSchema(Schema):
    label = fields.String(dump_only=True)  # starting|building|steady|slipping
    detail = fields.String(dump_only=True)


class NarrativeResponseSchema(Schema):
    period = fields.String(dump_only=True)
    start = fields.String(dump_only=True)
    end = fields.String(dump_only=True)
    summary = fields.String(dump_only=True)
    stats = fields.Nested(NarrativeStatsSchema, dump_only=True)
    previous = fields.Nested(NarrativeStatsSchema, dump_only=True)
    deltas = fields.Dict(keys=fields.String(), values=fields.Float(allow_none=True), dump_only=True)
    momentum = fields.Nested(MomentumSchema, dump_only=True)
    wins = fields.List(fields.String(), dump_only=True)
    watch = fields.List(fields.String(), dump_only=True)
    achievements = fields.List(fields.String(), dump_only=True)
    risks = fields.List(fields.String(), dump_only=True)
    recommendations = fields.List(fields.String(), dump_only=True)


class ScoreComponentSchema(Schema):
    key = fields.String(dump_only=True)
    label = fields.String(dump_only=True)
    points = fields.Integer(dump_only=True)
    max = fields.Integer(dump_only=True)
    detail = fields.String(dump_only=True)


class TodayScoreSchema(Schema):
    score = fields.Integer(dump_only=True)
    earned = fields.Integer(dump_only=True)
    achievable = fields.Integer(dump_only=True)
    components = fields.List(fields.Nested(ScoreComponentSchema), dump_only=True)
    mascot = fields.String(dump_only=True)
