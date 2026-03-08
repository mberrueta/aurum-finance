defmodule AurumFinance.LedgerTransactionsTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Transaction

  describe "create_transaction/2" do
    test "creates a balanced transaction and audit event" do
      entity = entity_fixture(%{name: "Ledger Tx Entity"})
      checking = account_fixture(entity, %{name: "Checking Tx"})

      food =
        account_fixture(entity, %{
          name: "Food Tx",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      assert {:ok, transaction} =
               Ledger.create_transaction(
                 %{
                   entity_id: entity.id,
                   date: ~D[2026-03-01],
                   description: "Lunch",
                   source_type: :manual,
                   postings: [
                     %{account_id: checking.id, amount: Decimal.new("-12.50")},
                     %{account_id: food.id, amount: Decimal.new("12.50")}
                   ]
                 },
                 actor: "person",
                 channel: :web
               )

      assert %Transaction{} = transaction
      assert Enum.count(transaction.postings) == 2

      [event] = Audit.list_audit_events(entity_id: transaction.id)
      assert event.entity_type == "transaction"
      assert event.action == "created"
      assert event.actor == "person"
      assert event.channel == :web
      assert event.after["description"] == "Lunch"
    end

    test "rejects unbalanced postings" do
      entity = entity_fixture(%{name: "Unbalanced Entity"})
      checking = account_fixture(entity, %{name: "Checking Unbalanced"})

      food =
        account_fixture(entity, %{
          name: "Food Unbalanced",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Broken lunch",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-12.50")},
                   %{account_id: food.id, amount: Decimal.new("10.00")}
                 ]
               })

      assert "Transaction postings must balance to zero within each currency." in errors_on(
               changeset
             ).postings
    end

    test "rejects correlation_id on normal creation" do
      entity = entity_fixture(%{name: "Correlation Entity"})
      checking = account_fixture(entity, %{name: "Checking Correlation"})

      food =
        account_fixture(entity, %{
          name: "Food Correlation",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Manual correlation id",
                 source_type: :manual,
                 correlation_id: Ecto.UUID.generate(),
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-12.50")},
                   %{account_id: food.id, amount: Decimal.new("12.50")}
                 ]
               })

      assert "Correlation ID is reserved for system-generated linked transactions." in errors_on(
               changeset
             ).correlation_id
    end

    test "rejects cross-entity posting accounts" do
      entity = entity_fixture(%{name: "Entity Main"})
      other_entity = entity_fixture(%{name: "Entity Foreign"})
      checking = account_fixture(entity, %{name: "Checking Main"})

      foreign_food =
        account_fixture(other_entity, %{
          name: "Food Foreign",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Cross entity",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-12.50")},
                   %{account_id: foreign_food.id, amount: Decimal.new("12.50")}
                 ]
               })

      assert "All posting accounts must belong to the same entity as the transaction." in errors_on(
               changeset
             ).postings
    end
  end

  describe "querying and voids" do
    test "balances are derived from postings and voids net to zero" do
      entity = entity_fixture(%{name: "Balance Entity"})
      checking = account_fixture(entity, %{name: "Checking Balance"})

      food =
        account_fixture(entity, %{
          name: "Food Balance",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      assert {:ok, transaction} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-03],
                 description: "Dinner",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-25.00")},
                   %{account_id: food.id, amount: Decimal.new("25.00")}
                 ]
               })

      assert Ledger.get_account_balance(checking.id) == %{"USD" => Decimal.new("-25.00")}
      assert Ledger.get_account_balance(checking.id, as_of_date: ~D[2026-03-02]) == %{}

      assert {:ok, %{voided: voided, reversal: reversal}} =
               Ledger.void_transaction(transaction, actor: "person", channel: :web)

      assert voided.correlation_id == reversal.correlation_id
      assert %DateTime{} = voided.voided_at
      assert is_nil(reversal.voided_at)
      assert is_binary(reversal.correlation_id)
      assert Ledger.get_account_balance(checking.id) == %{"USD" => Decimal.new("0.00")}

      actions =
        Audit.list_audit_events(entity_id: transaction.id)
        |> Enum.map(& &1.action)

      assert "voided" in actions
    end

    test "list_transactions/1 enforces scope and filters voided rows by default" do
      entity = entity_fixture(%{name: "Listing Entity"})
      transaction = create_balanced_transaction(entity, %{description: "Visible Tx"})

      assert [listed] = Ledger.list_transactions(entity_id: entity.id)
      assert listed.id == transaction.id

      assert {:ok, %{voided: _voided, reversal: _reversal}} = Ledger.void_transaction(transaction)

      [active_reversal] = Ledger.list_transactions(entity_id: entity.id)
      assert active_reversal.description == "Reversal of Visible Tx"
      assert 2 == Enum.count(Ledger.list_transactions(entity_id: entity.id, include_voided: true))

      assert_raise ArgumentError, "list_transactions/1 requires :entity_id", fn ->
        Ledger.list_transactions()
      end

      assert Ledger.get_transaction!(entity.id, transaction.id).id == transaction.id
    end
  end

  defp create_balanced_transaction(entity, attrs) do
    checking =
      account_fixture(entity, %{
        name: "Test Checking #{System.unique_integer([:positive])}",
        account_type: :asset,
        operational_subtype: :bank_checking,
        management_group: :institution
      })

    expense =
      account_fixture(entity, %{
        name: "Test Expense #{System.unique_integer([:positive])}",
        account_type: :expense,
        operational_subtype: nil,
        management_group: :category
      })

    params =
      %{
        entity_id: entity.id,
        date: Date.utc_today(),
        description: "Fixture transaction",
        source_type: :manual,
        postings: [
          %{account_id: checking.id, amount: Decimal.new("-10.00")},
          %{account_id: expense.id, amount: Decimal.new("10.00")}
        ]
      }
      |> Map.merge(attrs)

    {:ok, transaction} = Ledger.create_transaction(params)
    transaction
  end
end
