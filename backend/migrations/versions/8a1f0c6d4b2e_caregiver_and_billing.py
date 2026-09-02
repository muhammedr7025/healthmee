"""caregiver links and subscriptions

Revision ID: 8a1f0c6d4b2e
Revises: 24726eb270ed
Create Date: 2026-09-02 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '8a1f0c6d4b2e'
down_revision = '24726eb270ed'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('caregiver_links',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('owner_user_id', sa.String(length=36), nullable=False),
    sa.Column('caregiver_user_id', sa.String(length=36), nullable=True),
    sa.Column('caregiver_email', sa.String(length=255), nullable=False),
    sa.Column('status', sa.String(length=20), nullable=False),
    sa.Column('can_view_logs', sa.Boolean(), nullable=False),
    sa.Column('can_view_trends_reports', sa.Boolean(), nullable=False),
    sa.Column('can_edit_profile', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['caregiver_user_id'], ['users.id'], ),
    sa.ForeignKeyConstraint(['owner_user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('caregiver_links', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_caregiver_links_caregiver_email'), ['caregiver_email'], unique=False)
        batch_op.create_index(batch_op.f('ix_caregiver_links_caregiver_user_id'), ['caregiver_user_id'], unique=False)
        batch_op.create_index(batch_op.f('ix_caregiver_links_owner_user_id'), ['owner_user_id'], unique=False)

    op.create_table('subscriptions',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('plan', sa.String(length=20), nullable=False),
    sa.Column('status', sa.String(length=20), nullable=False),
    sa.Column('billing_mode', sa.String(length=10), nullable=False),
    sa.Column('stripe_customer_id', sa.String(length=255), nullable=True),
    sa.Column('stripe_subscription_id', sa.String(length=255), nullable=True),
    sa.Column('current_period_end', sa.DateTime(), nullable=True),
    sa.Column('cancel_at_period_end', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', name='uq_subscriptions_user_id')
    )
    with op.batch_alter_table('subscriptions', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_subscriptions_user_id'), ['user_id'], unique=True)


def downgrade():
    with op.batch_alter_table('subscriptions', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_subscriptions_user_id'))

    op.drop_table('subscriptions')
    with op.batch_alter_table('caregiver_links', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_caregiver_links_owner_user_id'))
        batch_op.drop_index(batch_op.f('ix_caregiver_links_caregiver_user_id'))
        batch_op.drop_index(batch_op.f('ix_caregiver_links_caregiver_email'))

    op.drop_table('caregiver_links')
