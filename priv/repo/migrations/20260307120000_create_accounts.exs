defmodule AurumFinance.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :entity_id, references(:entities, type: :binary_id, on_delete: :nothing), null: false
      add :name, :string, null: false
      add :account_type, :string, null: false
      add :operational_subtype, :string
      add :management_group, :string, null: false
      add :currency_code, :string, null: false
      add :institution_name, :string
      add :institution_account_ref, :string
      add :notes, :text
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:accounts, [:entity_id])
    create index(:accounts, [:entity_id, :archived_at])
  end
end
