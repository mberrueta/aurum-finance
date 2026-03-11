defmodule AurumFinance.Ingestion.ImportMaterialization do
  @moduledoc """
  Durable async materialization run record for one imported file.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ImportRowMaterialization
  alias AurumFinance.Ledger.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:pending, :processing, :completed, :completed_with_errors, :failed]

  @type t :: %__MODULE__{}

  @required [:imported_file_id, :account_id, :status, :requested_by]
  @optional [
    :rows_considered,
    :rows_materialized,
    :rows_skipped_duplicate,
    :rows_failed,
    :error_message,
    :started_at,
    :finished_at
  ]

  schema "import_materializations" do
    field :status, Ecto.Enum, values: @statuses
    field :requested_by, :string
    field :rows_considered, :integer, default: 0
    field :rows_materialized, :integer, default: 0
    field :rows_skipped_duplicate, :integer, default: 0
    field :rows_failed, :integer, default: 0
    field :error_message, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec

    belongs_to :imported_file, ImportedFile
    belongs_to :account, Account
    has_many :row_materializations, ImportRowMaterialization

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the import materialization changeset.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(import_materialization, attrs) do
    import_materialization
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:requested_by,
      min: 1,
      max: 255,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_import_materialization_requested_by_length_invalid"
        )
    )
    |> validate_length(:error_message,
      max: 2000,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_import_materialization_error_message_length_invalid"
        )
    )
    |> validate_number_fields()
    |> foreign_key_constraint(:imported_file_id)
    |> foreign_key_constraint(:account_id)
  end

  @doc """
  Returns the supported materialization statuses.
  """
  @spec status_values() :: [atom()]
  def status_values, do: @statuses

  defp validate_number_fields(changeset) do
    Enum.reduce(
      [
        :rows_considered,
        :rows_materialized,
        :rows_skipped_duplicate,
        :rows_failed
      ],
      changeset,
      fn field, acc ->
        validate_number(acc, field,
          greater_than_or_equal_to: 0,
          message:
            Gettext.dgettext(
              AurumFinanceWeb.Gettext,
              "errors",
              "error_import_materialization_count_must_be_non_negative"
            )
        )
      end
    )
  end
end
