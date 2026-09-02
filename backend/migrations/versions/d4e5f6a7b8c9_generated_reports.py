"""generated reports

Revision ID: d4e5f6a7b8c9
Revises: c3d9e7a1f5b6
Create Date: 2026-09-02 13:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd4e5f6a7b8c9'
down_revision = 'c3d9e7a1f5b6'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('generated_reports',
    sa.Column('id', sa.String(length=36), nullable=False),
    sa.Column('user_id', sa.String(length=36), nullable=False),
    sa.Column('storage_key', sa.String(length=512), nullable=False),
    sa.Column('range_start', sa.Date(), nullable=False),
    sa.Column('range_end', sa.Date(), nullable=False),
    sa.Column('page_count', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('generated_reports', schema=None) as batch_op:
        batch_op.create_index(batch_op.f('ix_generated_reports_user_id'), ['user_id'], unique=False)


def downgrade():
    with op.batch_alter_table('generated_reports', schema=None) as batch_op:
        batch_op.drop_index(batch_op.f('ix_generated_reports_user_id'))

    op.drop_table('generated_reports')
