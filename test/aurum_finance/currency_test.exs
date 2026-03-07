defmodule AurumFinance.CurrencyTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Currency

  doctest AurumFinance.Currency

  test "returns defaults for known countries" do
    assert Currency.default_code_for_country("BR") == "BRL"
    assert Currency.default_code_for_country("cl") == "CLP"
    assert Currency.default_code_for_country("DE") == "EUR"
    assert Currency.default_code_for_country("AG") == "XCD"
    assert Currency.default_code_for_country("CM") == "XAF"
    assert Currency.default_code_for_country("SN") == "XOF"
  end

  test "falls back to USD for unknown or nil country codes" do
    assert Currency.default_code_for_country(nil) == "USD"
    assert Currency.default_code_for_country("??") == "USD"
    assert Currency.default_code_for_country("") == "USD"
  end

  test "returns sorted select options" do
    options = Currency.options()

    assert {"BRL - Brazilian Real", "BRL"} in options
    assert {"USD - US Dollar", "USD"} in options
    assert options == Enum.sort(options)
  end
end
