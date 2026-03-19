defmodule AurumFinance.Repo.Migrations.AddDailyBalanceSnapshotFoundation do
  use Ecto.Migration

  def up do
    alter table(:accounts) do
      add :timezone, :string, null: false
    end

    alter table(:postings) do
      modify :amount, :decimal, precision: 20, scale: 4, null: false
    end

    create table(:daily_balance_snapshots, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false

      add :entity_id, references(:entities, type: :binary_id, on_delete: :nothing), null: false

      add :snapshot_date, :date, null: false
      add :closing_balance, :decimal, precision: 20, scale: 4, null: false
      add :daily_delta, :decimal, precision: 20, scale: 4, null: false
      add :computed_at, :utc_datetime_usec, null: false
      add :projection_version, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:daily_balance_snapshots, [:account_id, :snapshot_date])
    create index(:daily_balance_snapshots, [:entity_id, :snapshot_date])
    create index(:daily_balance_snapshots, [:snapshot_date])
  end

  def down do
    drop index(:daily_balance_snapshots, [:snapshot_date])
    drop index(:daily_balance_snapshots, [:entity_id, :snapshot_date])
    drop unique_index(:daily_balance_snapshots, [:account_id, :snapshot_date])
    drop table(:daily_balance_snapshots)

    alter table(:postings) do
      modify :amount, :decimal, null: false
    end

    alter table(:accounts) do
      remove :timezone
    end
  end
end
