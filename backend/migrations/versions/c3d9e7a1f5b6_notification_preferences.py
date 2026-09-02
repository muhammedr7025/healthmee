"""notification preferences

Revision ID: c3d9e7a1f5b6
Revises: 8a1f0c6d4b2e
Create Date: 2026-09-02 12:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'c3d9e7a1f5b6'
down_revision = '8a1f0c6d4b2e'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('notification_preferences',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('medication_reminders', sa.Boolean(), nullable=False),
    sa.Column('quiet_nudges', sa.Boolean(), nullable=False),
    sa.Column('streak_milestones', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', name='uq_notification_preferences_user_id')
    )
    with op.batch_alter_table('notification_preferences', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_notification_preferences_user_id'), ['user_id'], unique=True)


def downgrade():
    with op.batch_alter_table('notification_preferences', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_notification_preferences_user_id'))

    op.drop_table('notification_preferences')
