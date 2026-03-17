defmodule AurumFinance.Repo.Migrations.CreateRuleGroupsAndRules do
  use Ecto.Migration

  def change do
    create table(:rule_groups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :scope_type, :string, null: false
      add :entity_id, references(:entities, type: :binary_id, on_delete: :delete_all)
      add :account_id, references(:accounts, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :description, :text
      add :priority, :integer, null: false
      add :target_fields, {:array, :string}, null: false, default: []
      add :is_active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime_usec)
    end

    create index(:rule_groups, [:scope_type])
    create index(:rule_groups, [:entity_id])
    create index(:rule_groups, [:account_id])
    create index(:rule_groups, [:scope_type, :priority])
    create index(:rule_groups, [:scope_type, :is_active])

    create unique_index(
             :rule_groups,
             [:name],
             name: :rule_groups_global_name_index,
             where: "scope_type = 'global'"
           )

    create unique_index(
             :rule_groups,
             [:entity_id, :name],
             name: :rule_groups_entity_name_index,
             where: "scope_type = 'entity'"
           )

    create unique_index(
             :rule_groups,
             [:account_id, :name],
             name: :rule_groups_account_name_index,
             where: "scope_type = 'account'"
           )

    create table(:rules, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :rule_group_id, references(:rule_groups, type: :binary_id, on_delete: :delete_all),
        null: false

      add :name, :string, null: false
      add :description, :text
      add :position, :integer, null: false
      add :is_active, :boolean, null: false, default: true
      add :stop_processing, :boolean, null: false, default: true
      add :expression, :text, null: false
      add :actions, :map, null: false, default: fragment("'[]'::jsonb")

      timestamps(type: :utc_datetime_usec)
    end

    create index(:rules, [:rule_group_id])
    create index(:rules, [:rule_group_id, :position])
  end
end
