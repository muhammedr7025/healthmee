"""chat/alert foreign keys survive entry deletion; indexes for the hot paths

Deleting a log entry 500'd on Postgres because chat_messages and alert_logs
pointed at it with no ON DELETE rule (SQLite tests never enforced it).

Revision ID: a6b7c8d9e0f1
Revises: f5a6b7c8d9e0
Create Date: 2026-10-11 03:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'a6b7c8d9e0f1'
down_revision = 'f5a6b7c8d9e0'
branch_labels = None
depends_on = None

_FKS = [
    # (table, column, constraint name as Postgres auto-named it, referenced table)
    ('chat_messages', 'log_entry_id', 'chat_messages_log_entry_id_fkey', 'log_entries'),
    ('chat_messages', 'alert_id', 'chat_messages_alert_id_fkey', 'alert_logs'),
    ('alert_logs', 'log_entry_id', 'alert_logs_log_entry_id_fkey', 'log_entries'),
]


def upgrade():
    if op.get_bind().dialect.name == 'postgresql':
        for table, column, name, target in _FKS:
            op.execute(f'ALTER TABLE {table} DROP CONSTRAINT IF EXISTS {name}')
            op.create_foreign_key(name, table, target, [column], ['id'], ondelete='SET NULL')

    op.create_index('ix_chat_messages_log_entry_id', 'chat_messages', ['log_entry_id'])
    op.create_index('ix_chat_messages_alert_id', 'chat_messages', ['alert_id'])
    op.create_index('ix_alert_logs_log_entry_id', 'alert_logs', ['log_entry_id'])
    # Logbook, recompute and reports filter by user and order by time without a type.
    op.create_index('ix_log_entries_user_ts', 'log_entries', ['user_id', 'timestamp'])


def downgrade():
    op.drop_index('ix_log_entries_user_ts', table_name='log_entries')
    op.drop_index('ix_alert_logs_log_entry_id', table_name='alert_logs')
    op.drop_index('ix_chat_messages_alert_id', table_name='chat_messages')
    op.drop_index('ix_chat_messages_log_entry_id', table_name='chat_messages')
    if op.get_bind().dialect.name == 'postgresql':
        for table, column, name, target in _FKS:
            op.execute(f'ALTER TABLE {table} DROP CONSTRAINT IF EXISTS {name}')
            op.create_foreign_key(name, table, target, [column], ['id'])
