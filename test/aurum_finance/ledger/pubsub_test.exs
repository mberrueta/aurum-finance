defmodule AurumFinance.Ledger.PubSubTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.PubSub
  alias AurumFinance.Ledger.Transaction

  describe "broadcast_transaction_created/1" do
    test "broadcasts the business date and deduplicated affected account ids" do
      transaction_id = Ecto.UUID.generate()
      entity_id = Ecto.UUID.generate()
      checking_id = Ecto.UUID.generate()
      groceries_id = Ecto.UUID.generate()

      transaction = %Transaction{
        id: transaction_id,
        entity_id: entity_id,
        date: ~D[2026-03-19],
        postings: [
          %Posting{account_id: checking_id, amount: Decimal.new("-15.0000")},
          %Posting{account_id: groceries_id, amount: Decimal.new("10.0000")},
          %Posting{account_id: groceries_id, amount: Decimal.new("5.0000")}
        ]
      }

      assert :ok = PubSub.subscribe_transactions()
      assert :ok = PubSub.broadcast_transaction_created(transaction)

      assert_receive {:transaction_created,
                      %{
                        transaction_id: ^transaction_id,
                        entity_id: ^entity_id,
                        from_date: ~D[2026-03-19],
                        account_ids: account_ids
                      }}

      assert Enum.sort(account_ids) == Enum.sort([checking_id, groceries_id])
    end
  end

  describe "broadcast_transaction_voided/1" do
    test "broadcasts the voided transaction payload contract" do
      transaction_id = Ecto.UUID.generate()
      entity_id = Ecto.UUID.generate()
      checking_id = Ecto.UUID.generate()
      expense_id = Ecto.UUID.generate()

      voided = %Transaction{
        id: transaction_id,
        entity_id: entity_id,
        date: ~D[2026-03-20],
        postings: [
          %Posting{account_id: checking_id, amount: Decimal.new("-10.0000")},
          %Posting{account_id: expense_id, amount: Decimal.new("10.0000")}
        ]
      }

      assert :ok = PubSub.subscribe_transactions()
      assert :ok = PubSub.broadcast_transaction_voided(voided)

      assert_receive {:transaction_voided,
                      %{
                        transaction_id: ^transaction_id,
                        entity_id: ^entity_id,
                        from_date: ~D[2026-03-20],
                        account_ids: account_ids
                      }}

      assert Enum.sort(account_ids) == Enum.sort([checking_id, expense_id])
    end
  end
end
