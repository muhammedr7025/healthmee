from datetime import date

from flask.views import MethodView
from flask_jwt_extended import get_jwt_identity, jwt_required
from flask_smorest import Blueprint

from app.extensions import db
from app.goals.models import Goal
from app.goals.schemas import GoalSchema

blp = Blueprint("goals", __name__, url_prefix="/api/v1/goals", description="Goal tracking")


@blp.route("")
class Goals(MethodView):
    @jwt_required()
    @blp.response(200, GoalSchema(many=True))
    def get(self):
        return Goal.query.filter_by(user_id=get_jwt_identity()).all()

    @jwt_required()
    @blp.arguments(GoalSchema)
    @blp.response(201, GoalSchema)
    def post(self, data):
        goal = Goal(user_id=get_jwt_identity(), start_date=date.today(), **data)
        db.session.add(goal)
        db.session.commit()
        return goal


@blp.route("/<string:goal_id>")
class GoalDetail(MethodView):
    @jwt_required()
    @blp.arguments(GoalSchema(partial=True))
    @blp.response(200, GoalSchema)
    def patch(self, data, goal_id):
        goal = Goal.query.filter_by(id=goal_id, user_id=get_jwt_identity()).first_or_404()
        for key, value in data.items():
            setattr(goal, key, value)
        db.session.commit()
        return goal

    @jwt_required()
    @blp.response(204)
    def delete(self, goal_id):
        goal = Goal.query.filter_by(id=goal_id, user_id=get_jwt_identity()).first_or_404()
        db.session.delete(goal)
        db.session.commit()
