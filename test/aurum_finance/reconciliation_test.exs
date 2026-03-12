defmodule AurumFinance.ReconciliationTest do
  use AurumFinance.DataCase, async: true

  import Ecto.Query

  alias AurumFinance.Audit
  alias AurumFinance.Ingestion
  alias AurumFinance.Ledger
  alias AurumFinance.Reconciliation
  alias AurumFinance.Reconciliation.PostingReconciliationState
  alias AurumFinance.Reconciliation.ReconciliationAuditLog
  alias AurumFinance.Repo

  describe "create_reconciliation_session/2" do
    test "creates session with completed_at nil and emits an audit event" do
      entity = insert_entity()
      account = insert_account(entity)

      assert {:ok, session} =
               Reconciliation.create_reconciliation_session(
                 %{
                   entity_id: entity.id,
                   account_id: account.id,
                   statement_date: ~D[2026-03-11],
                   statement_balance: Decimal.new("5000.00")
                 },
                 entity_id: entity.id,
                 actor: "root",
                 channel: :web
               )

      assert session.completed_at == nil

      [event] = Audit.list_audit_events(entity_id: session.id)
      assert event.entity_type == "reconciliation_session"
      assert event.action == "created"
      assert event.actor == "root"
      assert event.channel == :web
    end

    test "rejects when an active session already exists for the account" do
      entity = insert_entity()
      account = insert_account(entity)

      assert {:ok, _session} =
               Reconciliation.create_reconciliation_session(
                 %{
                   entity_id: entity.id,
                   account_id: account.id,
                   statement_date: ~D[2026-03-11],
                   statement_balance: Decimal.new("5000.00")
                 },
                 entity_id: entity.id
               )

      assert {:error, changeset} =
               Reconciliation.create_reconciliation_session(
                 %{
                   entity_id: entity.id,
                   account_id: account.id,
                   statement_date: ~D[2026-03-12],
                   statement_balance: Decimal.new("5100.00")
                 },
                 entity_id: entity.id
               )

      assert "An active reconciliation session already exists for this account." in errors_on(
               changeset
             ).account_id
    end

    test "allows a new session after the previous one is completed" do
      entity = insert_entity()
      account = insert_account(entity)

      assert {:ok, session} =
               Reconciliation.create_reconciliation_session(
                 %{
                   entity_id: entity.id,
                   account_id: account.id,
                   statement_date: ~D[2026-03-11],
                   statement_balance: Decimal.new("5000.00")
                 },
                 entity_id: entity.id
               )

      assert {:ok, completed_session} = Reconciliation.complete_reconciliation_session(session)
      refute is_nil(completed_session.completed_at)

      assert {:ok, new_session} =
               Reconciliation.create_reconciliation_session(
                 %{
                   entity_id: entity.id,
                   account_id: account.id,
                   statement_date: ~D[2026-03-12],
                   statement_balance: Decimal.new("5100.00")
                 },
                 entity_id: entity.id
               )

      assert new_session.id != completed_session.id
      assert is_nil(new_session.completed_at)
    end
  end

  describe "list_reconciliation_sessions/1" do
    test "requires entity_id" do
      assert_raise ArgumentError,
                   "list_reconciliation_sessions_query/1 requires :entity_id",
                   fn ->
                     Reconciliation.list_reconciliation_sessions()
                   end
    end

    test "filters by entity_id and account_id" do
      entity = insert_entity()
      other_entity = insert_entity()
      account_a = insert_account(entity, %{name: "Checking A"})

      account_b =
        insert_account(entity, %{name: "Checking B", operational_subtype: :bank_savings})

      other_account = insert_account(other_entity, %{name: "Other Checking"})

      session_a =
        insert_reconciliation_session(entity, %{account: account_a, account_id: account_a.id})

      session_b =
        insert_reconciliation_session(entity, %{account: account_b, account_id: account_b.id})

      _other_session =
        insert_reconciliation_session(other_entity, %{
          account: other_account,
          account_id: other_account.id
        })

      assert Enum.map(Reconciliation.list_reconciliation_sessions(entity_id: entity.id), & &1.id)
             |> Enum.sort() ==
               Enum.sort([session_a.id, session_b.id])

      assert [filtered] =
               Reconciliation.list_reconciliation_sessions(
                 entity_id: entity.id,
                 account_id: account_a.id
               )

      assert filtered.id == session_a.id
    end
  end

  describe "get_reconciliation_session!/2" do
    test "returns the session for the correct entity and raises for another entity" do
      entity = insert_entity()
      other_entity = insert_entity()
      session = insert_reconciliation_session(entity)

      assert Reconciliation.get_reconciliation_session!(entity.id, session.id).id == session.id

      assert_raise Ecto.NoResultsError, fn ->
        Reconciliation.get_reconciliation_session!(other_entity.id, session.id)
      end
    end
  end

  describe "update_reconciliation_session/3" do
    test "updates statement_balance before completion" do
      entity = insert_entity()
      session = insert_reconciliation_session(entity)

      assert {:ok, updated_session} =
               Reconciliation.update_reconciliation_session(
                 session,
                 %{statement_balance: Decimal.new("1250.00")},
                 actor: "root",
                 channel: :web
               )

      assert Decimal.equal?(updated_session.statement_balance, Decimal.new("1250.00"))

      assert [_created_event, updated_event] =
               Audit.list_audit_events(entity_id: session.id)
               |> Enum.sort_by(& &1.occurred_at, {:asc, DateTime})

      assert updated_event.action == "updated"
      assert updated_event.actor == "root"
      assert updated_event.channel == :web
    end

    test "rejects edits after completion" do
      entity = insert_entity()
      session = insert_reconciliation_session(entity)

      assert {:ok, completed_session} = Reconciliation.complete_reconciliation_session(session)

      assert {:error, changeset} =
               Reconciliation.update_reconciliation_session(
                 completed_session,
                 %{statement_balance: Decimal.new("1500.00")}
               )

      assert "error_reconciliation_session_completed" in errors_on(changeset).completed_at
    end
  end

  describe "complete_reconciliation_session/2" do
    test "transitions cleared states to reconciled, creates audit logs, and emits session audit event" do
      %{entity: entity, account: account, posting_ids: posting_ids} = reconciliation_postings()

      assert {:ok, session} =
               Reconciliation.create_reconciliation_session(
                 %{
                   entity_id: entity.id,
                   account_id: account.id,
                   statement_date: ~D[2026-03-11],
                   statement_balance: Decimal.new("-30.00")
                 },
                 entity_id: entity.id,
                 actor: "root",
                 channel: :web
               )

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared(posting_ids, session.id, entity_id: entity.id)

      assert {:ok, completed_session} =
               Reconciliation.complete_reconciliation_session(session,
                 actor: "root",
                 channel: :web
               )

      refute is_nil(completed_session.completed_at)

      statuses =
        PostingReconciliationState
        |> where([state], state.reconciliation_session_id == ^session.id)
        |> select([state], state.status)
        |> Repo.all()

      assert statuses == [:reconciled, :reconciled]

      completion_logs =
        ReconciliationAuditLog
        |> where([log], log.reconciliation_session_id == ^session.id)
        |> where([log], log.from_status == "cleared" and log.to_status == "reconciled")
        |> Repo.all()

      assert length(completion_logs) == length(posting_ids)

      actions =
        Audit.list_audit_events(entity_id: session.id)
        |> Enum.map(& &1.action)

      assert "created" in actions
      assert "completed" in actions
    end
  end

  describe "mark_postings_cleared/3" do
    test "inserts overlay rows and audit log rows for unreconciled postings" do
      %{entity: entity, account: account, posting_ids: posting_ids} = reconciliation_postings()
      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert {:ok, states} =
               Reconciliation.mark_postings_cleared(posting_ids, session.id,
                 entity_id: entity.id,
                 actor: "root",
                 channel: :web
               )

      assert Enum.count(states) == length(posting_ids)
      assert Enum.all?(states, &(&1.status == :cleared))

      logs =
        ReconciliationAuditLog
        |> where([log], log.reconciliation_session_id == ^session.id)
        |> Repo.all()

      assert length(logs) == length(posting_ids)
      assert Enum.all?(logs, &(&1.to_status == "cleared"))
      assert Enum.all?(logs, &(&1.actor == "root"))
      assert Enum.all?(logs, &(&1.channel == "web"))
    end

    test "rejects when any posting already has an overlay and is atomic" do
      %{entity: entity, account: account, posting_ids: [posting_id | rest_posting_ids]} =
        reconciliation_postings()

      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert {:ok, [_state]} =
               Reconciliation.mark_postings_cleared([posting_id], session.id,
                 entity_id: entity.id
               )

      assert {:error, :postings_not_clearable} =
               Reconciliation.mark_postings_cleared(
                 [posting_id | rest_posting_ids],
                 session.id,
                 entity_id: entity.id
               )

      states =
        PostingReconciliationState
        |> where([state], state.reconciliation_session_id == ^session.id)
        |> Repo.all()

      assert length(states) == 1
      assert hd(states).posting_id == posting_id
    end
  end

  describe "mark_postings_uncleared/3" do
    test "deletes cleared overlay rows and creates audit log rows" do
      %{entity: entity, account: account, posting_ids: posting_ids} = reconciliation_postings()
      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared(posting_ids, session.id, entity_id: entity.id)

      assert {:ok, returned_posting_ids} =
               Reconciliation.mark_postings_uncleared(posting_ids, session.id,
                 entity_id: entity.id,
                 actor: "root",
                 channel: :web
               )

      assert Enum.sort(returned_posting_ids) == Enum.sort(posting_ids)

      assert Repo.aggregate(PostingReconciliationState, :count, :id) == 0

      logs =
        ReconciliationAuditLog
        |> where([log], log.reconciliation_session_id == ^session.id)
        |> where([log], log.from_status == "cleared" and is_nil(log.to_status))
        |> Repo.all()

      assert length(logs) == length(posting_ids)
    end

    test "rejects after the posting has become reconciled" do
      %{entity: entity, account: account, posting_ids: posting_ids} = reconciliation_postings()
      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared(posting_ids, session.id, entity_id: entity.id)

      assert {:ok, completed_session} = Reconciliation.complete_reconciliation_session(session)

      assert {:error, :session_already_completed} =
               Reconciliation.mark_postings_uncleared(
                 posting_ids,
                 completed_session.id,
                 entity_id: entity.id
               )
    end
  end

  describe "any_posting_reconciled?/1" do
    test "returns false for postings with no overlay rows" do
      %{posting_ids: posting_ids} = reconciliation_postings()

      refute Reconciliation.any_posting_reconciled?(posting_ids)
    end

    test "returns false when rows are only cleared and true when reconciled exists" do
      %{entity: entity, account: account, posting_ids: posting_ids} = reconciliation_postings()
      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared(posting_ids, session.id, entity_id: entity.id)

      refute Reconciliation.any_posting_reconciled?(posting_ids)

      assert {:ok, _completed_session} = Reconciliation.complete_reconciliation_session(session)

      assert Reconciliation.any_posting_reconciled?(posting_ids)
    end
  end

  describe "list_postings_for_reconciliation/2" do
    test "returns postings with derived status and is entity scoped" do
      %{entity: entity, account: account, posting_ids: [posting_id | _rest]} =
        reconciliation_postings()

      other_entity = insert_entity()
      _other_account = insert_account(other_entity)
      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared([posting_id], session.id,
                 entity_id: entity.id
               )

      postings = Reconciliation.list_postings_for_reconciliation(account.id, entity_id: entity.id)

      assert Enum.any?(postings, &(&1.id == posting_id and &1.reconciliation_status == :cleared))
      assert Enum.all?(postings, &(&1.account_id == account.id))

      assert [] ==
               Reconciliation.list_postings_for_reconciliation(
                 account.id,
                 entity_id: other_entity.id
               )
    end

    test "excludes postings whose parent transaction was voided" do
      %{
        entity: entity,
        account: account,
        transaction: transaction,
        transaction_posting_ids: transaction_posting_ids
      } = reconciliation_postings()

      assert {:ok, %{voided: _voided, reversal: reversal}} = Ledger.void_transaction(transaction)

      postings = Reconciliation.list_postings_for_reconciliation(account.id, entity_id: entity.id)

      refute Enum.any?(postings, &(&1.id in transaction_posting_ids))
      assert Enum.any?(postings, &(&1.transaction_id == reversal.id))
    end
  end

  describe "get_cleared_balance/2" do
    test "returns the sum of cleared and reconciled posting amounts" do
      %{entity: entity, account: account, posting_ids: posting_ids} = reconciliation_postings()
      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert Decimal.equal?(
               Reconciliation.get_cleared_balance(account.id, entity_id: entity.id),
               Decimal.new("0")
             )

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared(posting_ids, session.id, entity_id: entity.id)

      assert Decimal.equal?(
               Reconciliation.get_cleared_balance(account.id, entity_id: entity.id),
               Decimal.new("-30.00")
             )

      assert {:ok, _completed_session} = Reconciliation.complete_reconciliation_session(session)

      assert Decimal.equal?(
               Reconciliation.get_cleared_balance(account.id, entity_id: entity.id),
               Decimal.new("-30.00")
             )
    end

    test "excludes cleared postings from voided transactions" do
      %{entity: entity, account: account, transaction: transaction, posting_ids: posting_ids} =
        reconciliation_postings()

      session = insert_reconciliation_session(entity, account: account, account_id: account.id)

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared(posting_ids, session.id, entity_id: entity.id)

      assert Decimal.equal?(
               Reconciliation.get_cleared_balance(account.id, entity_id: entity.id),
               Decimal.new("-30.00")
             )

      assert {:ok, %{voided: _voided, reversal: _reversal}} = Ledger.void_transaction(transaction)

      assert Decimal.equal?(
               Reconciliation.get_cleared_balance(account.id, entity_id: entity.id),
               Decimal.new("-20.00")
             )
    end
  end

  describe "list_match_candidates_for_posting/2" do
    test "ranks stronger amount and date evidence above stronger description similarity" do
      %{
        entity: entity,
        fuel_posting_id: fuel_posting_id
      } = reconciliation_postings_with_import_rows()

      assert {:ok, [best_candidate, second_candidate | _rest]} =
               Reconciliation.list_match_candidates_for_posting(
                 fuel_posting_id,
                 entity_id: entity.id,
                 limit: 10
               )

      assert best_candidate.imported_row.description == "Fuel purchase"
      assert best_candidate.match_band == :exact_match
      assert best_candidate.score <= 1.0
      assert best_candidate.score >= 0.0

      assert second_candidate.imported_row.description == "Fuel station premium"
      assert second_candidate.match_band in [:near_match, :weak_match]
      assert best_candidate.score > second_candidate.score
    end

    test "filters below-threshold rows from the public API by default" do
      %{
        entity: entity,
        fuel_posting_id: fuel_posting_id
      } = reconciliation_postings_with_import_rows()

      assert {:ok, candidates} =
               Reconciliation.list_match_candidates_for_posting(
                 fuel_posting_id,
                 entity_id: entity.id,
                 limit: 10
               )

      refute Enum.any?(candidates, &(&1.match_band == :below_threshold))

      assert {:ok, candidates_with_below_threshold} =
               Reconciliation.list_match_candidates_for_posting(
                 fuel_posting_id,
                 entity_id: entity.id,
                 limit: 10,
                 include_below_threshold: true
               )

      assert Enum.any?(candidates_with_below_threshold, &(&1.match_band == :below_threshold))
    end

    test "returns only imported rows from the posting account and entity scope" do
      %{
        entity: entity,
        other_entity: other_entity,
        fuel_posting_id: fuel_posting_id,
        account: account
      } = reconciliation_postings_with_import_rows()

      assert {:ok, candidates} =
               Reconciliation.list_match_candidates_for_posting(
                 fuel_posting_id,
                 entity_id: entity.id,
                 limit: 10
               )

      assert Enum.all?(candidates, &(&1.imported_row.account_id == account.id))

      assert {:error, :not_found} =
               Reconciliation.list_match_candidates_for_posting(
                 fuel_posting_id,
                 entity_id: other_entity.id
               )
    end
  end

  describe "accept_match_candidate/4" do
    test "marks the posting as cleared and stores accepted candidate metadata in the audit log" do
      %{
        entity: entity,
        account: account,
        fuel_posting_id: fuel_posting_id
      } = reconciliation_postings_with_import_rows()

      session =
        insert_reconciliation_session(entity,
          account: account,
          account_id: account.id,
          statement_date: ~D[2026-03-31],
          statement_balance: Decimal.new("45.20")
        )

      {:ok, [candidate | _rest]} =
        Reconciliation.list_match_candidates_for_posting(
          fuel_posting_id,
          entity_id: entity.id
        )

      assert {:ok, state} =
               Reconciliation.accept_match_candidate(
                 fuel_posting_id,
                 candidate.imported_row_id,
                 session.id,
                 entity_id: entity.id,
                 actor: "root",
                 channel: :web
               )

      assert state.status == :cleared

      audit_log =
        ReconciliationAuditLog
        |> where(
          [log],
          log.reconciliation_session_id == ^session.id and log.posting_id == ^fuel_posting_id
        )
        |> order_by([log], desc: log.inserted_at)
        |> limit(1)
        |> Repo.one!()

      assert audit_log.metadata["accepted_imported_row_id"] == candidate.imported_row_id
      assert audit_log.metadata["accepted_imported_file_id"] == candidate.imported_file_id
      assert audit_log.metadata["match_band"] == Atom.to_string(candidate.match_band)
    end
  end

  defp reconciliation_postings do
    entity = insert_entity()
    account = insert_account(entity, %{name: "Recon Checking"})

    category =
      insert_account(entity, %{
        name: "Recon Expense",
        account_type: :expense,
        operational_subtype: nil,
        management_group: :category
      })

    {:ok, transaction_1} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: ~D[2026-03-01],
        description: "Groceries",
        source_type: :manual,
        postings: [
          %{account_id: account.id, amount: Decimal.new("-10.00")},
          %{account_id: category.id, amount: Decimal.new("10.00")}
        ]
      })

    {:ok, transaction_2} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: ~D[2026-03-02],
        description: "Fuel",
        source_type: :manual,
        postings: [
          %{account_id: account.id, amount: Decimal.new("-20.00")},
          %{account_id: category.id, amount: Decimal.new("20.00")}
        ]
      })

    transaction_ids = [transaction_1.id, transaction_2.id]

    posting_ids =
      AurumFinance.Ledger.Posting
      |> where(
        [posting],
        posting.account_id == ^account.id and posting.transaction_id in ^transaction_ids
      )
      |> select([posting], posting.id)
      |> Repo.all()

    transaction_posting_ids =
      AurumFinance.Ledger.Posting
      |> where(
        [posting],
        posting.account_id == ^account.id and posting.transaction_id == ^transaction_1.id
      )
      |> select([posting], posting.id)
      |> Repo.all()

    %{
      entity: entity,
      account: account,
      category: category,
      posting_ids: posting_ids,
      transaction_posting_ids: transaction_posting_ids,
      transaction: transaction_1
    }
  end

  defp reconciliation_postings_with_import_rows do
    base = reconciliation_postings()
    account = base.account
    other_entity = insert_entity()
    other_account = insert_account(other_entity)

    fuel_posting_id =
      AurumFinance.Ledger.Posting
      |> join(:inner, [posting], transaction in AurumFinance.Ledger.Transaction,
        on: transaction.id == posting.transaction_id
      )
      |> where(
        [posting, transaction],
        posting.account_id == ^account.id and transaction.description == "Fuel"
      )
      |> select([posting], posting.id)
      |> Repo.one!()

    imported_file = create_imported_file(account)

    _exact_match_row =
      create_imported_row(imported_file, account, 0, "Fuel purchase", ~D[2026-03-02], "-20.00")

    _better_description_weaker_core_row =
      create_imported_row(
        imported_file,
        account,
        1,
        "Fuel station premium",
        ~D[2026-03-03],
        "-22.00"
      )

    _below_threshold_row =
      create_imported_row(imported_file, account, 2, nil, ~D[2026-03-04], "-24.00")

    other_imported_file = create_imported_file(other_account)

    _other_entity_row =
      create_imported_row(
        other_imported_file,
        other_account,
        0,
        "Fuel purchase",
        ~D[2026-03-02],
        "-20.00"
      )

    Map.merge(base, %{
      fuel_posting_id: fuel_posting_id,
      other_entity: other_entity
    })
  end

  defp create_imported_file(account) do
    {:ok, imported_file} =
      Ingestion.create_imported_file(%{
        account_id: account.id,
        filename: "statement-#{System.unique_integer([:positive])}.csv",
        sha256: String.duplicate("a", 64),
        format: :csv,
        status: :complete,
        storage_path: "/tmp/statement-#{System.unique_integer([:positive])}.csv"
      })

    imported_file
  end

  defp create_imported_row(imported_file, account, row_index, description, posted_on, amount) do
    raw_data =
      case description do
        nil -> %{"posted_on" => Date.to_iso8601(posted_on)}
        _description -> %{"description" => description, "posted_on" => Date.to_iso8601(posted_on)}
      end

    {:ok, imported_row} =
      Ingestion.create_imported_row(%{
        imported_file_id: imported_file.id,
        account_id: account.id,
        row_index: row_index,
        raw_data: raw_data,
        description: description,
        normalized_description: normalize_description(description),
        posted_on: posted_on,
        amount: Decimal.new(amount),
        currency: "USD",
        fingerprint: "fp-#{System.unique_integer([:positive])}",
        status: :ready
      })

    imported_row
  end

  defp normalize_description(nil), do: nil
  defp normalize_description(description), do: String.downcase(description)
end
