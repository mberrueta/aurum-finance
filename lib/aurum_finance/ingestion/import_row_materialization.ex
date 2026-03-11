defmodule AurumFinance.Ingestion.ImportRowMaterialization do
  @moduledoc """
  Durable row-level materialization result and traceability record.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ledger.Transaction

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:committed, :skipped, :failed]

  @type t :: %__MODULE__{}

  @required [:import_materialization_id, :imported_row_id, :status]
  @optional [:transaction_id, :outcome_reason]

  schema "import_row_materializations" do
    field :status, Ecto.Enum, values: @statuses
    field :outcome_reason, :string

    belongs_to :import_materialization, ImportMaterialization
    belongs_to :imported_row, ImportedRow
    belongs_to :transaction, Transaction

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Builds the import row materialization changeset.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(import_row_materialization, attrs) do
    import_row_materialization
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:outcome_reason,
      max: 2000,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_import_row_materialization_outcome_reason_length_invalid"
        )
    )
    |> validate_transaction_shape()
    |> foreign_key_constraint(:import_materialization_id)
    |> foreign_key_constraint(:imported_row_id)
    |> foreign_key_constraint(:transaction_id)
    |> unique_constraint(:imported_row_id,
      name: :import_row_materializations_imported_row_committed_index
    )
    |> unique_constraint(:transaction_id,
      name: :import_row_materializations_transaction_id_unique_index
    )
  end

  @doc """
  Returns the supported row-level materialization statuses.
  """
  @spec status_values() :: [atom()]
  def status_values, do: @statuses

  defp validate_transaction_shape(changeset) do
    status = get_field(changeset, :status)
    transaction_id = get_field(changeset, :transaction_id)

    cond do
      status == :committed and is_nil(transaction_id) ->
        add_error(
          changeset,
          :transaction_id,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_import_row_materialization_transaction_required"
          )
        )

      status in [:skipped, :failed] and not is_nil(transaction_id) ->
        add_error(
          changeset,
          :transaction_id,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_import_row_materialization_transaction_forbidden"
          )
        )

      true ->
        changeset
    end
  end
end
