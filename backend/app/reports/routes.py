from flask.views import MethodView
from flask_jwt_extended import jwt_required
from flask_smorest import Blueprint, abort

blp = Blueprint("reports", __name__, url_prefix="/api/v1/reports", description="PDF report export (Phase 2)")


@blp.route("")
class Reports(MethodView):
    @jwt_required()
    def get(self):
        abort(501, message="PDF report export is planned for Phase 2 and isn't available yet.")
