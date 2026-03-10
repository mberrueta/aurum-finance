defmodule AurumFinance.Ingestion.RowNormalizerTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Ingestion.CanonicalRowCandidate
  alias AurumFinance.Ingestion.RowNormalizer
  alias AurumFinance.Ledger.Account

  doctest RowNormalizer

  describe "normalize_rows/1" do
    test "returns a lazy stream that can normalize large row sets incrementally" do
      rows = [
        %CanonicalRowCandidate{
          row_index: 1,
          raw_data: %{"Description" => " Uber "},
          canonical_data: %{description: " Uber "}
        },
        %CanonicalRowCandidate{
          row_index: 2,
          raw_data: %{"Description" => " UBER"},
          canonical_data: %{description: " UBER"}
        }
      ]

      normalized_rows =
        rows
        |> RowNormalizer.normalize_rows()
        |> Enum.to_list()

      assert Enum.map(normalized_rows, & &1.canonical_data.description) == ["uber", "uber"]
    end

    test "can derive currency from account context while normalizing rows" do
      rows = [
        %CanonicalRowCandidate{
          row_index: 1,
          raw_data: %{"Description" => "Uber $10"},
          canonical_data: %{description: "Uber $10", currency: nil}
        }
      ]

      account = %Account{currency_code: "brl"}

      [normalized_row] =
        rows
        |> RowNormalizer.normalize_rows(account: account)
        |> Enum.to_list()

      assert normalized_row.canonical_data == %{description: "uber $10", currency: "BRL"}
    end

    test "normalizes description variants consistently" do
      values = ["Uber ", " UBER", "uber"]

      normalized_values =
        Enum.map(values, fn value ->
          [
            %CanonicalRowCandidate{
              row_index: 1,
              raw_data: %{"Description" => value},
              canonical_data: %{description: value}
            }
          ]
          |> RowNormalizer.normalize_rows()
          |> Enum.to_list()
          |> hd()
          |> then(& &1.canonical_data.description)
        end)

      assert Enum.uniq(normalized_values) == ["uber"]
    end

    test "removes invisible and non-printable characters while collapsing whitespace" do
      rows = [
        %CanonicalRowCandidate{
          row_index: 1,
          raw_data: %{},
          canonical_data: %{
            description: "  Uber\u200B\t\n  Eats\u0000  ",
            amount: "  -4.50 \n",
            currency: " usd\u200B "
          }
        }
      ]

      [normalized] =
        rows
        |> RowNormalizer.normalize_rows()
        |> Enum.to_list()

      assert normalized.canonical_data == %{
               description: "uber eats",
               amount: "-4.50",
               currency: "USD"
             }
    end

    test "applies unicode normalization consistently" do
      decomposed = "Cafe\u0301"
      precomposed = "Caf\u00E9"

      [first_row] =
        [
          %CanonicalRowCandidate{
            row_index: 1,
            raw_data: %{},
            canonical_data: %{description: decomposed}
          }
        ]
        |> RowNormalizer.normalize_rows()
        |> Enum.to_list()

      [second_row] =
        [
          %CanonicalRowCandidate{
            row_index: 1,
            raw_data: %{},
            canonical_data: %{description: precomposed}
          }
        ]
        |> RowNormalizer.normalize_rows()
        |> Enum.to_list()

      assert first_row.canonical_data.description == second_row.canonical_data.description
      assert first_row.canonical_data.description == "café"
    end

    test "normalizes an entire chunk of rows and returns the normalized chunk content" do
      rows = [
        %CanonicalRowCandidate{
          row_index: 1,
          raw_data: %{"Description" => " Uber "},
          canonical_data: %{description: " Uber "}
        },
        %CanonicalRowCandidate{
          row_index: 2,
          raw_data: %{"Currency" => " usd "},
          canonical_data: %{currency: " usd "}
        }
      ]

      normalized_rows =
        rows
        |> RowNormalizer.normalize_rows()
        |> Enum.to_list()

      assert Enum.map(normalized_rows, & &1.canonical_data) == [
               %{description: "uber"},
               %{currency: "USD"}
             ]
    end
  end
end
