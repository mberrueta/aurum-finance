defmodule AurumFinance.HelpersTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Helpers

  describe "deep_atomize/1" do
    test "converts string keys to atoms in nested maps/lists" do
      input = %{"user" => %{"name" => "John"}, "items" => [%{"id" => 1}]}
      expected = %{user: %{name: "John"}, items: [%{id: 1}]}
      assert Helpers.deep_atomize(input) == expected
    end

    test "keeps unknown keys as strings" do
      input = %{"unknown_new_key" => 123}
      assert Helpers.deep_atomize(input) == %{"unknown_new_key" => 123}
    end
  end

  describe "slugify/1" do
    test "slugifies text" do
      assert Helpers.slugify("Another Example with Special Characters!@#$%") ==
               "another-example-with-special-characters"
    end
  end

  describe "format_price/2" do
    test "formats decimal by country code" do
      assert Helpers.format_price("BR", Decimal.new("123.45")) == "R$ 123,45"
      assert Helpers.format_price("BR", Decimal.new("123.456")) == "R$ 123,46"
      assert Helpers.format_price("US", Decimal.new("123.45")) == "U$D 123.45"
    end

    test "accepts numbers and keeps format_price/1 backwards-compatible" do
      assert Helpers.format_price("US", 10.0) == "U$D 10.00"
      assert Helpers.format_price(Decimal.new("10.50")) == "R$ 10,50"
    end
  end

  describe "humanize_token/1" do
    test "humanizes strings and atoms" do
      assert Helpers.humanize_token("legal_entity") == "Legal entity"
      assert Helpers.humanize_token(:market_close) == "Market close"
    end
  end

  describe "blank?/1" do
    test "returns true for nil/blank strings" do
      assert Helpers.blank?(nil)
      assert Helpers.blank?("")
      assert Helpers.blank?("   ")
      refute Helpers.blank?("text")
    end
  end

  describe "normalize_to_upper/1" do
    test "uppercases and trims binary values" do
      assert Helpers.normalize_to_upper(" usd ") == "USD"
      assert Helpers.normalize_to_upper("brl") == "BRL"
      assert Helpers.normalize_to_upper(nil) == nil
    end
  end

  describe "normalize_string/2" do
    test "normalizes unicode, removes invisible chars, and preserves case by default" do
      assert Helpers.normalize_string("  UBER\u200B\n Eats  ") == "UBER Eats"
    end

    test "supports explicit lowercase and uppercase normalization" do
      assert Helpers.normalize_string("  UBER\u200B\n Eats  ", case: :lower) == "uber eats"
      assert Helpers.normalize_string(" usd ", case: :upper) == "USD"
      assert Helpers.normalize_string(nil, case: :upper) == nil
    end
  end

  describe "map_get/2" do
    test "supports atom/string keys" do
      assert Helpers.map_get(%{name: "John"}, "name") == "John"
      assert Helpers.map_get(%{"name" => "Jane"}, :name) == "Jane"
    end
  end

  describe "generate_urlsafe_token/1" do
    test "generates url-safe non-empty token" do
      token = Helpers.generate_urlsafe_token(7)
      assert is_binary(token)
      assert token != ""
      assert String.match?(token, ~r/^[A-Za-z0-9\-_]+$/)
    end
  end
end
