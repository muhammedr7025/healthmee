"""daily vitals on aggregates

Revision ID: e4f5a6b7c8d9
Revises: d3e4f5a6b7c8
Create Date: 2026-10-11 00:30:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e4f5a6b7c8d9'
down_revision = 'd3e4f5a6b7c8'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('daily_aggregates', schema=None) as batch_op:
        batch_op.add_column(sa.Column('weight_kg', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('systolic', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('diastolic', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('glucose_mg_dl', sa.Float(), nullable=True))
        batch_op.add_column(sa.Column('heart_rate_bpm', sa.Float(), nullable=True))


def downgrade():
    with op.batch_alter_table('daily_aggregates', schema=None) as batch_op:
        batch_op.drop_column('heart_rate_bpm')
        batch_op.drop_column('glucose_mg_dl')
        batch_op.drop_column('diastolic')
        batch_op.drop_column('systolic')
        batch_op.drop_column('weight_kg')
