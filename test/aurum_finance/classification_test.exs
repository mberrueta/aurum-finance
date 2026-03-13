defmodule AurumFinance.ClassificationTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.Factory

  alias AurumFinance.Audit
  alias AurumFinance.Classification
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Repo

  describe "list_rule_groups/1" do
    test "returns groups ordered by scope precedence, priority, and name" do
      entity = insert_entity()
      account = insert_account(entity)

      global_group =
        insert_global_rule_group(%{
          name: "Zulu Global",
          priority: 3
        })

      entity_group =
        insert_rule_group(entity, %{
          name: "Alpha Entity",
          priority: 2
        })

      account_group =
        insert_account_rule_group(account, %{
          name: "Bravo Account",
          priority: 1
        })

      assert Enum.map(Classification.list_rule_groups(), & &1.id) == [
               account_group.id,
               entity_group.id,
               global_group.id
             ]
    end

    test "filters by scope and active state" do
      active_group = insert_global_rule_group(%{name: "Active Group", is_active: true})
      _inactive_group = insert_global_rule_group(%{name: "Inactive Group", is_active: false})

      assert [listed_group] =
               Classification.list_rule_groups(scope_type: :global, is_active: true)

      assert listed_group.id == active_group.id
    end
  end

  describe "list_visible_rule_groups/3" do
    test "returns global plus matching entity and account groups" do
      entity = insert_entity()
      other_entity = insert_entity()
      account = insert_account(entity)
      _other_account = insert_account(other_entity)

      global_group = insert_global_rule_group(%{name: "Global Group"})
      entity_group = insert_rule_group(entity, %{name: "Entity Group"})
      account_group = insert_account_rule_group(account, %{name: "Account Group"})
      _other_entity_group = insert_rule_group(other_entity, %{name: "Other Entity Group"})

      visible_groups = Classification.list_visible_rule_groups(entity.id, [account.id])

      assert Enum.map(visible_groups, & &1.id) == [
               account_group.id,
               entity_group.id,
               global_group.id
             ]
    end
  end

  describe "get_rule_group!/1" do
    test "loads one rule group with rules" do
      rule_group = insert_rule_group()
      rule = insert_rule(rule_group)

      loaded_group = Classification.get_rule_group!(rule_group.id)

      assert loaded_group.id == rule_group.id
      assert Enum.map(loaded_group.rules, & &1.id) == [rule.id]
    end
  end

  describe "create_rule_group/1" do
    test "creates global, entity, and account scoped groups" do
      entity = insert_entity()
      account = insert_account(entity)
      entity_id = entity.id
      account_id = account.id

      assert {:ok, %RuleGroup{scope_type: :global, entity_id: nil, account_id: nil}} =
               Classification.create_rule_group(%{
                 scope_type: :global,
                 name: "Global Group",
                 priority: 1
               })

      assert {:ok, %RuleGroup{scope_type: :entity, entity_id: ^entity_id, account_id: nil}} =
               Classification.create_rule_group(%{
                 scope_type: :entity,
                 entity_id: entity_id,
                 name: "Entity Group",
                 priority: 1
               })

      assert {:ok, %RuleGroup{scope_type: :account, entity_id: nil, account_id: ^account_id}} =
               Classification.create_rule_group(%{
                 scope_type: :account,
                 account_id: account_id,
                 name: "Account Group",
                 priority: 1
               })
    end

    test "returns validation errors for missing name, invalid priority, and invalid scope" do
      entity = insert_entity()
      account = insert_account(entity)

      assert {:error, changeset} =
               Classification.create_rule_group(%{
                 scope_type: :entity,
                 entity_id: entity.id,
                 account_id: account.id,
                 priority: 0
               })

      assert "This field is required." in errors_on(changeset).name
      assert "Rule group priority must be greater than zero." in errors_on(changeset).priority

      assert "Rule group scope is inconsistent with the selected entity/account ownership." in errors_on(
               changeset
             ).scope_type
    end

    test "enforces scoped uniqueness" do
      insert_global_rule_group(%{name: "Duplicated Group"})

      assert {:error, changeset} =
               Classification.create_rule_group(%{
                 scope_type: :global,
                 name: "Duplicated Group",
                 priority: 1
               })

      assert "A group with this name already exists in this scope." in errors_on(changeset).name
    end
  end

  describe "update_rule_group/2" do
    test "updates a group and writes an audit event" do
      rule_group = insert_rule_group(%{name: "Old Name"})

      assert {:ok, updated_group} =
               Classification.update_rule_group(rule_group, %{
                 name: "New Name",
                 priority: 4
               })

      assert updated_group.name == "New Name"
      assert updated_group.priority == 4

      assert Enum.any?(
               Audit.list_audit_events(entity_type: "rule_group", entity_id: rule_group.id),
               &(&1.action == "updated")
             )
    end

    test "accepts a decorated map with id and reloads the persisted rule group" do
      rule_group = insert_rule_group(%{name: "Decorated"})

      decorated_group = %{
        id: rule_group.id,
        name: rule_group.name,
        priority: rule_group.priority,
        scope_label: "Entity",
        scope_target_label: "Personal",
        rule_count: 0
      }

      assert {:ok, updated_group} =
               Classification.update_rule_group(decorated_group, %{priority: 3})

      assert updated_group.id == rule_group.id
      assert updated_group.priority == 3
    end
  end

  describe "delete_rule_group/1" do
    test "deletes the group, cascades rules, and writes an audit event" do
      rule_group = insert_rule_group()
      rule_group_id = rule_group.id
      rule = insert_rule(rule_group)

      assert {:ok, %RuleGroup{id: ^rule_group_id}} = Classification.delete_rule_group(rule_group)
      assert_raise Ecto.NoResultsError, fn -> Classification.get_rule_group!(rule_group_id) end
      assert Repo.get(Rule, rule.id) == nil

      assert Enum.any?(
               Audit.list_audit_events(entity_type: "rule_group", entity_id: rule_group_id),
               &(&1.action == "deleted")
             )
    end

    test "accepts a decorated map with id and deletes the persisted rule group" do
      rule_group = insert_rule_group(%{name: "Decorated Delete"})
      rule_group_id = rule_group.id

      decorated_group = %{
        id: rule_group.id,
        name: rule_group.name,
        priority: rule_group.priority,
        scope_label: "Entity",
        scope_target_label: "Personal",
        rule_count: 0
      }

      assert {:ok, %RuleGroup{id: ^rule_group_id}} =
               Classification.delete_rule_group(decorated_group)

      assert_raise Ecto.NoResultsError, fn -> Classification.get_rule_group!(rule_group_id) end
    end
  end

  describe "change_rule_group/2" do
    test "returns a changeset for form handling" do
      changeset =
        Classification.change_rule_group(%RuleGroup{}, %{
          scope_type: :global,
          name: "Rules",
          priority: 1
        })

      assert changeset.valid?
    end
  end

  describe "list_rules/1" do
    test "orders rules by position and name" do
      rule_group = insert_rule_group()
      later_rule = insert_rule(rule_group, %{name: "Zulu", position: 2})
      earlier_rule = insert_rule(rule_group, %{name: "Alpha", position: 1})

      assert Enum.map(Classification.list_rules(rule_group_id: rule_group.id), & &1.id) == [
               earlier_rule.id,
               later_rule.id
             ]
    end
  end

  describe "get_rule!/1" do
    test "loads one rule with its group" do
      rule_group = insert_rule_group()
      rule = insert_rule(rule_group)

      loaded_rule = Classification.get_rule!(rule.id)

      assert loaded_rule.id == rule.id
      assert loaded_rule.rule_group_id == rule_group.id
    end
  end

  describe "create_rule/1" do
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

      assert Enum.any?(
               Audit.list_audit_events(entity_type: "rule", entity_id: rule.id),
               &(&1.action == "created")
             )
    end

    test "creates a rule from a direct expression" do
      rule_group = insert_rule_group()

      assert {:ok, rule} =
               Classification.create_rule(%{
                 rule_group_id: rule_group.id,
                 name: "Direct Rule",
                 position: 1,
                 expression: ~s|description contains "Uber"|,
                 actions: [%{field: :tags, operation: :add, value: "ride"}]
               })

      assert rule.expression == ~s|description contains "Uber"|
    end

    test "rejects invalid expressions" do
      rule_group = insert_rule_group()

      assert {:error, changeset} =
               Classification.create_rule(%{
                 rule_group_id: rule_group.id,
                 name: "Invalid Expression Rule",
                 position: 1,
                 expression: ~s|memo contains "Uber"|,
                 actions: [%{field: :tags, operation: :add, value: "ride"}]
               })

      assert "Rule expression is invalid." in errors_on(changeset).expression
    end

    test "rejects invalid action combinations" do
      rule_group = insert_rule_group()

      assert {:error, changeset} =
               Classification.create_rule(%{
                 rule_group_id: rule_group.id,
                 name: "Invalid Action Rule",
                 position: 1,
                 expression: ~s|description contains "Uber"|,
                 actions: [%{field: :category, operation: :append, value: "bad"}]
               })

      assert [%{operation: [message]}] = errors_on(changeset).actions
      assert message == "This operation is not valid for the selected classification field."
    end

    test "rejects action fields outside the parent target_fields" do
      rule_group = insert_rule_group(%{target_fields: ["category"]})

      assert {:error, changeset} =
               Classification.create_rule(%{
                 rule_group_id: rule_group.id,
                 name: "Wrong Action Rule",
                 position: 1,
                 expression: ~s|description contains "Uber"|,
                 actions: [%{field: :tags, operation: :add, value: "ride"}]
               })

      assert "Action field 'tags' is not declared in this group's target fields." in errors_on(
               changeset
             ).actions
    end
  end

  describe "update_rule/2" do
    test "updates a rule and writes an audit event" do
      rule_group = insert_rule_group()
      rule = insert_rule(rule_group)

      assert {:ok, updated_rule} =
               Classification.update_rule(rule, %{
                 expression: ~s|description contains "Lyft"|,
                 actions: [%{field: :tags, operation: :add, value: "taxi"}]
               })

      assert updated_rule.expression == ~s|description contains "Lyft"|
      assert hd(updated_rule.actions).value == "taxi"

      assert Enum.any?(
               Audit.list_audit_events(entity_type: "rule", entity_id: rule.id),
               &(&1.action == "updated")
             )
    end

    test "rejects an invalid updated expression" do
      rule_group = insert_rule_group()
      rule = insert_rule(rule_group)

      assert {:error, changeset} =
               Classification.update_rule(rule, %{
                 expression: ~s|memo contains "Lyft"|
               })

      assert "Rule expression is invalid." in errors_on(changeset).expression
    end
  end

  describe "delete_rule/1" do
    test "deletes a rule and writes an audit event" do
      rule_group = insert_rule_group()
      rule = insert_rule(rule_group)
      rule_id = rule.id

      assert {:ok, %Rule{id: ^rule_id}} = Classification.delete_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Classification.get_rule!(rule_id) end

      assert Enum.any?(
               Audit.list_audit_events(entity_type: "rule", entity_id: rule_id),
               &(&1.action == "deleted")
             )
    end
  end

  describe "change_rule/2" do
    test "returns a changeset for form handling" do
      rule_group = insert_rule_group()

      changeset =
        Classification.change_rule(%Rule{}, %{
          rule_group_id: rule_group.id,
          name: "Rule",
          position: 1,
          expression: ~s|description contains "Uber"|,
          actions: [%{field: :tags, operation: :add, value: "ride"}]
        })

      assert changeset.valid?
    end
  end
end
