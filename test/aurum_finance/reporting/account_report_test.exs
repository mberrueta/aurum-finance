defmodule AurumFinance.Reporting.AccountReportTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.ReportingTestHelpers

  alias AurumFinance.Fx
  alias AurumFinance.Reporting

  describe "account_report/2" do
    test "returns the native account report when conversion is not requested" do
      entity = insert(:entity)
      account = insert_account(entity, name: "Checking")

      insert_snapshot!(account, ~D[2026-03-10], "100.0000", "5.0000")

      assert {:ok, report} =
               Reporting.account_report(account.id, as_of_date: ~D[2026-03-10])

      assert report.account_id == account.id
      assert report.account_name == "Checking"
      assert report.as_of_date == ~D[2026-03-10]
      assert report.native_currency_code == "USD"
      assert report.native_amount == Decimal.new("100.0000")
      assert report.ledger_balance == Decimal.new("100.0000")
      assert report.snapshot_date_used == ~D[2026-03-10]
      assert report.conversion_status == :not_requested
      assert report.conversion_message == nil
      assert report.converted_amount == nil
      assert report.converted_currency_code == nil
      assert report.fx_series_id == nil
    end

    test "converts using an inverted compatible series" do
      entity = insert(:entity)
      account = insert_account(entity, name: "USD Cash")

      insert_snapshot!(account, ~D[2026-03-10], "10.0000", "1.0000")

      series =
        insert_fx_series(%{
          name: "BRL/USD Daily",
          base_currency_code: "BRL",
          quote_currency_code: "USD",
          from_date: ~D[2026-03-01],
          source_kind: :csv_upload
        })

      :ok = insert_rate!(series, ~D[2026-03-10], "0.25")

      assert {:ok, report} =
               Reporting.account_report(
                 account.id,
                 as_of_date: ~D[2026-03-10],
                 target_currency_code: "brl",
                 fx_series_id: series.id
               )

      assert report.conversion_status == :converted
      assert report.target_currency_code == "BRL"
      assert report.converted_currency_code == "BRL"
      assert report.converted_amount == Decimal.new("40.0000")
      assert report.fx_series_id == series.id
      assert report.fx_series_slug == series.slug
      assert report.fx_series_name == series.name
      assert report.fx_series_base_currency_code == "BRL"
      assert report.fx_series_quote_currency_code == "USD"
      assert report.fx_series_inverted? == true
      assert report.fx_rate_effective_date == ~D[2026-03-10]
      assert report.fx_rate_value == Decimal.new("4")
    end

    test "returns a non-failing unavailable conversion when the lookup window has no rate" do
      entity = insert(:entity)
      account = insert_account(entity, name: "USD Savings")

      insert_snapshot!(account, ~D[2026-03-10], "100.0000", "1.0000")

      series =
        insert_fx_series(%{
          name: "USD/EUR Daily",
          base_currency_code: "USD",
          quote_currency_code: "EUR",
          from_date: ~D[2026-03-01],
          source_kind: :csv_upload
        })

      :ok = insert_rate!(series, ~D[2026-03-05], "0.9100")

      assert {:ok, report} =
               Reporting.account_report(
                 account.id,
                 as_of_date: ~D[2026-03-10],
                 target_currency_code: "EUR",
                 fx_series_id: series.id
               )

      assert report.native_amount == Decimal.new("100.0000")
      assert report.conversion_status == :unavailable
      assert report.conversion_message == "No FX rate found within 4 days"
      assert report.converted_amount == nil
      assert report.converted_currency_code == "EUR"
      assert report.fx_series_id == series.id
      assert report.fx_series_slug == series.slug
      assert report.fx_series_name == series.name
      assert report.fx_series_inverted? == false
      assert report.fx_rate_effective_date == nil
      assert report.fx_rate_value == nil
    end

    test "rejects an incompatible FX series selection with form-usable errors" do
      entity = insert(:entity)
      account = insert_account(entity, name: "USD Checking")

      insert_snapshot!(account, ~D[2026-03-10], "100.0000", "1.0000")

      incompatible_series =
        insert_fx_series(%{
          name: "USD/EUR Daily",
          base_currency_code: "USD",
          quote_currency_code: "EUR",
          from_date: ~D[2026-03-01],
          source_kind: :csv_upload
        })

      assert {:error, changeset} =
               Reporting.account_report(
                 account.id,
                 as_of_date: ~D[2026-03-10],
                 target_currency_code: "BRL",
                 fx_series_id: incompatible_series.id
               )

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).fx_series_id
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
