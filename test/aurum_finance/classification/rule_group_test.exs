defmodule AurumFinance.Classification.RuleGroupTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.Factory

  alias AurumFinance.Classification.RuleGroup

  describe "changeset/2" do
    test "accepts a valid global scope" do
      changeset =
        RuleGroup.changeset(%RuleGroup{}, %{
          scope_type: :global,
          name: "Global Rules",
          priority: 1,
          target_fields: ["category"]
        })

      assert changeset.valid?
    end

    test "accepts a valid entity scope" do
      entity = insert(:entity)

      changeset =
        RuleGroup.changeset(%RuleGroup{}, %{
          scope_type: :entity,
          entity_id: entity.id,
          name: "Entity Rules",
          priority: 1
        })

      assert changeset.valid?
    end

    test "accepts a valid account scope" do
      account = insert(:account)

      changeset =
        RuleGroup.changeset(%RuleGroup{}, %{
          scope_type: :account,
          account_id: account.id,
          name: "Account Rules",
          priority: 1
        })

      assert changeset.valid?
    end

    test "rejects invalid scope combinations" do
      entity = insert(:entity)
      account = insert(:account)

      changeset =
        RuleGroup.changeset(%RuleGroup{}, %{
          scope_type: :entity,
          entity_id: entity.id,
          account_id: account.id,
          name: "Broken Scope",
          priority: 1
        })

      refute changeset.valid?
      assert "error_rule_group_scope_invalid" in errors_on(changeset).scope_type
    end

    test "rejects non-positive priority" do
      changeset =
        RuleGroup.changeset(%RuleGroup{}, %{
          scope_type: :global,
          name: "Invalid Priority",
          priority: 0
        })

      refute changeset.valid?
      assert "error_rule_group_priority_invalid" in errors_on(changeset).priority
    end
  end
end
