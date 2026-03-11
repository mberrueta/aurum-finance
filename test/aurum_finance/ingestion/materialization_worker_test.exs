defmodule AurumFinance.Ingestion.MaterializationWorkerTest do
  use AurumFinance.DataCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.ImportRowMaterialization
  alias AurumFinance.Ingestion.MaterializationWorker
  alias AurumFinance.Ingestion.PubSub
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Repo

  describe "perform/1" do
    test "commits ready rows and records skipped and failed outcomes durably" do
      %{account: account, entity: entity, imported_file: imported_file} =
        build_materialization_context()

      assert :ok = PubSub.subscribe_account_imports(account.id)
      assert :ok = PubSub.subscribe_imported_file(imported_file.id)

      initial_transaction_count =
        Repo.aggregate(
          from(transaction in Transaction, where: transaction.entity_id == ^entity.id),
          :count,
          :id
        )

      ready_row_one =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-ready-one",
          amount: Decimal.new("-10.00"),
          description: "Groceries"
        })

      ready_row_two =
        insert_imported_row(imported_file, account, %{
          row_index: 1,
          fingerprint: "fp-ready-two",
          amount: Decimal.new("2500.00"),
          description: "Salary"
        })

      duplicate_row =
        insert_imported_row(imported_file, account, %{
          row_index: 2,
          fingerprint: "fp-duplicate",
          status: :duplicate,
          skip_reason: "already imported"
        })

      invalid_row =
        insert_imported_row(imported_file, account, %{
          row_index: 3,
          fingerprint: "fp-invalid",
          status: :invalid,
          validation_error: "missing date"
        })

      mismatch_row =
        insert_imported_row(imported_file, account, %{
          row_index: 4,
          fingerprint: "fp-mismatch",
          currency: "EUR"
        })

      committed_row =
        insert_imported_row(imported_file, account, %{
          row_index: 5,
          fingerprint: "fp-already-committed"
        })

      _prior_committed =
        insert_committed_row_materialization(imported_file, account, committed_row)

      assert {:ok, materialization} =
               Ingestion.request_materialization(account.id, imported_file.id,
                 requested_by: "reviewer@example.com"
               )

      account_id = account.id
      imported_file_id = imported_file.id
      materialization_id = materialization.id

      args = %{
        "account_id" => account.id,
        "import_materialization_id" => materialization.id,
        "imported_file_id" => imported_file.id
      }

      assert :ok = MaterializationWorker.perform(%Oban.Job{args: args})

      assert_receive {:materialization_processing,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :processing
                      }}

      assert_receive {:materialization_processing,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :processing
                      }}

      assert_receive {:materialization_completed,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :completed_with_errors
                      }}

      assert_receive {:materialization_completed,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :completed_with_errors
                      }}

      materialization = Repo.get!(ImportMaterialization, materialization.id)

      assert materialization.status == :completed_with_errors
      assert materialization.rows_considered == 6
      assert materialization.rows_materialized == 2
      assert materialization.rows_skipped_duplicate == 1
      assert materialization.rows_failed == 1
      assert %DateTime{} = materialization.started_at
      assert %DateTime{} = materialization.finished_at
      assert materialization.error_message == nil

      outcomes =
        ImportRowMaterialization
        |> where(
          [row_materialization],
          row_materialization.import_materialization_id == ^materialization.id
        )
        |> order_by([row_materialization], asc: row_materialization.inserted_at)
        |> Repo.all()
        |> Map.new(fn outcome -> {outcome.imported_row_id, outcome} end)

      assert map_size(outcomes) == 6
      assert outcomes[ready_row_one.id].status == :committed
      assert outcomes[ready_row_two.id].status == :committed
      assert outcomes[duplicate_row.id].status == :skipped
      assert outcomes[duplicate_row.id].outcome_reason == "already imported"
      assert outcomes[invalid_row.id].status == :skipped
      assert outcomes[invalid_row.id].outcome_reason == "missing date"
      assert outcomes[mismatch_row.id].status == :failed

      assert outcomes[mismatch_row.id].outcome_reason ==
               "currency mismatch: row EUR vs account USD"

      assert outcomes[committed_row.id].status == :skipped
      assert outcomes[committed_row.id].outcome_reason == "already committed"

      committed_transaction_ids =
        [outcomes[ready_row_one.id].transaction_id, outcomes[ready_row_two.id].transaction_id]

      assert Enum.all?(committed_transaction_ids, &is_binary/1)

      [clearing_account] = Ledger.list_system_managed_accounts(entity_id: entity.id)
      assert clearing_account.account_type == :equity
      assert clearing_account.currency_code == "USD"

      committed_transactions =
        Enum.map(committed_transaction_ids, &Ledger.get_transaction!(entity.id, &1))

      assert Enum.all?(committed_transactions, &(&1.source_type == :import))

      assert Enum.any?(committed_transactions, fn transaction ->
               Enum.any?(transaction.postings, &(&1.account_id == ready_row_one.account_id)) and
                 Enum.any?(transaction.postings, &(&1.account_id == clearing_account.id))
             end)

      assert Repo.aggregate(
               from(transaction in Transaction, where: transaction.entity_id == ^entity.id),
               :count,
               :id
             ) == initial_transaction_count + 3
    end

    test "returns :ok and does not duplicate outcomes when a completed run is executed again" do
      %{account: account, entity: entity, imported_file: imported_file} =
        build_materialization_context()

      initial_transaction_count =
        Repo.aggregate(
          from(transaction in Transaction, where: transaction.entity_id == ^entity.id),
          :count,
          :id
        )

      _ready_row =
        insert_imported_row(imported_file, account, %{
          row_index: 0,
          fingerprint: "fp-idempotent-ready"
        })

      assert {:ok, materialization} =
               Ingestion.request_materialization(account.id, imported_file.id,
                 requested_by: "reviewer@example.com"
               )

      args = %{
        "account_id" => account.id,
        "import_materialization_id" => materialization.id,
        "imported_file_id" => imported_file.id
      }

      assert :ok = MaterializationWorker.perform(%Oban.Job{args: args})

      assert Repo.aggregate(
               from(transaction in Transaction, where: transaction.entity_id == ^entity.id),
               :count,
               :id
             ) == initial_transaction_count + 1

      assert 1 ==
               Repo.aggregate(
                 from(row_materialization in ImportRowMaterialization,
                   where: row_materialization.import_materialization_id == ^materialization.id
                 ),
                 :count,
                 :id
               )

      materialization = Repo.get!(ImportMaterialization, materialization.id)
      assert materialization.status == :completed
      assert materialization.rows_considered == 1
      assert materialization.rows_materialized == 1

      [clearing_account] = Ledger.list_system_managed_accounts(entity_id: entity.id)
      assert clearing_account.currency_code == "USD"
    end
  end

  defp build_materialization_context do
    entity = insert(:entity, name: "Materialization entity")

    account =
      insert(:account, entity: entity, entity_id: entity.id, name: "Materialization account")

    {:ok, imported_file} =
      Ingestion.create_imported_file(%{
        account_id: account.id,
        filename: "materialization.csv",
        sha256: String.duplicate("b", 64),
        format: :csv,
        status: :complete,
        storage_path: "/tmp/imports/materialization.csv"
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
        description: "Previously imported transaction",
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
