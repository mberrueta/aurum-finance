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

  test "renders the reporting hub with a coarse freshness badge and net worth card", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    checking = insert_account(entity, name: "Checking")

    insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "10.0000")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    assert has_element?(view, "#reports-page")
    assert has_element?(view, "#reports-hub-overview")
    assert has_element?(view, "#reports-freshness-badge")
    assert has_element?(view, "#reports-net-worth-card")
    assert has_element?(view, "#reports-net-worth-summary")
    assert has_element?(view, "#reports-net-worth-open[href=\"/reports/net-worth\"]")
    assert has_element?(view, "#reports-refresh-submit")

    html = render(view)

    assert html =~ "Net Worth"
    assert html =~ "Open report"
    assert html =~ "As of #{Date.to_iso8601(Date.utc_today())}"
    assert html =~ "1 accounts"
    assert html =~ "USD"

    refute has_element?(view, "#reports-rebuild-form")
    refute html =~ "Cashflow (month)"
    refute html =~ "Portfolio allocation"
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
