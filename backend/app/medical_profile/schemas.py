from marshmallow import Schema, fields, validate


class AllergySchema(Schema):
    id = fields.String(dump_only=True)
    name = fields.String(required=True)
    severity = fields.String(
        required=False, load_default="moderate", validate=validate.OneOf(["mild", "moderate", "severe"])
    )
    notes = fields.String(required=False, allow_none=True)


class MedicalProfileSchema(Schema):
    id = fields.String(dump_only=True)
    version = fields.Integer(dump_only=True)
    conditions = fields.List(fields.String(), required=False, load_default=list)
    medications = fields.List(fields.String(), required=False, load_default=list)
    baseline_vitals = fields.Dict(required=False, load_default=dict)
    notes = fields.String(required=False, allow_none=True)
    created_at = fields.String(dump_only=True)


class LabResultSchema(Schema):
    id = fields.String(dump_only=True)
    source = fields.String(required=False, load_default="manual", validate=validate.OneOf(["manual", "ocr"]))
    test_name = fields.String(required=True)
    value = fields.String(required=True)
    unit = fields.String(required=False, allow_none=True)
    reference_range = fields.String(required=False, allow_none=True)
    taken_at = fields.DateTime(required=True)
    media_asset_id = fields.String(required=False, allow_none=True)


class ScanLabReportSchema(Schema):
    media_asset_id = fields.String(required=True)


class GoalIntakeSchema(Schema):
    type = fields.String(required=True)
    target_value = fields.Dict(required=True)
    target_date = fields.Date(required=False, allow_none=True)


class OnboardingSchema(Schema):
    full_name = fields.String(required=False, allow_none=True)
    conditions = fields.List(fields.String(), required=False, load_default=list)
    medications = fields.List(fields.String(), required=False, load_default=list)
    allergies = fields.List(fields.Nested(AllergySchema), required=False, load_default=list)
    baseline_vitals = fields.Dict(required=False, load_default=dict)
    goals = fields.List(fields.Nested(GoalIntakeSchema), required=False, load_default=list)
    consent_given = fields.Boolean(required=True)
