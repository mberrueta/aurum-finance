defmodule AurumFinance.Classification.ExpressionValidatorTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Classification.ExpressionValidator

  describe "validate_expression/1" do
    test "accepts valid expressions" do
      assert {:ok, _expression} =
               ExpressionValidator.validate_expression(
                 ~s|(description contains "Uber") AND (amount < -10)|
               )
    end

    test "rejects invalid fields" do
      assert {:error, :invalid_expression} =
               ExpressionValidator.validate_expression(~s|memo contains "Uber"|)
    end

    test "rejects invalid regular expressions" do
      assert {:error, :invalid_regex} =
               ExpressionValidator.validate_expression(~s|description matches_regex "["|)
    end
  end
end
