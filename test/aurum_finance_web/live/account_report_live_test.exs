defmodule AurumFinanceWeb.AccountReportLiveTest do
  use AurumFinanceWeb.ConnCase, async: false

  import AurumFinance.ReportingTestHelpers
  import Phoenix.LiveViewTest

  alias AurumFinance.Fx
  alias AurumFinance.Reporting

  test "renders the form with conversion disabled by default", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    account = insert_account(entity, name: "Checking")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/account-report")

    assert has_element?(view, "#account-report-page")
    assert has_element?(view, "#app-breadcrumb-0[href=\"/reports\"]", "Reports")
    assert has_element?(view, "#account-report-form")
    assert has_element?(view, "#account-report-account-id option[value=\"#{account.id}\"]")
    assert has_element?(view, "#account-report-as-of-date")
    assert has_element?(view, "#account-report-convert-toggle")
    assert has_element?(view, "#account-report-submit")
    assert has_element?(view, "#account-report-guidance-info")
    assert has_element?(view, "#account-report-guidance-tip")
    assert has_element?(view, "#account-report-guidance-warning")
    assert has_element?(view, "#account-report-guidance-info a[href=\"/fx\"]", "Open FX series")
    refute has_element?(view, "#account-report-conversion-fields")
    assert has_element?(view, "#account-report-result")
    assert has_element?(view, "#account-report-preview .au-empty")
  end

  test "shows compatible FX series and empty states as the filters change", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    account = insert_account(entity, name: "USD Checking", currency_code: "USD")

    series =
      insert_fx_series(%{
        name: "USD/EUR Daily",
        base_currency_code: "USD",
        quote_currency_code: "EUR",
        from_date: ~D[2026-03-01],
        source_kind: :csv_upload
      })

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/account-report")

    view
    |> element("#account-report-form")
    |> render_change(%{
      "_target" => ["saved_account_report", "account_id"],
      "saved_account_report" => %{
        "account_id" => account.id,
        "pinned_as_of_date" => "2026-03-10",
        "convert" => "true"
      }
    })

    assert has_element?(view, "#account-report-conversion-fields")
    assert has_element?(view, "#account-report-target-currency option[value=\"EUR\"]")

    view
    |> element("#account-report-form")
    |> render_change(%{
      "_target" => ["saved_account_report", "target_currency_code"],
      "saved_account_report" => %{
        "account_id" => account.id,
        "pinned_as_of_date" => "2026-03-10",
        "convert" => "true",
        "target_currency_code" => "EUR"
      }
    })

    assert has_element?(view, "#account-report-fx-series option[value=\"#{series.id}\"]")
    refute has_element?(view, "#account-report-compatible-empty")

    view
    |> element("#account-report-form")
    |> render_change(%{
      "_target" => ["saved_account_report", "target_currency_code"],
      "saved_account_report" => %{
        "account_id" => account.id,
        "pinned_as_of_date" => "2026-03-10",
        "convert" => "true",
        "target_currency_code" => "JPY"
      }
    })

    assert has_element?(view, "#account-report-compatible-empty")
    refute has_element?(view, "#account-report-fx-series option[value=\"#{series.id}\"]")
  end

  test "renders a converted report with the selected FX series and rate date", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    account = insert_account(entity, name: "USD Checking", currency_code: "USD")

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

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/account-report")

    params = %{
      "account_id" => account.id,
      "pinned_as_of_date" => "2026-03-10",
      "convert" => "true",
      "target_currency_code" => "EUR",
      "fx_series_id" => series.id
    }

    view
    |> element("#account-report-form")
    |> render_change(%{
      "saved_account_report" => %{
        "account_id" => account.id,
        "pinned_as_of_date" => "2026-03-10",
        "convert" => "true"
      }
    })

    view
    |> element("#account-report-form")
    |> render_change(%{"saved_account_report" => params})

    assert has_element?(view, "#account-report-result")
    assert has_element?(view, "#account-report-converted-amount")
    assert has_element?(view, "#account-report-rate-date")
    assert has_element?(view, "#account-report-series-reference")
    refute has_element?(view, "#account-report-native-amount")
    refute has_element?(view, "#account-report-target-currency-value")
  end

  test "renders the unavailable conversion state when no rate exists inside the lookup window",
       %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    account = insert_account(entity, name: "USD Savings", currency_code: "USD")

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

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/account-report")

    params = %{
      "account_id" => account.id,
      "pinned_as_of_date" => "2026-03-10",
      "convert" => "true",
      "target_currency_code" => "EUR",
      "fx_series_id" => series.id
    }

    view
    |> element("#account-report-form")
    |> render_change(%{
      "saved_account_report" => %{
        "account_id" => account.id,
        "pinned_as_of_date" => "2026-03-10",
        "convert" => "true"
      }
    })

    view
    |> element("#account-report-form")
    |> render_change(%{"saved_account_report" => params})

    assert has_element?(view, "#account-report-result")
    assert has_element?(view, "#account-report-native-amount")
    assert has_element?(view, "#account-report-converted-amount")
    assert has_element?(view, "#account-report-unavailable-banner")

    assert has_element?(
             view,
             "#account-report-unavailable-message",
             "No FX rate found within 4 days"
           )
  end

  test "rejects a target currency that matches the account currency", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    account = insert_account(entity, name: "USD Checking", currency_code: "USD")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/account-report")

    params = %{
      "account_id" => account.id,
      "pinned_as_of_date" => "2026-03-10",
      "convert" => "true",
      "target_currency_code" => "USD"
    }

    view
    |> element("#account-report-form")
    |> render_change(%{
      "saved_account_report" => %{
        "account_id" => account.id,
        "as_of_date" => "2026-03-10",
        "convert" => "true"
      }
    })

    view
    |> element("#account-report-form")
    |> render_change(%{"saved_account_report" => params})
  end

  test "creates a saved account report and opens the edit page", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    account = insert_account(entity, name: "Checking")

    conn = log_in_root(conn)
    {:ok, view, _html} = live(conn, "/reports/account-reports/new")

    params = %{
      "account_id" => account.id,
      "convert" => "false"
    }

    view
    |> form("#account-report-form", saved_account_report: params)
    |> render_submit()

    report = Reporting.list_saved_account_reports() |> List.first()

    assert report
    assert_redirect(view, ~p"/reports/account-reports/#{report.id}")

    {:ok, edit_view, _html} = live(conn, ~p"/reports/account-reports/#{report.id}")

    assert has_element?(edit_view, "#account-report-page")
    assert has_element?(edit_view, "#account-report-delete-submit")
    assert has_element?(edit_view, "#account-report-back-link[href=\"/reports\"]")
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
