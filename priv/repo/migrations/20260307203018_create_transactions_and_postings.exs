defmodule AurumFinance.Repo.Migrations.CreateTransactionsAndPostings do
  use Ecto.Migration

  def up do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_id, references(:entities, type: :binary_id, on_delete: :nothing), null: false
      add :date, :date, null: false
      add :description, :string, null: false
      add :source_type, :string, null: false
      add :correlation_id, :binary_id
      add :voided_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:transactions, [:entity_id])
    create index(:transactions, [:entity_id, :date])
    create index(:transactions, [:entity_id, :correlation_id])
    create index(:transactions, [:correlation_id])

    create table(:postings, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :transaction_id, references(:transactions, type: :binary_id, on_delete: :restrict),
        null: false

      add :account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false
      add :amount, :decimal, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:postings, [:transaction_id])
    create index(:postings, [:account_id])
  end

  def down do
    drop table(:postings)
    drop table(:transactions)
  end
end
