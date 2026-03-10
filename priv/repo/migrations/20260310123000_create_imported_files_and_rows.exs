defmodule AurumFinance.Repo.Migrations.CreateImportedFilesAndRows do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:imported_files, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false
      add :filename, :string, null: false
      add :sha256, :string, null: false
      add :format, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :row_count, :integer, null: false, default: 0
      add :imported_row_count, :integer, null: false, default: 0
      add :skipped_row_count, :integer, null: false, default: 0
      add :invalid_row_count, :integer, null: false, default: 0
      add :error_message, :text
      add :warnings, :map, null: false, default: %{}
      add :storage_path, :string, null: false
      add :processed_at, :utc_datetime_usec
      add :content_type, :string
      add :byte_size, :integer

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:imported_files, [:account_id])
    create_if_not_exists index(:imported_files, [:account_id, :inserted_at])
    create_if_not_exists index(:imported_files, [:account_id, :status])

    create_if_not_exists table(:imported_rows, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :imported_file_id, references(:imported_files, type: :binary_id, on_delete: :restrict),
        null: false

      add :account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false
      add :row_index, :integer, null: false
      add :raw_data, :map, null: false
      add :description, :string
      add :normalized_description, :string
      add :posted_on, :date
      add :amount, :decimal
      add :currency, :string
      add :fingerprint, :string
      add :status, :string, null: false
      add :skip_reason, :string
      add :validation_error, :text

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create_if_not_exists index(:imported_rows, [:imported_file_id])
    create_if_not_exists index(:imported_rows, [:account_id, :imported_file_id])
    create_if_not_exists index(:imported_rows, [:account_id, :fingerprint])

    create_if_not_exists unique_index(
                           :imported_rows,
                           [:account_id, :fingerprint],
                           where: "status = 'ready'",
                           name: :imported_rows_account_id_fingerprint_ready_index
                         )
  end

  def down do
    drop_if_exists table(:imported_rows)
    drop_if_exists table(:imported_files)
  end
end
