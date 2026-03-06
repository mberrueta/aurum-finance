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

  describe "map_get/2" do
    test "supports atom/string keys" do
      assert Helpers.map_get(%{name: "John"}, "name") == "John"
      assert Helpers.map_get(%{"name" => "Jane"}, :name) == "Jane"
    end
  end
end
