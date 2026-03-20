defmodule AurumFinanceWeb.ReportsLiveTest do
  use AurumFinanceWeb.ConnCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  import Phoenix.LiveViewTest

  alias AurumFinance.Ledger
  alias AurumFinance.Repo
  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.DailyBalanceSnapshot

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

    refute has_element?(view, "#reports-rebuild-form")
    refute render(view) =~ "Cashflow (month)"
    refute render(view) =~ "Portfolio allocation"
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

    assert has_element?(view, "#reports-freshness-badge")
    assert render(view) =~ "Up to date"
  end

  defp insert_snapshot!(account, snapshot_date, closing_balance, daily_delta, computed_at \\ nil) do
    computed_at = computed_at || DateTime.utc_now() |> DateTime.truncate(:microsecond)

    %DailyBalanceSnapshot{}
    |> DailyBalanceSnapshot.changeset(%{
      account_id: account.id,
      entity_id: account.entity_id,
      snapshot_date: snapshot_date,
      closing_balance: Decimal.new(closing_balance),
      daily_delta: Decimal.new(daily_delta),
      computed_at: computed_at,
      projection_version: 1
    })
    |> Repo.insert!()
  end

  defp create_transaction!(entity, date, postings) do
    {:ok, transaction} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: date,
        description: "Reports hub test transaction",
        source_type: :manual,
        postings: postings
      })

    transaction
  end
end
