defmodule AurumFinance.Ledger.PostingTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Ledger.Posting

  describe "changeset/2" do
    test "accepts valid attrs with required fields" do
      changeset =
        Posting.changeset(%Posting{}, %{
          transaction_id: Ecto.UUID.generate(),
          account_id: Ecto.UUID.generate(),
          amount: Decimal.new("10.00")
        })

      assert changeset.valid?
    end

    test "requires transaction_id, account_id, and amount" do
      changeset = Posting.changeset(%Posting{}, %{})

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).transaction_id
      assert "error_field_required" in errors_on(changeset).account_id
      assert "error_field_required" in errors_on(changeset).amount
    end

    test "requires amount to be non-nil" do
      changeset =
        Posting.changeset(%Posting{}, %{
          transaction_id: Ecto.UUID.generate(),
          account_id: Ecto.UUID.generate(),
          amount: nil
        })

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).amount
    end

    test "does not expose currency_code, entity_id, or updated_at fields" do
      fields = Posting.__schema__(:fields)

      refute :currency_code in fields
      refute :entity_id in fields
      refute :updated_at in fields
      assert :amount in fields
    end
  end
end
