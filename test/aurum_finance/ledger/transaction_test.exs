defmodule AurumFinance.Ledger.TransactionTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Ledger.Transaction

  describe "changeset/2" do
    test "accepts valid attrs with required fields" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Salary payment",
          source_type: :manual
        })

      assert changeset.valid?
      assert get_change(changeset, :voided_at) == nil
    end

    test "requires entity_id, date, description, and source_type" do
      changeset = Transaction.changeset(%Transaction{}, %{})

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).entity_id
      assert "error_field_required" in errors_on(changeset).date
      assert "error_field_required" in errors_on(changeset).description
      assert "error_field_required" in errors_on(changeset).source_type
    end

    test "validates source_type enum" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Bad type",
          source_type: :unknown
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).source_type
    end

    test "limits description length to 500 characters" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: String.duplicate("a", 501),
          source_type: :manual
        })

      refute changeset.valid?

      assert "Transaction description must be at most 500 characters." in errors_on(changeset).description
    end

    test "rejects caller-supplied correlation_id on create" do
      changeset =
        Transaction.changeset(%Transaction{}, %{
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Reserved correlation",
          source_type: :manual,
          correlation_id: Ecto.UUID.generate()
        })

      refute changeset.valid?

      assert "Correlation ID is reserved for system-generated linked transactions." in errors_on(
               changeset
             ).correlation_id
    end

    test "rejects immutable field changes on update" do
      transaction =
        struct(Transaction,
          id: Ecto.UUID.generate(),
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Original",
          source_type: :manual
        )

      changeset =
        Transaction.changeset(transaction, %{
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-08],
          description: "Changed",
          source_type: :import
        })

      refute changeset.valid?

      assert "This field cannot be changed after the transaction is created." in errors_on(
               changeset
             ).entity_id

      assert "This field cannot be changed after the transaction is created." in errors_on(
               changeset
             ).date

      assert "This field cannot be changed after the transaction is created." in errors_on(
               changeset
             ).description

      assert "This field cannot be changed after the transaction is created." in errors_on(
               changeset
             ).source_type
    end

    test "does not expose memo, status, or updated_at fields" do
      fields = Transaction.__schema__(:fields)

      refute :memo in fields
      refute :status in fields
      refute :updated_at in fields
      assert :voided_at in fields
    end
  end

  describe "system_changeset/2" do
    test "allows correlation_id for system-generated transactions" do
      changeset =
        Transaction.system_changeset(%Transaction{}, %{
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Reversal",
          source_type: :system,
          correlation_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
    end
  end

  describe "void_changeset/2" do
    test "sets voided_at and correlation_id" do
      transaction =
        struct(Transaction,
          id: Ecto.UUID.generate(),
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Original",
          source_type: :manual
        )

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      correlation_id = Ecto.UUID.generate()

      changeset =
        Transaction.void_changeset(transaction, %{
          voided_at: now,
          correlation_id: correlation_id
        })

      assert changeset.valid?
      assert DateTime.compare(get_change(changeset, :voided_at), now) == :eq
      assert get_change(changeset, :correlation_id) == correlation_id
    end

    test "ignores attempts to change immutable transaction fields" do
      transaction =
        struct(Transaction,
          id: Ecto.UUID.generate(),
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Original",
          source_type: :manual
        )

      changeset =
        Transaction.void_changeset(transaction, %{
          voided_at: DateTime.utc_now() |> DateTime.truncate(:second),
          description: "Changed"
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :description)
    end

    test "rejects double void" do
      transaction =
        struct(Transaction,
          id: Ecto.UUID.generate(),
          entity_id: Ecto.UUID.generate(),
          date: ~D[2026-03-07],
          description: "Already voided",
          source_type: :manual,
          voided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      changeset =
        Transaction.void_changeset(transaction, %{
          voided_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      refute changeset.valid?
      assert "This transaction has already been voided." in errors_on(changeset).voided_at
    end
  end
end
