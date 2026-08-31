from marshmallow import Schema, fields, validate


class RegisterSchema(Schema):
    email = fields.Email(required=True)
    password = fields.String(required=True, validate=validate.Length(min=8))
    full_name = fields.String(required=False, allow_none=True)


class LoginSchema(Schema):
    email = fields.Email(required=True)
    password = fields.String(required=True)


class UserSchema(Schema):
    id = fields.String(dump_only=True)
    email = fields.Email(dump_only=True)
    full_name = fields.String(dump_only=True, allow_none=True)
    onboarding_completed = fields.Boolean(dump_only=True)


class TokenSchema(Schema):
    access_token = fields.String(dump_only=True)
    user = fields.Nested(UserSchema, dump_only=True)
