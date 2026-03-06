defmodule AurumFinance.Repo.Migrations.CreateAuditEvents do
  use Ecto.Migration

  def change do
    create table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :entity_type, :string, null: false
      add :entity_id, :binary_id, null: false
      add :action, :string, null: false
      add :actor, :string, null: false
      add :channel, :string, null: false
      add :before, :map
      add :after, :map
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:audit_events, [:entity_type, :entity_id])
    create index(:audit_events, [:action])
    create index(:audit_events, [:channel])
    create index(:audit_events, [:occurred_at])
  end
end
