defmodule AurumFinance.ClassificationTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.Factory

  alias AurumFinance.Audit
  alias AurumFinance.Classification

  describe "rule group CRUD" do
    test "creates and lists visible rule groups" do
      entity = insert_entity()
      account = insert_account(entity)

      global_group =
        insert_rule_group(%{
          scope_type: :global,
          entity_id: nil,
          account_id: nil,
          name: "Global Group"
        })

      entity_group =
        insert_rule_group(%{
          scope_type: :entity,
          entity_id: entity.id,
          account_id: nil,
          name: "Entity Group"
        })

      account_group =
        insert_rule_group(%{
          scope_type: :account,
          entity_id: nil,
          account_id: account.id,
          name: "Account Group"
        })

      visible_groups = Classification.list_visible_rule_groups(entity.id, [account.id])

      assert Enum.map(visible_groups, & &1.id) == [
               account_group.id,
               entity_group.id,
               global_group.id
             ]
    end

    test "lists rule groups with public filters only" do
      global_group =
        insert_rule_group(%{
          scope_type: :global,
          entity_id: nil,
          account_id: nil,
          name: "Public Global Group"
        })

      assert [listed_group] = Classification.list_rule_groups(scope_type: :global)
      assert listed_group.id == global_group.id
    end
  end

  describe "rule CRUD" do
    test "creates a rule from structured conditions and writes an audit event" do
      rule_group = insert_rule_group()

      assert {:ok, rule} =
               Classification.create_rule(%{
                 rule_group_id: rule_group.id,
                 name: "Uber Rule",
                 position: 1,
                 conditions: [
                   %{field: :description, operator: :contains, value: "Uber", negate: false}
                 ],
                 actions: [%{field: :tags, operation: :add, value: "ride"}]
               })

      assert rule.expression == ~s|(description contains "Uber")|

      events = Audit.list_audit_events(entity_type: "rule", entity_id: rule.id)
      assert Enum.any?(events, &(&1.action == "created"))
    end

    test "rejects action fields outside the parent target_fields" do
      rule_group = insert_rule_group(%{target_fields: ["category"]})

      assert {:error, changeset} =
               Classification.create_rule(%{
                 rule_group_id: rule_group.id,
                 name: "Wrong Action Rule",
                 position: 1,
                 expression: ~s(description contains "Uber"),
                 actions: [%{field: :tags, operation: :add, value: "ride"}]
               })

      assert "Action field 'tags' is not declared in this group's target fields." in errors_on(
               changeset
             ).actions
    end
  end
end
