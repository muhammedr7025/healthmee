from flask.views import MethodView
from flask_jwt_extended import create_access_token, get_jwt_identity, jwt_required
from flask_smorest import Blueprint, abort

from app.accounts.data_service import delete_account, export_account_data
from app.accounts.models import User
from app.accounts.schemas import LoginSchema, RegisterSchema, TokenSchema, UserSchema
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
