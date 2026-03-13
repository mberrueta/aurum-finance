defmodule AurumFinance.Classification.RuleActionTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Classification.RuleAction

  describe "changeset/2" do
    test "accepts valid field and operation pairs" do
      for attrs <- [
            %{field: :category, operation: :set, value: Ecto.UUID.generate()},
            %{field: :tags, operation: :add, value: "ride"},
            %{field: :tags, operation: :remove, value: "ride"},
            %{field: :investment_type, operation: :set, value: "bond"},
            %{field: :notes, operation: :set, value: "memo"},
            %{field: :notes, operation: :append, value: "memo"}
          ] do
        changeset = RuleAction.changeset(%RuleAction{}, attrs)

        assert changeset.valid?
      end
    end

    test "rejects incompatible field and operation pairs" do
      changeset =
        RuleAction.changeset(%RuleAction{}, %{
          field: :category,
          operation: :append,
          value: "memo"
        })

      refute changeset.valid?
      assert "error_rule_action_operation_invalid" in errors_on(changeset).operation
    end
  end
end
