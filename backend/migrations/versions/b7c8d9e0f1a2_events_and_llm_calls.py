"""product events and llm call log

Revision ID: b7c8d9e0f1a2
Revises: a6b7c8d9e0f1
Create Date: 2026-10-11 04:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'b7c8d9e0f1a2'
down_revision = 'a6b7c8d9e0f1'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'product_events',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=True),
        sa.Column('name', sa.String(length=64), nullable=False),
        sa.Column('props', sa.JSON(), nullable=False),
        sa.Column('platform', sa.String(length=20), nullable=False),
        sa.Column('app_version', sa.String(length=32), nullable=True),
        sa.Column('session_id', sa.String(length=64), nullable=True),
        sa.Column('client_ts', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_product_events_name_created', 'product_events', ['name', 'created_at'])
    op.create_index('ix_product_events_user_created', 'product_events', ['user_id', 'created_at'])

    op.create_table(
        'llm_calls',
        sa.Column('id', sa.String(length=36), nullable=False),
        sa.Column('user_id', sa.String(length=36), nullable=True),
        sa.Column('purpose', sa.String(length=20), nullable=False),
        sa.Column('provider', sa.String(length=20), nullable=False),
        sa.Column('model', sa.String(length=64), nullable=True),
        sa.Column('latency_ms', sa.Integer(), nullable=False),
        sa.Column('input_chars', sa.Integer(), nullable=True),
        sa.Column('has_media', sa.Boolean(), nullable=False),
        sa.Column('output_entries', sa.Integer(), nullable=True),
        sa.Column('dropped_entries', sa.Integer(), nullable=True),
        sa.Column('fell_back', sa.Boolean(), nullable=False),
        sa.Column('failed', sa.Boolean(), nullable=False),
        sa.Column('usage_input', sa.Integer(), nullable=True),
        sa.Column('usage_output', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='SET NULL'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_llm_calls_created', 'llm_calls', ['created_at'])
    op.create_index('ix_llm_calls_user_created', 'llm_calls', ['user_id', 'created_at'])


def downgrade():
    op.drop_table('llm_calls')
    op.drop_table('product_events')
