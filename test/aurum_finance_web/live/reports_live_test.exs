defmodule AurumFinanceWeb.ReportsLiveTest do
  use AurumFinanceWeb.ConnCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  import Phoenix.LiveViewTest

  alias AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker

  test "renders the technical rebuild control", %{conn: conn} do
    account = insert(:account, name: "Operating")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    assert has_element?(view, "#reports-page")
    assert has_element?(view, "#reports-rebuild-panel")
    assert has_element?(view, "#reports-rebuild-form")
    assert has_element?(view, "#reports-rebuild-account-id option[value=\"#{account.id}\"]")
    assert has_element?(view, "#reports-rebuild-from-date")
    assert has_element?(view, "#reports-rebuild-preset-last_month")
    assert has_element?(view, "#reports-rebuild-preset-current_year")
    assert has_element?(view, "#reports-rebuild-preset-one_year_ago")
    assert has_element?(view, "#reports-rebuild-submit")
  end

  test "submits a manual rebuild request and enqueues the reporting job", %{conn: conn} do
    account = insert(:account)

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    view
    |> form("#reports-rebuild-form",
      snapshot_rebuild: %{
        "account_id" => account.id,
        "from_date" => "2026-03-12"
      }
    )
    |> render_submit()

    assert_enqueued(
      worker: DailyBalanceSnapshotRefreshWorker,
      queue: :reporting,
      args: %{"account_id" => account.id, "from_date" => "2026-03-12"}
    )

    assert has_element?(view, "[role=alert]")
  end

  test "shows validation feedback for an invalid rebuild request", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    view
    |> form("#reports-rebuild-form",
      snapshot_rebuild: %{
        "account_id" => "",
        "from_date" => "not-a-date"
      }
    )
    |> render_submit()

    refute_enqueued(worker: DailyBalanceSnapshotRefreshWorker, queue: :reporting)
    assert has_element?(view, "[role=alert]")
    assert has_element?(view, "#reports-rebuild-form")
  end

  test "date presets populate the from date field", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_root() |> live("/reports")

    view
    |> element("#reports-rebuild-preset-current_year")
    |> render_click()

    today = Date.utc_today()
    current_year_start = %{today | month: 1, day: 1} |> Date.to_iso8601()

    assert has_element?(view, "#reports-rebuild-from-date[value=\"#{current_year_start}\"]")
  end
end
