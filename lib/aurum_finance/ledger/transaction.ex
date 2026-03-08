defmodule AurumFinance.Ledger.Transaction do
  @moduledoc """
  Immutable ledger transaction header with set-once void metadata.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Posting

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @source_types [:manual, :import, :system]
  @immutable_fields [:entity_id, :date, :description, :source_type]

  @type t :: %__MODULE__{}

  @required [:entity_id, :date, :description, :source_type]
  @optional [:correlation_id, :voided_at]

  schema "transactions" do
    field :date, :date
    field :description, :string
    field :source_type, Ecto.Enum, values: @source_types
    field :correlation_id, Ecto.UUID
    field :voided_at, :utc_datetime_usec

    belongs_to :entity, Entity
    has_many :postings, Posting

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  @doc """
  Builds the user-facing transaction changeset.

  ## Examples

  ```elixir
  changeset =
    AurumFinance.Ledger.Transaction.changeset(%AurumFinance.Ledger.Transaction{}, %{
      entity_id: Ecto.UUID.generate(),
      date: ~D[2026-03-07],
      description: "Salary",
      source_type: :manual
    })

  changeset.valid?
  #=> true
  ```
  """
  def changeset(transaction, attrs) do
    do_changeset(transaction, attrs, false)
  end

  @spec system_changeset(t(), map()) :: Ecto.Changeset.t()
  @doc """
  Builds a system-only transaction changeset that may carry `correlation_id`.

  ## Examples

  ```elixir
  changeset =
    AurumFinance.Ledger.Transaction.system_changeset(%AurumFinance.Ledger.Transaction{}, %{
      entity_id: Ecto.UUID.generate(),
      date: ~D[2026-03-07],
      description: "Reversal of Salary",
      source_type: :system,
      correlation_id: Ecto.UUID.generate()
    })

  changeset.valid?
  #=> true
  ```
  """
  def system_changeset(transaction, attrs) do
    do_changeset(transaction, attrs, true)
  end

  defp do_changeset(transaction, attrs, allow_correlation_id?) do
    transaction
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:description,
      max: 500,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_transaction_description_length_invalid"
        )
    )
    |> validate_absence_of_correlation_id_on_create(allow_correlation_id?)
    |> validate_immutable_fields()
    |> foreign_key_constraint(:entity_id)
  end

  @spec void_changeset(t(), map()) :: Ecto.Changeset.t()
  @doc """
  Builds the set-once void changeset used by the void workflow.

  ## Examples

  ```elixir
  changeset =
    AurumFinance.Ledger.Transaction.void_changeset(transaction, %{
      voided_at: DateTime.utc_now(),
      correlation_id: Ecto.UUID.generate()
    })
  ```
  """
  def void_changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:voided_at, :correlation_id])
    |> validate_required([:voided_at],
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_voidable()
  end

  @spec source_types() :: [atom()]
  @doc """
  Returns the supported transaction source types.

  ## Examples

  ```elixir
  AurumFinance.Ledger.Transaction.source_types()
  #=> [:manual, :import, :system]
  ```
  """
  def source_types, do: @source_types

  defp validate_immutable_fields(%Ecto.Changeset{data: %{id: nil}} = changeset), do: changeset

  defp validate_immutable_fields(changeset) do
    Enum.reduce(@immutable_fields, changeset, fn field, acc ->
      case fetch_change(acc, field) do
        {:ok, value} ->
          maybe_add_immutable_error(acc, field, value)

        :error ->
          acc
      end
    end)
  end

  defp validate_voidable(%Ecto.Changeset{data: %{voided_at: nil}} = changeset), do: changeset

  defp validate_voidable(changeset) do
    add_error(
      changeset,
      :voided_at,
      Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_transaction_already_voided")
    )
  end

  defp validate_absence_of_correlation_id_on_create(changeset, true), do: changeset

  defp validate_absence_of_correlation_id_on_create(
         %Ecto.Changeset{data: %{id: nil}} = changeset,
         false
       ) do
    case get_change(changeset, :correlation_id) do
      nil ->
        changeset

      _value ->
        add_error(
          changeset,
          :correlation_id,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_transaction_correlation_id_reserved"
          )
        )
    end
  end

  defp validate_absence_of_correlation_id_on_create(changeset, false), do: changeset

  defp maybe_add_immutable_error(changeset, field, value) do
    if value == Map.get(changeset.data, field) do
      changeset
    else
      add_error(
        changeset,
        field,
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_transaction_immutable_field"
        )
      )
    end
  end
end
