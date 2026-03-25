defmodule AurumFinance.Fx.CsvImportTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Fx.CsvImport
  alias AurumFinance.Fx.FxSeries

  describe "import/2" do
    test "updates series from_date only when imported data is older" do
      series = insert_csv_series(~D[2026-03-25])

      first_rows = [
        %{date: ~D[2026-03-25], value: Decimal.new("5.7000")},
        %{date: ~D[2026-03-24], value: Decimal.new("5.6800")},
        %{date: ~D[2026-03-23], value: Decimal.new("5.6900")},
        %{date: ~D[2026-03-22], value: Decimal.new("5.6600")},
        %{date: ~D[2026-03-21], value: Decimal.new("5.6400")},
        %{date: ~D[2026-03-20], value: Decimal.new("5.6200")},
        %{date: ~D[2026-03-19], value: Decimal.new("5.6100")}
      ]

      assert {:ok, %{inserted: 7, updated: 0}} = CsvImport.import(series, first_rows)
      assert Repo.get!(FxSeries, series.id).from_date == ~D[2026-03-19]

      second_rows = [%{date: ~D[2026-02-20], value: Decimal.new("5.5500")}]

      assert {:ok, %{inserted: 1, updated: 0}} = CsvImport.import(series, second_rows)
      assert Repo.get!(FxSeries, series.id).from_date == ~D[2026-02-20]

      third_rows = [%{date: ~D[2026-03-24], value: Decimal.new("5.6810")}]

      assert {:ok, %{inserted: 0, updated: 1}} = CsvImport.import(series, third_rows)
      assert Repo.get!(FxSeries, series.id).from_date == ~D[2026-02-20]
    end
  end

  defp insert_csv_series(from_date) do
    Repo.insert!(%FxSeries{
      id: Ecto.UUID.generate(),
      name: "CSV Import Test",
      slug: "csv-import-test-#{System.unique_integer([:positive])}",
      base_currency_code: "USD",
      quote_currency_code: "BRL",
      from_date: from_date,
      source_kind: :csv_upload,
      inserted_at: now(),
      updated_at: now()
    })
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
