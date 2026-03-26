defmodule AurumFinanceWeb.ReportsLiveTest do
  use AurumFinanceWeb.ConnCase, async: false
  use Oban.Testing, repo: AurumFinance.Repo

  import AurumFinance.ReportingTestHelpers
  import Phoenix.LiveViewTest
  alias AurumFinance.Reporting

  defmodule FailingReporting do
    def net_worth_report(_entity_ids, _opts \\ []), do: {:error, :db_down}
    def subscribe_hub_freshness, do: :ok
    def enqueue_hub_refresh(_entity_ids), do: {:ok, %{status: :queued}}
  end

  defmodule CountingReporting do
    def net_worth_report(_entity_ids, _opts \\ []) do
      if test_pid = Application.get_env(:aurum_finance, :reporting_test_pid) do
        send(test_pid, :hub_net_worth_report_called)
      end

      {:ok,
       %{
         as_of_date: Date.utc_today(),
         freshness_status: :up_to_date,
         refresh_suggested?: false,
         empty?: true,
         included_account_count: 0,
         entity_count: 0,
         show_entity_column?: false,
         coverage_counts: %{exact: 0, carried_forward: 0, refreshable_gap: 0, no_history: 0},
         currency_summaries: [],
         account_rows: []
       }}
    end

    def subscribe_hub_freshness, do: :ok
    def enqueue_hub_refresh(_entity_ids), do: {:ok, %{status: :queued}}
  end

  test "renders the reporting dashboard with built-in and saved report areas", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    checking = insert_account(entity, name: "Checking")

    insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "10.0000")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    assert has_element?(view, "#reports-page")
    assert has_element?(view, "#reports-freshness-badge")
    assert has_element?(view, "#reports-guidance-info")
    assert has_element?(view, "#reports-net-worth-card")
    assert has_element?(view, "#reports-net-worth-title[href=\"/reports/net-worth\"]")
    assert has_element?(view, "#reports-saved-account-reports-panel")
    assert has_element?(view, "#saved-account-reports-empty")
    assert has_element?(view, "#reports-new-saved-report[href=\"/reports/account-reports/new\"]")
    assert has_element?(view, "#reports-refresh-submit")
    assert has_element?(view, "#reports-guidance-tip")
    assert has_element?(view, "#reports-guidance-warning")

    html = render(view)

    assert elem(:binary.match(html, "reports-guidance"), 0) <
             elem(:binary.match(html, "reports-net-worth-card"), 0)

    assert elem(:binary.match(html, "reports-net-worth-card"), 0) <
             elem(:binary.match(html, "reports-guidance-bottom"), 0)

    assert html =~ "Net Worth"
    assert html =~ "Saved account reports"
    assert html =~ "No saved account reports yet."
    assert html =~ "Why this page exists"
    assert html =~ "As of #{Date.to_iso8601(Date.utc_today())}"
    assert html =~ "1 accounts"
    assert html =~ "USD"

    refute has_element?(view, "#reports-rebuild-form")
    refute html =~ "Cashflow (month)"
    refute html =~ "Portfolio allocation"
  end

  test "renders saved account report cards in label order", %{conn: conn} do
    alpha = insert(:entity, name: "Alpha")
    beta = insert(:entity, name: "Beta")

    beta_account = insert_account(beta, name: "Zulu")
    alpha_account = insert_account(alpha, name: "Alpha")

    {:ok, beta_report} = Reporting.create_saved_account_report(%{account_id: beta_account.id})
    {:ok, alpha_report} = Reporting.create_saved_account_report(%{account_id: alpha_account.id})

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    assert has_element?(
             view,
             "#saved-account-report-title-#{alpha_report.id}[href=\"/reports/account-reports/#{alpha_report.id}\"]"
           )

    assert has_element?(
             view,
             "#saved-account-report-title-#{beta_report.id}[href=\"/reports/account-reports/#{beta_report.id}\"]"
           )

    html = render(view)
    alpha_label = Reporting.saved_account_report_label(alpha_report)
    beta_label = Reporting.saved_account_report_label(beta_report)

    assert elem(:binary.match(html, alpha_label), 0) < elem(:binary.match(html, beta_label), 0)
  end

  test "refresh action enqueues reporting jobs for included accounts", %{conn: conn} do
    entity = insert(:entity)
    asset = insert_account(entity, name: "Checking")

    liability =
      insert_account(entity,
        name: "Card",
        account_type: :liability,
        operational_subtype: :credit_card
      )

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    view
    |> element("#reports-refresh-submit")
    |> render_click()

    assert_enqueued(
      worker: AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker,
      queue: :reporting,
      args: %{"account_id" => asset.id, "from_date" => "__first_effective_date__"}
    )

    assert_enqueued(
      worker: AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker,
      queue: :reporting,
      args: %{"account_id" => liability.id, "from_date" => "__first_effective_date__"}
    )

    assert has_element?(view, "[role=alert]")
    assert has_element?(view, "#reports-refresh-pending")
  end

  test "refresh signal updates the coarse freshness badge after snapshots catch up", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    checking = insert_account(entity, name: "Checking")

    expense =
      insert_account(entity,
        name: "Groceries",
        account_type: :expense,
        management_group: :category,
        operational_subtype: nil,
        institution_name: nil,
        institution_account_ref: nil
      )

    insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "10.0000", ~U[2026-03-10 09:00:00Z])

    create_transaction!(entity, ~D[2026-03-10], [
      %{account_id: checking.id, amount: Decimal.new("-20.0000")},
      %{account_id: expense.id, amount: Decimal.new("20.0000")}
    ])

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    assert render(view) =~ "Outdated"

    assert {:ok, _result} = Reporting.refresh_daily_balance_snapshots(checking, nil)

    send(view.pid, {:reporting_hub_freshness_refreshed, %{account_id: checking.id}})
    send(view.pid, :refresh_hub)

    assert has_element?(view, "#reports-freshness-badge")
    assert render(view) =~ "Up to date"
  end

  test "keeps the LiveView alive when the hub report load fails", %{conn: conn} do
    previous_reporting_module = Application.get_env(:aurum_finance, :reporting_module)
    Application.put_env(:aurum_finance, :reporting_module, FailingReporting)

    on_exit(fn ->
      if previous_reporting_module do
        Application.put_env(:aurum_finance, :reporting_module, previous_reporting_module)
      else
        Application.delete_env(:aurum_finance, :reporting_module)
      end
    end)

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    assert has_element?(view, "#reports-page")
    assert has_element?(view, "#reports-net-worth-empty")
    assert has_element?(view, "#reports-freshness-badge", "Unavailable")
    assert has_element?(view, "[role=alert]")
    assert render(view) =~ "Unavailable"
  end

  test "debounces bursts of freshness events into one hub reload", %{conn: conn} do
    previous_reporting_module = Application.get_env(:aurum_finance, :reporting_module)
    previous_test_pid = Application.get_env(:aurum_finance, :reporting_test_pid)
    Application.put_env(:aurum_finance, :reporting_module, CountingReporting)
    Application.put_env(:aurum_finance, :reporting_test_pid, self())

    on_exit(fn ->
      if previous_reporting_module do
        Application.put_env(:aurum_finance, :reporting_module, previous_reporting_module)
      else
        Application.delete_env(:aurum_finance, :reporting_module)
      end

      if previous_test_pid do
        Application.put_env(:aurum_finance, :reporting_test_pid, previous_test_pid)
      else
        Application.delete_env(:aurum_finance, :reporting_test_pid)
      end
    end)

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")
    flush_hub_report_calls()

    send(view.pid, {:reporting_hub_freshness_invalidated, %{}})
    send(view.pid, {:reporting_hub_freshness_refreshed, %{}})
    send(view.pid, {:reporting_hub_freshness_invalidated, %{}})

    assert_receive :hub_net_worth_report_called, 250
    refute_receive :hub_net_worth_report_called, 150
  end

  defp flush_hub_report_calls do
    receive do
      :hub_net_worth_report_called -> flush_hub_report_calls()
    after
      0 -> :ok
    end
  end
end
