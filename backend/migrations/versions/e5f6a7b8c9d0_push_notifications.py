"""push notifications (device tokens + push log)

Revision ID: e5f6a7b8c9d0
Revises: d4e5f6a7b8c9
Create Date: 2026-09-02 14:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'e5f6a7b8c9d0'
down_revision = 'd4e5f6a7b8c9'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('device_tokens',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('token', sa.String(length=512), nullable=False),
    sa.Column('platform', sa.String(length=20), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'token', name='uq_device_tokens_user_token')
    )
    with op.batch_alter_table('device_tokens', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_device_tokens_user_id'), ['user_id'], unique=False)

    op.create_table('push_logs',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('kind', sa.String(length=30), nullable=False),
    sa.Column('title', sa.String(length=255), nullable=False),
    sa.Column('body', sa.Text(), nullable=False),
    sa.Column('delivery_mode', sa.String(length=10), nullable=False),
    sa.Column('dedupe_key', sa.String(length=255), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('push_logs', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_push_logs_user_id'), ['user_id'], unique=False)


def downgrade():
    with op.batch_alter_table('push_logs', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_push_logs_user_id'))

    op.drop_table('push_logs')
    with op.batch_alter_table('device_tokens', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_device_tokens_user_id'))

    op.drop_table('device_tokens')
