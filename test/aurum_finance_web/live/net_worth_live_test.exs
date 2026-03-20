defmodule AurumFinanceWeb.NetWorthLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Ledger
  alias AurumFinance.Repo
  alias AurumFinance.Reporting.DailyBalanceSnapshot

  test "loads with Date.utc_today default and renders summary plus accounts table", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    checking = insert_account(entity, name: "Checking")
    last_year_end = Date.new!(Date.utc_today().year - 1, 12, 31)

    insert_snapshot!(checking, Date.utc_today(), "1250.0000", "25.0000")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/net-worth")

    assert has_element?(view, "#net-worth-page")

    assert has_element?(
             view,
             "#filters_as_of_date[value=\"#{Date.to_iso8601(Date.utc_today())}\"]"
           )

    assert has_element?(view, "#net-worth-summary")
    assert has_element?(view, "#net-worth-accounts-table")
    assert has_element?(view, "#net-worth-freshness-badge")
    assert has_element?(view, "#net-worth-date-presets")
    assert has_element?(view, "#net-worth-date-preset-today")
    assert has_element?(view, "#net-worth-date-preset-last_month_end")
    assert has_element?(view, "#net-worth-date-preset-last_year_end")

    row_html = view |> element("#net-worth-account-row-#{checking.id}") |> render()

    assert row_html =~ "Checking"
    assert row_html =~ "1,250.00 USD"
    assert row_html =~ "Exact"

    view
    |> element("#net-worth-date-preset-last_year_end")
    |> render_click()

    assert has_element?(view, "#filters_as_of_date[value=\"#{Date.to_iso8601(last_year_end)}\"]")
  end

  test "renders liabilities as positive owed amounts and keeps no-history rows visible", %{
    conn: conn
  } do
    entity = insert(:entity, name: "Alpha")
    asset = insert_account(entity, name: "Checking")

    liability =
      insert_account(entity,
        name: "Card",
        account_type: :liability,
        operational_subtype: :credit_card
      )

    no_history_liability =
      insert_account(entity,
        name: "Line of Credit",
        account_type: :liability,
        operational_subtype: :credit_card
      )

    insert_snapshot!(asset, ~D[2026-03-10], "100.0000", "10.0000")
    insert_snapshot!(liability, ~D[2026-03-10], "-40.0000", "-5.0000")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/net-worth?as_of_date=2026-03-10")

    summary_html = view |> element("#net-worth-summary") |> render()
    liability_row_html = view |> element("#net-worth-account-row-#{liability.id}") |> render()

    no_history_row_html =
      view |> element("#net-worth-account-row-#{no_history_liability.id}") |> render()

    assert summary_html =~ "60.00 USD"
    assert summary_html =~ "100.00 USD"
    assert summary_html =~ "40.00 USD"

    assert liability_row_html =~ "Liability"
    assert liability_row_html =~ "40.00 USD"
    assert liability_row_html =~ "Exact"

    assert no_history_row_html =~ "Line of Credit"
    assert no_history_row_html =~ "Not available"
    assert no_history_row_html =~ "No snapshot"
    assert no_history_row_html =~ "No history"
  end

  test "shows entity column for multi-entity scope and refresh hint for stale balances", %{
    conn: conn
  } do
    entity_a = insert(:entity, name: "Alpha")
    entity_b = insert(:entity, name: "Beta")
    checking_a = insert_account(entity_a, name: "Alpha Cash")
    checking_b = insert_account(entity_b, name: "Beta Cash")

    expense =
      insert_account(entity_a,
        name: "Utilities",
        account_type: :expense,
        management_group: :category,
        operational_subtype: nil,
        institution_name: nil,
        institution_account_ref: nil
      )

    insert_snapshot!(checking_a, ~D[2026-03-10], "100.0000", "10.0000", ~U[2026-03-10 09:00:00Z])
    insert_snapshot!(checking_b, ~D[2026-03-10], "80.0000", "8.0000")

    create_transaction!(entity_a, ~D[2026-03-10], [
      %{account_id: checking_a.id, amount: Decimal.new("-20.0000")},
      %{account_id: expense.id, amount: Decimal.new("20.0000")}
    ])

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/net-worth?as_of_date=2026-03-10")

    assert has_element?(view, "#net-worth-refresh-hint")
    assert has_element?(view, "#net-worth-accounts-table th", "Entity")

    stale_row_html = view |> element("#net-worth-account-row-#{checking_a.id}") |> render()
    exact_row_html = view |> element("#net-worth-account-row-#{checking_b.id}") |> render()

    assert stale_row_html =~ "Alpha"
    assert stale_row_html =~ "Refreshable gap"
    assert exact_row_html =~ "Beta"
  end

  test "shows empty state when there are no included institution-managed asset or liability accounts",
       %{
         conn: conn
       } do
    entity = insert(:entity, name: "Alpha")

    _expense =
      insert_account(entity,
        name: "Groceries",
        account_type: :expense,
        management_group: :category,
        operational_subtype: nil,
        institution_name: nil,
        institution_account_ref: nil
      )

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/net-worth")

    assert has_element?(view, "#net-worth-empty")
    refute has_element?(view, "#net-worth-summary")
    refute has_element?(view, "#net-worth-accounts-table")
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
        description: "Net worth live test transaction",
        source_type: :manual,
        postings: postings
      })

    transaction
  end
end
