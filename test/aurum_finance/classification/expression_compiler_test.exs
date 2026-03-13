defmodule AurumFinance.Classification.ExpressionCompilerTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Classification.ExpressionCompiler

  describe "compile/1" do
    test "compiles multiple structured conditions into the DSL" do
      assert {:ok, expression} =
               ExpressionCompiler.compile([
                 %{field: :description, operator: :contains, value: "Uber", negate: false},
                 %{field: :amount, operator: :less_than, value: "-10", negate: false}
               ])

      assert expression == ~s|(description contains "Uber") AND (amount < -10)|
    end

    test "compiles negated conditions" do
      assert {:ok, expression} =
               ExpressionCompiler.compile([
                 %{field: :description, operator: :contains, value: "ATM", negate: true}
               ])

      assert expression == ~s|(NOT (description contains "ATM"))|
    end
  end
end
