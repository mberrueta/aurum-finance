defmodule AurumFinance.Repo.Migrations.AddImportReviewMaterializationWorkflow do
  use Ecto.Migration

  def change do
    create table(:import_materializations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :imported_file_id,
          references(:imported_files, type: :binary_id, on_delete: :restrict),
          null: false

      add :account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false
      add :status, :string, null: false
      add :requested_by, :string, null: false
      add :rows_considered, :integer, null: false, default: 0
      add :rows_materialized, :integer, null: false, default: 0
      add :rows_skipped_duplicate, :integer, null: false, default: 0
      add :rows_failed, :integer, null: false, default: 0
      add :error_message, :text
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:import_materializations, [:imported_file_id])
    create index(:import_materializations, [:account_id, :inserted_at])
    create index(:import_materializations, [:imported_file_id, :status])

    create constraint(:import_materializations, :import_materializations_status_valid,
             check:
               "status in ('pending', 'processing', 'completed', 'completed_with_errors', 'failed')"
           )

    create constraint(
             :import_materializations,
             :import_materializations_rows_considered_non_negative,
             check: "rows_considered >= 0"
           )

    create constraint(
             :import_materializations,
             :import_materializations_rows_materialized_non_negative,
             check: "rows_materialized >= 0"
           )

    create constraint(
             :import_materializations,
             :import_materializations_rows_skipped_duplicate_non_negative,
             check: "rows_skipped_duplicate >= 0"
           )

    create constraint(:import_materializations, :import_materializations_rows_failed_non_negative,
             check: "rows_failed >= 0"
           )

    create table(:import_row_materializations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :import_materialization_id,
          references(:import_materializations, type: :binary_id, on_delete: :restrict),
          null: false

      add :imported_row_id,
          references(:imported_rows, type: :binary_id, on_delete: :restrict),
          null: false

      add :transaction_id, references(:transactions, type: :binary_id, on_delete: :restrict)
      add :status, :string, null: false
      add :outcome_reason, :text

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:import_row_materializations, [:import_materialization_id])
    create index(:import_row_materializations, [:imported_row_id])

    create unique_index(:import_row_materializations, [:imported_row_id],
             where: "status = 'committed'",
             name: :import_row_materializations_imported_row_committed_index
           )

    create unique_index(:import_row_materializations, [:transaction_id],
             where: "transaction_id is not null",
             name: :import_row_materializations_transaction_id_unique_index
           )

    create constraint(:import_row_materializations, :import_row_materializations_status_valid,
             check: "status in ('committed', 'skipped', 'failed')"
           )

    create constraint(
             :import_row_materializations,
             :import_row_materializations_status_transaction_shape_valid,
             check:
               "(status = 'committed' and transaction_id is not null) or (status in ('skipped', 'failed') and transaction_id is null)"
           )
  end
end
