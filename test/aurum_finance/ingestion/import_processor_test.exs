defmodule AurumFinance.Ingestion.ImportProcessorTest do
  use AurumFinance.DataCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  alias AurumFinance.Audit
  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.Fingerprint
  alias AurumFinance.Ingestion.ImportWorker
  alias AurumFinance.Ingestion.PubSub

  describe "enqueue_import_processing/1" do
    test "processes a stored file asynchronously and summarizes ready, duplicate, and invalid rows" do
      entity = insert(:entity, name: "Async import entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Async import account")

      assert {:ok, existing_import} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "existing.csv",
                 sha256: String.duplicate("7", 64),
                 format: :csv,
                 status: :complete,
                 storage_path: "/tmp/imports/existing.csv"
               })

      existing_fingerprint =
        Fingerprint.build(%{
          posted_on: "2026-03-10",
          description: "coffee shop",
          amount: "-4.50",
          currency: "USD"
        })

      assert {:ok, _row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: existing_import.id,
                 account_id: account.id,
                 row_index: 1,
                 raw_data: %{"Description" => "Coffee Shop"},
                 description: "Coffee Shop",
                 normalized_description: "coffee shop",
                 posted_on: ~D[2026-03-10],
                 amount: Decimal.new("-4.50"),
                 currency: "USD",
                 fingerprint: existing_fingerprint,
                 status: :ready
               })

      csv = """
      Date,Description,Amount,Currency
      2026-03-10,Coffee Shop,-4.50,USD
      2026-03-11,Salary,1000.00,USD
      2026-03-12,Broken amount,wat,USD
      """

      assert {:ok, imported_file} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "statement.csv",
                 content: csv,
                 content_type: "text/csv"
               })

      assert :ok = PubSub.subscribe_imported_file(imported_file.id)

      assert {:ok, %Oban.Job{} = job} = Ingestion.enqueue_import_processing(imported_file)
      assert job.queue == "imports"

      assert_enqueued(
        worker: ImportWorker,
        queue: :imports,
        args: %{"account_id" => account.id, "imported_file_id" => imported_file.id}
      )

      assert %{failure: 0, success: 1, snoozed: 0} = Oban.drain_queue(queue: :imports)

      assert_receive {:import_updated,
                      %{
                        account_id: account_id,
                        imported_file_id: imported_file_id,
                        status: :processing
                      }}

      assert account_id == account.id
      assert imported_file_id == imported_file.id

      assert_receive {:import_updated,
                      %{
                        account_id: completed_account_id,
                        imported_file_id: completed_imported_file_id,
                        status: :complete
                      }}

      assert completed_account_id == account.id
      assert completed_imported_file_id == imported_file.id

      processed_import = Ingestion.get_imported_file!(account.id, imported_file.id)

      assert processed_import.status == :complete
      assert processed_import.row_count == 3
      assert processed_import.imported_row_count == 1
      assert processed_import.skipped_row_count == 1
      assert processed_import.invalid_row_count == 1
      assert processed_import.error_message == nil
      assert %DateTime{} = processed_import.processed_at

      [started_event, completed_event] =
        processed_import.id
        |> fetch_import_audit_events()
        |> Enum.sort_by(& &1.occurred_at, {:asc, DateTime})

      assert started_event.action == "processing_started"
      assert started_event.actor == "system"
      assert started_event.channel == :system
      assert started_event.before["status"] == "pending"
      assert started_event.after["status"] == "processing"
      assert started_event.metadata == %{"account_id" => account.id}

      assert completed_event.action == "processing_completed"
      assert completed_event.before["status"] == "processing"
      assert completed_event.after["status"] == "complete"
      assert completed_event.after["imported_row_count"] == 1
      assert completed_event.after["skipped_row_count"] == 1
      assert completed_event.after["invalid_row_count"] == 1

      rows =
        Ingestion.list_imported_rows(
          account_id: account.id,
          imported_file_id: processed_import.id
        )

      assert Enum.map(rows, & &1.status) == [:duplicate, :ready, :invalid]
      assert Enum.at(rows, 0).skip_reason == "already imported"
      assert Enum.at(rows, 1).fingerprint != nil
      assert Enum.at(rows, 2).validation_error == "invalid amount"
    end

    test "marks the import as failed when parsing cannot proceed" do
      entity = insert(:entity, name: "Async failure entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Async failure account")

      assert {:ok, imported_file} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "empty.csv",
                 content: "",
                 content_type: "text/csv"
               })

      assert :ok = PubSub.subscribe_imported_file(imported_file.id)

      assert {:ok, %Oban.Job{} = job} = Ingestion.enqueue_import_processing(imported_file)
      assert job.queue == "imports"
      assert %{failure: 0, success: 1, snoozed: 0} = Oban.drain_queue(queue: :imports)

      assert_receive {:import_updated,
                      %{
                        account_id: processing_account_id,
                        imported_file_id: processing_imported_file_id,
                        status: :processing
                      }}

      assert processing_account_id == account.id
      assert processing_imported_file_id == imported_file.id

      assert_receive {:import_updated,
                      %{
                        account_id: failed_account_id,
                        imported_file_id: failed_imported_file_id,
                        status: :failed
                      }}

      assert failed_account_id == account.id
      assert failed_imported_file_id == imported_file.id

      failed_import = Ingestion.get_imported_file!(account.id, imported_file.id)

      assert failed_import.status == :failed
      assert failed_import.row_count == 0
      assert failed_import.imported_row_count == 0
      assert failed_import.skipped_row_count == 0
      assert failed_import.invalid_row_count == 0
      assert failed_import.error_message == "CSV file is empty"
      assert %DateTime{} = failed_import.processed_at

      [started_event, failed_event] =
        failed_import.id
        |> fetch_import_audit_events()
        |> Enum.sort_by(& &1.occurred_at, {:asc, DateTime})

      assert started_event.action == "processing_started"
      assert started_event.after["status"] == "processing"

      assert failed_event.action == "processing_failed"
      assert failed_event.before["status"] == "processing"
      assert failed_event.after["status"] == "failed"
      assert failed_event.after["error_message"] == "CSV file is empty"

      assert Ingestion.list_imported_rows(
               account_id: account.id,
               imported_file_id: failed_import.id
             ) == []
    end
  end

  defp fetch_import_audit_events(imported_file_id) do
    Audit.list_audit_events(entity_type: "imported_file", entity_id: imported_file_id)
  end
end
