defmodule AurumFinance.Repo.Migrations.HardenImmutability do
  use Ecto.Migration

  # ---------------------------------------------------------------------------
  # audit_events — fully append-only (no UPDATE, no DELETE)
  # postings     — fully append-only (no UPDATE, no DELETE)
  # transactions — protected facts: DELETE blocked, UPDATE restricted to
  #                lifecycle fields only (voided_at, correlation_id).
  #                Immutable fact fields (entity_id, date, description,
  #                source_type, inserted_at) can never be changed.
  #                voided_at is set-once: NULL → non-NULL only, never reversed.
  #
  # Note: transactions has no `status` column. Void state is represented
  # entirely by voided_at (NULL = active, non-NULL = voided). The trigger
  # enforces this set-once semantic at the DB level.
  # ---------------------------------------------------------------------------

  def up do
    # -- audit_events: add metadata, remove updated_at -----------------------
    alter table(:audit_events) do
      add :metadata, :map
      remove :updated_at
    end

    # -- audit_events: append-only trigger ------------------------------------
    execute """
    CREATE OR REPLACE FUNCTION audit_events_append_only_trigger()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'audit_events is append-only: UPDATE and DELETE are prohibited';
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_events_append_only
      BEFORE UPDATE OR DELETE ON audit_events
      FOR EACH ROW
      EXECUTE FUNCTION audit_events_append_only_trigger();
    """

    # -- postings: append-only trigger ----------------------------------------
    execute """
    CREATE OR REPLACE FUNCTION postings_append_only_trigger()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'postings is append-only: UPDATE and DELETE are prohibited';
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER postings_append_only
      BEFORE UPDATE OR DELETE ON postings
      FOR EACH ROW
      EXECUTE FUNCTION postings_append_only_trigger();
    """

    # -- transactions: allowlist-based update protection + delete block --------
    # Columns that MAY change: voided_at, correlation_id (and only these).
    # All other columns are immutable once inserted.
    # voided_at rules:
    #   NULL → non-NULL : allowed (voiding a transaction)
    #   non-NULL → NULL : forbidden (cannot un-void)
    #   non-NULL → different non-NULL : forbidden (cannot change once set)
    # transactions schema columns (no updated_at):
    #   id, entity_id, date, description, source_type, correlation_id,
    #   voided_at, inserted_at
    execute """
    CREATE OR REPLACE FUNCTION transactions_immutability_trigger()
    RETURNS TRIGGER AS $$
    BEGIN
      IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'transactions are protected ledger facts: DELETE is prohibited';
        RETURN NULL;
      END IF;

      IF TG_OP = 'UPDATE' THEN
        -- Allowlist: only voided_at and correlation_id may change.
        -- Any change to any other column is rejected.
        IF OLD.id           IS DISTINCT FROM NEW.id           OR
           OLD.entity_id    IS DISTINCT FROM NEW.entity_id    OR
           OLD.date         IS DISTINCT FROM NEW.date         OR
           OLD.description  IS DISTINCT FROM NEW.description  OR
           OLD.source_type  IS DISTINCT FROM NEW.source_type  OR
           OLD.inserted_at  IS DISTINCT FROM NEW.inserted_at  THEN
          RAISE EXCEPTION
            'transactions: only voided_at and correlation_id may be updated; all other columns are immutable';
        END IF;

        -- voided_at is set-once: NULL → non-NULL only.
        -- Reversing (non-NULL → NULL) or changing (non-NULL → different non-NULL) are both forbidden.
        IF OLD.voided_at IS NOT NULL AND NEW.voided_at IS DISTINCT FROM OLD.voided_at THEN
          RAISE EXCEPTION
            'transactions: voided_at is set-once (NULL -> non-NULL only); it cannot be cleared or changed after being set';
        END IF;
      END IF;

      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER transactions_immutability
      BEFORE UPDATE OR DELETE ON transactions
      FOR EACH ROW
      EXECUTE FUNCTION transactions_immutability_trigger();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS transactions_immutability ON transactions;"
    execute "DROP FUNCTION IF EXISTS transactions_immutability_trigger();"

    execute "DROP TRIGGER IF EXISTS postings_append_only ON postings;"
    execute "DROP FUNCTION IF EXISTS postings_append_only_trigger();"

    execute "DROP TRIGGER IF EXISTS audit_events_append_only ON audit_events;"
    execute "DROP FUNCTION IF EXISTS audit_events_append_only_trigger();"

    alter table(:audit_events) do
      remove :metadata
      add :updated_at, :utc_datetime_usec
    end
  end
end
