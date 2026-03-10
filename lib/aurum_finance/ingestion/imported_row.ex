defmodule AurumFinance.Ingestion.ImportedRow do
  @moduledoc """
  Immutable imported-row evidence record for parsed file rows.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Helpers
  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ledger.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:ready, :duplicate, :invalid]

  @type t :: %__MODULE__{}

  @required [:imported_file_id, :account_id, :row_index, :raw_data, :status]
  @optional [
    :description,
    :normalized_description,
    :posted_on,
    :amount,
    :currency,
    :fingerprint,
    :skip_reason,
    :validation_error
  ]

  schema "imported_rows" do
    field :row_index, :integer
    field :raw_data, :map
    field :description, :string
    field :normalized_description, :string
    field :posted_on, :date
    field :amount, :decimal
    field :currency, :string
    field :fingerprint, :string
    field :status, Ecto.Enum, values: @statuses
    field :skip_reason, :string
    field :validation_error, :string

    belongs_to :imported_file, ImportedFile
    belongs_to :account, Account

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Builds the imported row changeset used to persist immutable row evidence.

  ## Examples

  ```elixir
  changeset =
    AurumFinance.Ingestion.ImportedRow.changeset(%AurumFinance.Ingestion.ImportedRow{}, %{
      imported_file_id: Ecto.UUID.generate(),
      account_id: Ecto.UUID.generate(),
      row_index: 1,
      raw_data: %{"description" => "Coffee"},
      description: "Coffee",
      normalized_description: "coffee",
      posted_on: ~D[2026-03-10],
      amount: Decimal.new("4.50"),
      currency: "USD",
      fingerprint: "fp-1",
      status: :ready
    })

  changeset.valid?
  #=> true
  ```
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(imported_row, attrs) do
    imported_row
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_number(:row_index,
      greater_than_or_equal_to: 0,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_row_row_index_must_be_non_negative"
        )
    )
    |> validate_length(:description,
      max: 500,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_row_description_length_invalid"
        )
    )
    |> validate_length(:normalized_description,
      max: 500,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_row_description_length_invalid"
        )
    )
    |> validate_length(:currency,
      is: 3,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_row_currency_length_invalid"
        )
    )
    |> update_change(:currency, &Helpers.normalize_to_upper/1)
    |> validate_length(:fingerprint,
      max: 255,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_row_fingerprint_length_invalid"
        )
    )
    |> validate_length(:skip_reason,
      max: 500,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_row_skip_reason_length_invalid"
        )
    )
    |> validate_length(:validation_error,
      max: 2000,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_row_validation_error_length_invalid"
        )
    )
    |> validate_fingerprint_requirement()
    |> foreign_key_constraint(:imported_file_id)
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:fingerprint, name: :imported_rows_account_id_fingerprint_ready_index)
  end

  @doc """
  Returns the lifecycle statuses supported for imported rows.

  ## Examples

  ```elixir
  AurumFinance.Ingestion.ImportedRow.status_values()
  #=> [:ready, :duplicate, :invalid]
  ```
  """
  @spec status_values() :: [atom()]
  def status_values, do: @statuses

  defp validate_fingerprint_requirement(changeset) do
    status = get_field(changeset, :status)
    fingerprint = get_field(changeset, :fingerprint)

    cond do
      status in [:ready, :duplicate] and Helpers.blank?(fingerprint) ->
        add_error(
          changeset,
          :fingerprint,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_imported_row_fingerprint_required"
          )
        )

      status == :invalid ->
        changeset

      true ->
        changeset
    end
  end
end
