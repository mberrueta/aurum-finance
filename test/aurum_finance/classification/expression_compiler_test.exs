defmodule AurumFinance.Classification.ExpressionCompilerTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Classification.ExpressionCompiler

  describe "compile/1" do
    test "compiles a single condition" do
      assert {:ok, expression} =
               ExpressionCompiler.compile([
                 %{field: :description, operator: :contains, value: "Uber", negate: false}
               ])

      assert expression == ~s|(description contains "Uber")|
    end

    test "compiles multiple conditions into an AND expression" do
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

    test "supports the v1 operator and field matrix" do
      assert {:ok, _} =
               ExpressionCompiler.compile([
                 %{field: :description, operator: :equals, value: "Uber", negate: false},
                 %{field: :account_name, operator: :starts_with, value: "Cash", negate: false},
                 %{field: :institution_name, operator: :ends_with, value: "Bank", negate: false},
                 %{
                   field: :currency_code,
                   operator: :equals,
                   value: "USD",
                   negate: false
                 },
                 %{field: :source_type, operator: :equals, value: "manual", negate: false},
                 %{field: :account_type, operator: :equals, value: "asset", negate: false},
                 %{field: :amount, operator: :greater_than, value: "10", negate: false},
                 %{
                   field: :abs_amount,
                   operator: :greater_than_or_equal,
                   value: "50",
                   negate: false
                 },
                 %{
                   field: :date,
                   operator: :less_than_or_equal,
                   value: "2026-03-13",
                   negate: false
                 }
               ])
    end

    test "supports regex and unary operators" do
      assert {:ok, _} =
               ExpressionCompiler.compile([
                 %{
                   field: :description,
                   operator: :matches_regex,
                   value: "^UBER.*",
                   negate: false
                 },
                 %{field: :institution_name, operator: :is_not_empty, negate: false}
               ])
    end

    test "rejects empty conditions" do
      assert {:error, :empty_conditions} = ExpressionCompiler.compile([])
    end

    test "rejects invalid condition values" do
      assert {:error, :invalid_condition_value} =
               ExpressionCompiler.compile([
                 %{field: :amount, operator: :less_than, value: %{}, negate: false}
               ])
    end
  end
end
