from flask.views import MethodView
from flask_jwt_extended import create_access_token, get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.data_service import delete_account, export_account_data
from app.accounts.models import PasswordResetToken, User
from app.accounts.schemas import (
    LoginSchema,
    PasswordResetConfirmSchema,
    PasswordResetRequestSchema,
    RegisterSchema,
    TokenSchema,
    UserSchema,
)
from app.common.email_service import send as send_email
from app.common.models import utcnow
from app.extensions import db

blp = Blueprint("accounts", __name__, url_prefix="/api/v1/auth", description="Registration & login")


@blp.route("/register")
class Register(MethodView):
    @blp.arguments(RegisterSchema)
    @blp.response(201, TokenSchema)
    def post(self, data):
        if User.query.filter_by(email=data["email"]).first():
            abort(409, message="An account with this email already exists.")

        user = User(email=data["email"], full_name=data.get("full_name"))
        user.set_password(data["password"])
        db.session.add(user)
        db.session.commit()

        return {"access_token": create_access_token(identity=user.id), "user": user}


@blp.route("/login")
class Login(MethodView):
    @blp.arguments(LoginSchema)
    @blp.response(200, TokenSchema)
    def post(self, data):
        user = User.query.filter_by(email=data["email"]).first()
        if user is None or not user.check_password(data["password"]):
            abort(401, message="Invalid email or password.")

        return {"access_token": create_access_token(identity=user.id), "user": user}


@blp.route("/me")
class Me(MethodView):
    @jwt_required()
    @blp.response(200, UserSchema)
    def get(self):
        return User.query.get_or_404(get_jwt_identity())

    @jwt_required()
    @blp.response(204)
    def delete(self):
        """Cascade-deletes every row tied to this account. Immediate,
        irreversible — the client is expected to have its own confirmation
        step before calling this (Settings "Delete my account and all data")."""
        delete_account(get_jwt_identity())


@blp.route("/me/export")
class MeExport(MethodView):
    @jwt_required()
    def get(self):
        return export_account_data(get_jwt_identity())


@blp.route("/password/reset-request")
class PasswordResetRequest(MethodView):
    @blp.arguments(PasswordResetRequestSchema)
    @blp.response(202)
    def post(self, data):
        """Always 202, whether or not the email is registered — the response
        can't reveal that, or it becomes a way to check who has an account.
        """
        user = User.query.filter_by(email=data["email"]).first()
        if user is not None:
            # A fresh request supersedes any still-valid code from a previous
            # one, so at most one code for this user is ever guessable.
            PasswordResetToken.query.filter_by(user_id=user.id, used_at=None).delete()
            token, raw_code = PasswordResetToken.issue(user.id)
            db.session.add(token)
            db.session.commit()
            send_email(
                user.email,
                "Your Health MEE password reset code",
                f"Your code is {raw_code}. It works once and expires in 30 minutes.\n\n"
                "If you didn't request this, you can ignore this email.",
            )


@blp.route("/password/reset-confirm")
class PasswordResetConfirm(MethodView):
    @blp.arguments(PasswordResetConfirmSchema)
    @blp.response(204)
    def post(self, data):
        user = User.query.filter_by(email=data["email"]).first()
        token = PasswordResetToken.find_valid(user.id, data["code"]) if user else None
        if token is None:
            db.session.commit()  # persist a failed attempt count even on a wrong guess
            abort(400, message="That code is invalid or has expired.")

        user.set_password(data["new_password"])
        token.used_at = utcnow()
        db.session.commit()
