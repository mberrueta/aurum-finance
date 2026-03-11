defmodule AurumFinance.Ingestion.MaterializationContextTest do
  use AurumFinance.DataCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.ImportRowMaterialization
  alias AurumFinance.Ingestion.MaterializationWorker
  alias AurumFinance.Ingestion.PubSub
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Repo

  describe "list_materializable_imported_rows/1" do
    test "returns only ready rows that are not committed and match account currency" do
      %{account: account, imported_file: imported_file} = build_import_context()

      ready_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-materializable-ready",
          status: :ready,
          currency: "USD"
        })

      _duplicate_row =
        insert_imported_row(imported_file, account, %{
          row_index: 1,
          fingerprint: "fp-materializable-duplicate",
          status: :duplicate,
          skip_reason: "already imported"
        })

      _invalid_row =
        insert_imported_row(imported_file, account, %{
          row_index: 2,
          fingerprint: "fp-materializable-invalid",
          status: :invalid,
          validation_error: "missing date"
        })

      _mismatch_row =
        insert_imported_row(imported_file, account, %{
          row_index: 3,
          fingerprint: "fp-materializable-mismatch",
          status: :ready,
          currency: "EUR"
        })

      committed_row =
        insert_imported_row(imported_file, account, %{
          row_index: 4,
          fingerprint: "fp-materializable-committed",
          status: :ready,
          currency: "USD"
        })

      _row_materialization =
        insert_committed_row_materialization(imported_file, account, committed_row)

      rows =
        Ingestion.list_materializable_imported_rows(
          account_id: account.id,
          imported_file_id: imported_file.id
        )

      assert Enum.map(rows, & &1.id) == [ready_row.id]
      assert hd(rows).account.currency_code == "USD"
    end
  end

  describe "request_materialization/3" do
    test "persists a pending run and enqueues the worker for ready rows" do
      %{account: account, imported_file: imported_file} = build_import_context()

      assert :ok = PubSub.subscribe_account_imports(account.id)
      assert :ok = PubSub.subscribe_imported_file(imported_file.id)

      _ready_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-request-ready",
          status: :ready,
          currency: "USD"
        })

      _mismatch_row =
        insert_imported_row(imported_file, account, %{
          row_index: 1,
          fingerprint: "fp-request-mismatch",
          status: :ready,
          currency: "EUR"
        })

      _duplicate_row =
        insert_imported_row(imported_file, account, %{
          row_index: 2,
          fingerprint: "fp-request-duplicate",
          status: :duplicate,
          skip_reason: "already imported"
        })

      assert {:ok, materialization} =
               Ingestion.request_materialization(account.id, imported_file.id,
                 requested_by: "reviewer@example.com"
               )

      account_id = account.id
      imported_file_id = imported_file.id
      materialization_id = materialization.id

      assert materialization.status == :pending
      assert materialization.requested_by == "reviewer@example.com"
      assert materialization.rows_considered == 2
      assert materialization.rows_skipped_duplicate == 1
      assert materialization.rows_materialized == 0
      assert materialization.rows_failed == 0

      assert_receive {:materialization_requested,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :pending
                      }}

      assert_receive {:materialization_requested,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :pending
                      }}

      assert_enqueued(
        worker: MaterializationWorker,
        queue: :materializations,
        args: %{
          "account_id" => account.id,
          "import_materialization_id" => materialization.id,
          "imported_file_id" => imported_file.id
        }
      )
    end

    test "returns a localized error when there are no ready rows left to consider" do
      %{account: account, imported_file: imported_file} = build_import_context()

      _duplicate_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-no-ready-duplicate",
          status: :duplicate,
          skip_reason: "already imported"
        })

      invalid_row =
        insert_imported_row(imported_file, account, %{
          row_index: 1,
          fingerprint: "fp-no-ready-invalid",
          status: :invalid,
          validation_error: "missing date"
        })

      committed_row =
        insert_imported_row(imported_file, account, %{
          row_index: 2,
          fingerprint: "fp-no-ready-committed",
          status: :ready
        })

      _row_materialization =
        insert_committed_row_materialization(imported_file, account, committed_row)

      assert invalid_row.status == :invalid

      assert {:error, reason} =
               Ingestion.request_materialization(account.id, imported_file.id,
                 requested_by: "reviewer@example.com"
               )

      assert reason == "There are no rows eligible for materialization."
      refute_enqueued(worker: MaterializationWorker)
    end
  end

  defp build_import_context do
    entity = insert(:entity, name: "Review entity")
    account = insert(:account, entity: entity, entity_id: entity.id, name: "Review account")

    {:ok, imported_file} =
      Ingestion.create_imported_file(%{
        account_id: account.id,
        filename: "review.csv",
        sha256: String.duplicate("a", 64),
        format: :csv,
        status: :complete,
        storage_path: "/tmp/imports/review.csv"
      })

    %{entity: entity, account: account, imported_file: imported_file}
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

  defp insert_committed_row_materialization(imported_file, account, imported_row) do
    {:ok, materialization} =
      %ImportMaterialization{}
      |> ImportMaterialization.changeset(%{
        imported_file_id: imported_file.id,
        account_id: account.id,
        status: :completed,
        requested_by: "reviewer@example.com",
        rows_considered: 1,
        rows_materialized: 1
      })
      |> Repo.insert()

    {:ok, transaction} =
      %Transaction{}
      |> Transaction.changeset(%{
        entity_id: account.entity_id,
        date: ~D[2026-03-10],
        description: "Imported transaction",
        source_type: :import
      })
      |> Repo.insert()

    {:ok, row_materialization} =
      %ImportRowMaterialization{}
      |> ImportRowMaterialization.changeset(%{
        import_materialization_id: materialization.id,
        imported_row_id: imported_row.id,
        transaction_id: transaction.id,
        status: :committed
      })
      |> Repo.insert()

    row_materialization
  end
end
