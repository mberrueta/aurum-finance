defmodule AurumFinance.Ingestion.ImportedFile do
  @moduledoc """
  Account-scoped uploaded source file record for the import pipeline.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ledger.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @formats [:csv]
  @statuses [:pending, :processing, :complete, :failed]

  @type t :: %__MODULE__{}

  @required [:account_id, :filename, :sha256, :format, :status, :storage_path]
  @optional [
    :row_count,
    :imported_row_count,
    :skipped_row_count,
    :invalid_row_count,
    :error_message,
    :warnings,
    :processed_at,
    :content_type,
    :byte_size
  ]

  schema "imported_files" do
    field :filename, :string
    field :sha256, :string
    field :format, Ecto.Enum, values: @formats
    field :status, Ecto.Enum, values: @statuses
    field :row_count, :integer, default: 0
    field :imported_row_count, :integer, default: 0
    field :skipped_row_count, :integer, default: 0
    field :invalid_row_count, :integer, default: 0
    field :error_message, :string
    field :warnings, :map, default: %{}
    field :storage_path, :string
    field :processed_at, :utc_datetime_usec
    field :content_type, :string
    field :byte_size, :integer

    belongs_to :account, Account
    has_many :imported_rows, ImportedRow

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the imported file changeset used by the ingestion context.

  ## Examples

  ```elixir
  changeset =
    AurumFinance.Ingestion.ImportedFile.changeset(%AurumFinance.Ingestion.ImportedFile{}, %{
      account_id: Ecto.UUID.generate(),
      filename: "statement.csv",
      sha256: String.duplicate("a", 64),
      format: :csv,
      status: :pending,
      storage_path: "/tmp/imports/statement.csv"
    })

  changeset.valid?
  #=> true
  ```
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(imported_file, attrs) do
    imported_file
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:filename,
      min: 1,
      max: 255,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_filename_length_invalid"
        )
    )
    |> validate_length(:sha256,
      is: 64,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_sha256_length_invalid"
        )
    )
    |> validate_length(:storage_path,
      min: 1,
      max: 1024,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_storage_path_length_invalid"
        )
    )
    |> validate_length(:error_message,
      max: 2000,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_error_message_length_invalid"
        )
    )
    |> validate_length(:content_type,
      max: 255,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_content_type_length_invalid"
        )
    )
    |> validate_number(:row_count,
      greater_than_or_equal_to: 0,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_count_must_be_non_negative"
        )
    )
    |> validate_number(:imported_row_count,
      greater_than_or_equal_to: 0,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_count_must_be_non_negative"
        )
    )
    |> validate_number(:skipped_row_count,
      greater_than_or_equal_to: 0,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_count_must_be_non_negative"
        )
    )
    |> validate_number(:invalid_row_count,
      greater_than_or_equal_to: 0,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_count_must_be_non_negative"
        )
    )
    |> validate_number(:byte_size,
      greater_than_or_equal_to: 0,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_imported_file_byte_size_must_be_non_negative"
        )
    )
    |> foreign_key_constraint(:account_id)
  end

  @doc """
  Returns the formats currently supported for imported files.

  ## Examples

  ```elixir
  AurumFinance.Ingestion.ImportedFile.format_values()
  #=> [:csv]
  ```
  """
  @spec format_values() :: [atom()]
  def format_values, do: @formats

  @doc """
  Returns the lifecycle statuses supported for imported files.

  ## Examples

  ```elixir
  AurumFinance.Ingestion.ImportedFile.status_values()
  #=> [:pending, :processing, :complete, :failed]
  ```
  """
  @spec status_values() :: [atom()]
  def status_values, do: @statuses
end
