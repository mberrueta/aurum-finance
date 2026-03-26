defmodule AurumFinance.Reporting.SavedAccountReportsTest do
  use AurumFinance.DataCase, async: true

  doctest AurumFinance.Reporting.SavedAccountReports
  doctest AurumFinance.Reporting.SavedAccountReport

  import AurumFinance.ReportingTestHelpers

  alias AurumFinance.Fx
  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.SavedAccountReport

  describe "list_saved_account_reports/1" do
    test "sorts by derived label and allows duplicate definitions" do
      entity_a = insert(:entity, name: "Alpha")
      entity_b = insert(:entity, name: "Beta")

      account_a = insert_account(entity_b, name: "Zulu")
      account_b = insert_account(entity_a, name: "Alpha")

      {:ok, first} = Reporting.create_saved_account_report(%{account_id: account_a.id})
      {:ok, second} = Reporting.create_saved_account_report(%{account_id: account_b.id})
      {:ok, duplicate} = Reporting.create_saved_account_report(%{account_id: account_a.id})

      labels =
        Reporting.list_saved_account_reports()
        |> Enum.map(&Reporting.saved_account_report_label/1)

      assert labels == ["Alpha · Alpha", "Beta · Zulu", "Beta · Zulu"]
      assert first.id != duplicate.id
      assert second.id != first.id
    end
  end

  describe "change_saved_account_report/2" do
    test "rejects partial conversion and same-currency conversion" do
      entity = insert(:entity, name: "Alpha")
      account = insert_account(entity, name: "Checking", currency_code: "USD")

      partial =
        Reporting.change_saved_account_report(%SavedAccountReport{}, %{
          account_id: account.id,
          convert: true,
          target_currency_code: "EUR"
        })

      assert "This field is required." in errors_on(partial).fx_series_id

      series =
        insert_fx_series(%{
          name: "USD/EUR Daily",
          base_currency_code: "USD",
          quote_currency_code: "EUR",
          from_date: ~D[2026-03-01],
          source_kind: :csv_upload
        })

      same_currency =
        Reporting.change_saved_account_report(%SavedAccountReport{}, %{
          account_id: account.id,
          convert: true,
          target_currency_code: "USD",
          fx_series_id: series.id
        })

      assert "Target currency must be different from the account currency" in errors_on(
               same_currency
             ).target_currency_code
    end
  end

  describe "preview_saved_account_report/1" do
    test "renders converted and unavailable states at read time" do
      entity = insert(:entity, name: "Alpha")
      account = insert_account(entity, name: "Checking", currency_code: "USD")

      insert_snapshot!(account, ~D[2026-03-10], "10.0000", "1.0000")

      series =
        insert_fx_series(%{
          name: "USD/EUR Daily",
          base_currency_code: "USD",
          quote_currency_code: "EUR",
          from_date: ~D[2026-03-01],
          source_kind: :csv_upload
        })

      :ok = insert_rate!(series, ~D[2026-03-10], "0.25")

      {:ok, converted} =
        Reporting.create_saved_account_report(%{
          account_id: account.id,
          convert: true,
          target_currency_code: "EUR",
          fx_series_id: series.id,
          pinned_as_of_date: ~D[2026-03-10]
        })

      assert {:ok, %{report: report, live?: false, effective_as_of_date: ~D[2026-03-10]}} =
               Reporting.preview_saved_account_report(converted)

      assert report.conversion_status == :converted
      assert report.converted_amount == Decimal.new("2.5000000000000000")
      assert report.fx_series_slug == "usdeur-daily"

      {:ok, unavailable} =
        Reporting.create_saved_account_report(%{
          account_id: account.id,
          convert: true,
          target_currency_code: "EUR",
          fx_series_id: series.id,
          pinned_as_of_date: ~D[2026-03-20]
        })

      assert {:ok, %{report: unavailable_report}} =
               Reporting.preview_saved_account_report(unavailable)

      assert unavailable_report.conversion_status == :unavailable
      assert unavailable_report.conversion_message =~ "No FX rate found within 4 days"
    end
  end

  defp insert_fx_series(attrs) do
    params =
      %{
        name: "FX Series",
        base_currency_code: "USD",
        quote_currency_code: "BRL",
        from_date: ~D[2026-03-01],
        source_kind: :csv_upload
      }
      |> Map.merge(attrs)

    {:ok, series} = Fx.create_fx_series(params)
    series
  end

  defp insert_rate!(series, date, rate) do
    assert {:ok, 1} =
             Fx.upsert_rate_records(series.id, [
               %{date: date, value: Decimal.new(rate)}
             ])

    :ok
  end
end
