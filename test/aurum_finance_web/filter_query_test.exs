defmodule AurumFinanceWeb.FilterQueryTest do
  use ExUnit.Case, async: true

  alias AurumFinanceWeb.FilterQuery

  describe "decode/1" do
    test "returns an empty map for nil and empty input" do
      assert FilterQuery.decode(nil) == %{}
      assert FilterQuery.decode("") == %{}
    end

    test "decodes a single clause" do
      assert FilterQuery.decode("q=entity:123") == %{"entity" => "123"}
    end

    test "decodes multiple clauses" do
      assert FilterQuery.decode("q=entity:123&source:manual&voided:true") == %{
               "entity" => "123",
               "source" => "manual",
               "voided" => "true"
             }
    end

    test "ignores malformed clauses" do
      assert FilterQuery.decode("q=entity:123&broken&empty:&:missing_key") == %{
               "entity" => "123"
             }
    end

    test "decodes URI-encoded payloads" do
      assert FilterQuery.decode("q=description%3Aweekly%20groceries%26source%3Amanual") == %{
               "description" => "weekly groceries",
               "source" => "manual"
             }
    end
  end

  describe "encode/1" do
    test "returns nil for an empty list or when all values are skipped" do
      assert FilterQuery.encode([]) == nil
      assert FilterQuery.encode(entity: nil, source: false, account: "") == nil
    end

    test "encodes only surviving clauses" do
      assert FilterQuery.encode(entity: "123", source: nil, voided: "true") ==
               "?q=entity:123&voided:true"
    end

    test "supports string keys" do
      assert FilterQuery.encode([{"entity", "123"}, {"account", "456"}]) ==
               "?q=entity:123&account:456"
    end
  end

  describe "build_path/2" do
    test "returns the base path when no clauses survive" do
      assert FilterQuery.build_path("/transactions", entity: nil, source: "") == "/transactions"
    end

    test "appends the encoded query string when clauses survive" do
      assert FilterQuery.build_path("/transactions", entity: "123", source: "manual") ==
               "/transactions?q=entity:123&source:manual"
    end
  end

  describe "skip_default/2" do
    test "returns nil when the value matches the default" do
      assert FilterQuery.skip_default("all", "all") == nil
    end

    test "returns the original value when it differs from the default" do
      assert FilterQuery.skip_default("this_month", "all") == "this_month"
    end
  end

  describe "round-trip" do
    test "encode then decode preserves the original key/value pairs" do
      clauses = [entity: "123", account: "456", source: "manual", voided: "true"]

      assert clauses |> FilterQuery.encode() |> String.trim_leading("?") |> FilterQuery.decode() ==
               %{
                 "entity" => "123",
                 "account" => "456",
                 "source" => "manual",
                 "voided" => "true"
               }
    end
  end
end
