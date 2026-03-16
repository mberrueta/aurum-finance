defmodule AurumFinance.Repo.Migrations.CreateClassificationRecords do
  use Ecto.Migration

  def change do
    create table(:classification_records, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transaction_id, references(:transactions, type: :binary_id, on_delete: :delete_all),
        null: false

      add :entity_id, references(:entities, type: :binary_id, on_delete: :delete_all), null: false

      add :category_account_id, references(:accounts, type: :binary_id)
      add :category_classified_by, :map
      add :category_manually_overridden, :boolean, null: false, default: false
      add :tags, :map, null: false, default: fragment("'[]'::jsonb")
      add :tags_classified_by, :map
      add :tags_manually_overridden, :boolean, null: false, default: false
      add :investment_type, :string
      add :investment_type_classified_by, :map
      add :investment_type_manually_overridden, :boolean, null: false, default: false
      add :notes, :text
      add :notes_classified_by, :map
      add :notes_manually_overridden, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:classification_records, [:transaction_id])
    create index(:classification_records, [:entity_id])
  end
end
