"""medication schedules and dose marks

Revision ID: f5a6b7c8d9e0
Revises: e4f5a6b7c8d9
Create Date: 2026-10-11 01:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f5a6b7c8d9e0'
down_revision = 'e4f5a6b7c8d9'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'medication_schedules',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('dose', sa.String(length=64), nullable=True),
        sa.Column('times', sa.JSON(), nullable=False),
        sa.Column('days_of_week', sa.JSON(), nullable=True),
        sa.Column('active', sa.Boolean(), nullable=False),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    with op.batch_alter_table('medication_schedules', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_medication_schedules_user_id'), ['user_id'], unique=False)

    op.create_table(
        'medication_doses',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=False),
        sa.Column('schedule_id', sa.String(length=36), nullable=False),
        sa.Column('scheduled_date', sa.Date(), nullable=False),
        sa.Column('scheduled_time', sa.String(length=5), nullable=False),
        sa.Column('status', sa.String(length=10), nullable=False),
        sa.Column('marked_at', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['schedule_id'], ['medication_schedules.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('schedule_id', 'scheduled_date', 'scheduled_time', name='uq_medication_dose_slot'),
    )
    with op.batch_alter_table('medication_doses', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_medication_doses_user_id'), ['user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_medication_doses_schedule_id'), ['schedule_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_medication_doses_scheduled_date'), ['scheduled_date'], unique=False)


def downgrade():
    op.drop_table('medication_doses')
    op.drop_table('medication_schedules')
