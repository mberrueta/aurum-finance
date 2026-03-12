defmodule AurumFinance.Repo.Migrations.CreateReconciliationTables do
  use Ecto.Migration

  def up do
    create table(:reconciliation_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :account_id, references(:accounts, type: :binary_id, on_delete: :restrict), null: false
      add :entity_id, references(:entities, type: :binary_id, on_delete: :restrict), null: false
      add :statement_date, :date, null: false
      add :statement_balance, :decimal, null: false
      add :completed_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:reconciliation_sessions, [:entity_id])
    create index(:reconciliation_sessions, [:account_id])

    create unique_index(
             :reconciliation_sessions,
             [:account_id],
             name: :reconciliation_sessions_account_id_active_index,
             where: "completed_at IS NULL"
           )

    create table(:posting_reconciliation_states, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :entity_id, references(:entities, type: :binary_id, on_delete: :restrict), null: false
      add :posting_id, references(:postings, type: :binary_id, on_delete: :restrict), null: false

      add :reconciliation_session_id,
          references(:reconciliation_sessions, type: :binary_id, on_delete: :nilify_all)

      add :status, :string, null: false
      add :reason, :string

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(
             :posting_reconciliation_states,
             [:posting_id],
             name: :posting_reconciliation_states_posting_id_index
           )

    create index(:posting_reconciliation_states, [:entity_id])
    create index(:posting_reconciliation_states, [:reconciliation_session_id])
    create index(:posting_reconciliation_states, [:entity_id, :status])

    create constraint(
             :posting_reconciliation_states,
             :posting_reconciliation_states_status_check,
             check: "status IN ('cleared', 'reconciled')"
           )

    create table(:reconciliation_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :posting_reconciliation_state_id,
          references(:posting_reconciliation_states, type: :binary_id, on_delete: :nilify_all)

      add :reconciliation_session_id,
          references(:reconciliation_sessions, type: :binary_id, on_delete: :restrict),
          null: false

      add :posting_id, references(:postings, type: :binary_id, on_delete: :restrict), null: false
      add :from_status, :string
      add :to_status, :string
      add :actor, :string, null: false
      add :channel, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false, default: fragment("NOW()")
      add :metadata, :map

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:reconciliation_audit_logs, [:reconciliation_session_id])
    create index(:reconciliation_audit_logs, [:posting_id])
    create index(:reconciliation_audit_logs, [:posting_reconciliation_state_id])
    create index(:reconciliation_audit_logs, [:occurred_at])

    execute """
    CREATE OR REPLACE FUNCTION reconciliation_audit_logs_append_only()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'reconciliation_audit_logs is append-only: UPDATE and DELETE are prohibited';
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER reconciliation_audit_logs_append_only_trigger
      BEFORE UPDATE OR DELETE ON reconciliation_audit_logs
      FOR EACH ROW
      EXECUTE FUNCTION reconciliation_audit_logs_append_only();
    """

    execute """
    CREATE OR REPLACE FUNCTION posting_reconciliation_states_no_unreconcile()
    RETURNS TRIGGER AS $$
    BEGIN
      IF OLD.status = 'reconciled' THEN
        RAISE EXCEPTION
          'posting_reconciliation_states: reconciled rows cannot be updated or deleted';
      END IF;

      RETURN COALESCE(NEW, OLD);
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER posting_reconciliation_states_no_unreconcile_trigger
      BEFORE UPDATE OR DELETE ON posting_reconciliation_states
      FOR EACH ROW
      EXECUTE FUNCTION posting_reconciliation_states_no_unreconcile();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS posting_reconciliation_states_no_unreconcile_trigger ON posting_reconciliation_states;"
    execute "DROP FUNCTION IF EXISTS posting_reconciliation_states_no_unreconcile();"

    execute "DROP TRIGGER IF EXISTS reconciliation_audit_logs_append_only_trigger ON reconciliation_audit_logs;"
    execute "DROP FUNCTION IF EXISTS reconciliation_audit_logs_append_only();"

    drop table(:reconciliation_audit_logs)
    drop constraint(:posting_reconciliation_states, :posting_reconciliation_states_status_check)
    drop_if_exists index(:posting_reconciliation_states, [:entity_id, :status])
    drop_if_exists index(:posting_reconciliation_states, [:reconciliation_session_id])
    drop_if_exists index(:posting_reconciliation_states, [:entity_id])

    drop_if_exists index(
                     :posting_reconciliation_states,
                     [:posting_id],
                     name: :posting_reconciliation_states_posting_id_index
                   )

    drop table(:posting_reconciliation_states)

    drop_if_exists index(
                     :reconciliation_sessions,
                     [:account_id],
                     name: :reconciliation_sessions_account_id_active_index
                   )

    drop_if_exists index(:reconciliation_sessions, [:account_id])
    drop_if_exists index(:reconciliation_sessions, [:entity_id])
    drop table(:reconciliation_sessions)
  end
end
