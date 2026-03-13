defmodule AurumFinance.Classification.RuleTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.Factory

  alias AurumFinance.Classification.Rule

  describe "changeset/2" do
    test "accepts valid embedded actions" do
      rule_group = insert(:rule_group)

      changeset =
        Rule.changeset(%Rule{}, %{
          rule_group_id: rule_group.id,
          name: "Uber Rule",
          position: 1,
          expression: "description contains \"Uber\"",
          actions: [%{field: :tags, operation: :add, value: "ride"}]
        })

      assert changeset.valid?
    end

    test "requires at least one action" do
      rule_group = insert(:rule_group)

      changeset =
        Rule.changeset(%Rule{}, %{
          rule_group_id: rule_group.id,
          name: "Empty Action Rule",
          position: 1,
          expression: "description contains \"Uber\"",
          actions: []
        })

      refute changeset.valid?
      assert "error_rule_actions_required" in errors_on(changeset).actions
    end

    test "rejects blank expressions" do
      rule_group = insert(:rule_group)

      changeset =
        Rule.changeset(%Rule{}, %{
          rule_group_id: rule_group.id,
          name: "Blank Expression Rule",
          position: 1,
          expression: "",
          actions: [%{field: :tags, operation: :add, value: "ride"}]
        })

      refute changeset.valid?
      assert "error_rule_expression_required" in errors_on(changeset).expression
    end
  end
end
