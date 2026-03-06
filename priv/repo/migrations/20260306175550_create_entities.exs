defmodule AurumFinance.Repo.Migrations.CreateEntities do
  use Ecto.Migration

  def change do
    create table(:entities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :type, :string, null: false
      add :tax_identifier, :string
      add :country_code, :string, null: false
      add :fiscal_residency_country_code, :string
      add :default_tax_rate_type, :string
      add :notes, :text
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:entities, [:name])
    create index(:entities, [:type])
    create index(:entities, [:archived_at])
    create index(:entities, [:country_code])
  end
end
