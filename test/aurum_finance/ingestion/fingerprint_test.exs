defmodule AurumFinance.Ingestion.FingerprintTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Ingestion.Fingerprint

  doctest Fingerprint

  describe "build/1" do
    test "builds the same fingerprint for equivalent normalized maps regardless of key order" do
      first =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-10],
          amount: Decimal.new("-4.50"),
          currency: "USD",
          description: "coffee"
        })

      second =
        Fingerprint.build(%{
          description: "coffee",
          currency: "USD",
          amount: Decimal.new("-4.50"),
          posted_on: ~D[2026-03-10]
        })

      assert first == second
    end

    test "changes when normalized canonical values change" do
      first =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-10],
          amount: Decimal.new("-4.50"),
          currency: "USD",
          description: "coffee"
        })

      second =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-10],
          amount: Decimal.new("-5.00"),
          currency: "USD",
          description: "coffee"
        })

      refute first == second
    end
  end
end
