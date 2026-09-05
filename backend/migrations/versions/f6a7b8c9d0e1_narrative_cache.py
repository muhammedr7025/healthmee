"""narrative cache

Revision ID: f6a7b8c9d0e1
Revises: e5f6a7b8c9d0
Create Date: 2026-09-05 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f6a7b8c9d0e1'
down_revision = 'e5f6a7b8c9d0'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('narrative_cache',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('period', sa.String(length=20), nullable=False),
    sa.Column('stats_fingerprint', sa.String(length=64), nullable=False),
    sa.Column('summary', sa.Text(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('user_id', 'period', name='uq_narrative_cache_user_period')
    )
    with op.batch_alter_table('narrative_cache', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_narrative_cache_user_id'), ['user_id'], unique=False)


def downgrade():
    with op.batch_alter_table('narrative_cache', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_narrative_cache_user_id'))

    op.drop_table('narrative_cache')
