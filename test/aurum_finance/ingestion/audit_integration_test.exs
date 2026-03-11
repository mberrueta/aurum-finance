defmodule AurumFinance.Ingestion.AuditIntegrationTest do
  use AurumFinance.DataCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  alias AurumFinance.Audit
  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.MaterializationWorker

  describe "materialization workflow audit" do
    test "request_materialization/3 appends a materialization_requested audit event" do
      %{account: account, imported_file: imported_file} = build_import_context()

      _ready_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-audit-request"
        })

      assert {:ok, materialization} =
               Ingestion.request_materialization(account.id, imported_file.id,
                 requested_by: "reviewer@example.com"
               )

      [event] =
        Audit.list_audit_events(
          entity_type: "import_materialization",
          entity_id: materialization.id,
          action: "materialization_requested"
        )

      assert event.actor == "reviewer@example.com"
      assert event.channel == :web
      assert event.before == nil
      assert event.after["status"] == "pending"
      assert event.after["requested_by"] == "reviewer@example.com"

      assert event.metadata == %{
               "account_id" => account.id,
               "imported_file_id" => imported_file.id,
               "requested_by" => "reviewer@example.com"
             }
    end

    test "completed_with_errors appends a materialization_completed audit event" do
      %{account: account, imported_file: imported_file} = build_import_context()

      _ready_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-audit-complete-ready"
        })

      _mismatch_row =
        insert_imported_row(imported_file, account, %{
          row_index: 1,
          fingerprint: "fp-audit-complete-mismatch",
          currency: "EUR"
        })

      assert {:ok, materialization} =
               Ingestion.request_materialization(account.id, imported_file.id,
                 requested_by: "reviewer@example.com"
               )

      assert :ok =
               MaterializationWorker.perform(%Oban.Job{
                 args: %{
                   "account_id" => account.id,
                   "import_materialization_id" => materialization.id,
                   "imported_file_id" => imported_file.id
                 }
               })

      [event] =
        Audit.list_audit_events(
          entity_type: "import_materialization",
          entity_id: materialization.id,
          action: "materialization_completed"
        )

      assert event.actor == "system"
      assert event.channel == :system
      assert event.before["status"] == "processing"
      assert event.after["status"] == "completed_with_errors"
      assert event.after["rows_materialized"] == 1
      assert event.after["rows_failed"] == 1

      assert event.metadata == %{
               "account_id" => account.id,
               "imported_file_id" => imported_file.id,
               "requested_by" => "reviewer@example.com"
             }
    end

    test "terminal workflow failure appends a materialization_failed audit event" do
      %{account: account, imported_file: imported_file} = build_import_context()

      _ready_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-audit-failed-ready"
        })

      invalid_row =
        insert_imported_row(imported_file, account, %{
          row_index: 1,
          fingerprint: "fp-audit-failed",
          status: :invalid,
          validation_error: "placeholder"
        })

      overlong_reason = String.duplicate("x", 2001)

      assert {1, _} =
               from(imported_row in AurumFinance.Ingestion.ImportedRow,
                 where: imported_row.id == ^invalid_row.id
               )
               |> Repo.update_all(set: [validation_error: overlong_reason])

      assert {:ok, materialization} =
               Ingestion.request_materialization(account.id, imported_file.id,
                 requested_by: "reviewer@example.com"
               )

      assert {:error, %Ecto.Changeset{} = changeset} =
               MaterializationWorker.perform(%Oban.Job{
                 args: %{
                   "account_id" => account.id,
                   "import_materialization_id" => materialization.id,
                   "imported_file_id" => imported_file.id
                 }
               })

      assert "Row materialization outcome details must be at most 2000 characters." in errors_on(
               changeset
             ).outcome_reason

      [event] =
        Audit.list_audit_events(
          entity_type: "import_materialization",
          entity_id: materialization.id,
          action: "materialization_failed"
        )

      assert event.actor == "system"
      assert event.channel == :system
      assert event.before["status"] == "processing"
      assert event.after["status"] == "failed"
      assert event.after["error_message"] =~ "outcome_reason"
    end
  end

  describe "import deletion audit" do
    test "delete_imported_file/2 appends a narrow deleted audit event" do
      %{account: account, imported_file: imported_file} = build_import_context()

      _ready_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-audit-delete"
        })

      assert {:ok, _deleted_imported_file} =
               Ingestion.delete_imported_file(account.id, imported_file.id)

      [event] =
        Audit.list_audit_events(
          entity_type: "imported_file",
          entity_id: imported_file.id,
          action: "deleted"
        )

      assert event.actor == "system"
      assert event.channel == :system
      assert event.before["filename"] == "audit.csv"
      assert event.before["account_id"] == account.id
      assert event.after == nil
      assert event.metadata == %{"account_id" => account.id}
    end
  end

  defp build_import_context do
    entity = insert(:entity, name: "Audit materialization entity")

    account =
      insert(:account,
        entity: entity,
        entity_id: entity.id,
        name: "Audit materialization account"
      )

    {:ok, imported_file} =
      Ingestion.create_imported_file(%{
        account_id: account.id,
        filename: "audit.csv",
        sha256: String.duplicate("c", 64),
        format: :csv,
        status: :complete,
        storage_path: "/tmp/imports/audit.csv"
      })

    %{account: account, entity: entity, imported_file: imported_file}
  end

  defp insert_imported_row(imported_file, account, attrs) do
    defaults = %{
      imported_file_id: imported_file.id,
      account_id: account.id,
      row_index: 0,
      raw_data: %{"description" => "Coffee"},
      description: "Coffee",
      normalized_description: "coffee",
      posted_on: ~D[2026-03-10],
      amount: Decimal.new("-4.50"),
      currency: "USD",
      fingerprint: "fp-default",
      status: :ready
    }

    {:ok, imported_row} =
      defaults
      |> Map.merge(attrs)
      |> Ingestion.create_imported_row()

    imported_row
  end
end
