defmodule AurumFinanceWeb.NetWorthLiveTest do
  use AurumFinanceWeb.ConnCase, async: false

  import AurumFinance.ReportingTestHelpers
  import Phoenix.LiveViewTest

  defmodule FailingReporting do
    def net_worth_report(_entity_ids, _opts \\ []), do: {:error, :db_down}
    def subscribe_hub_freshness, do: :ok
  end

  defmodule CountingReporting do
    def net_worth_report(_entity_ids, opts \\ []) do
      if test_pid = Application.get_env(:aurum_finance, :reporting_test_pid) do
        send(test_pid, {:net_worth_report_called, Keyword.get(opts, :as_of_date)})
      end

      {:ok,
       %{
         as_of_date: Keyword.get(opts, :as_of_date, Date.utc_today()),
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
  end

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

  test "keeps the LiveView alive when the report load fails", %{conn: conn} do
    previous_reporting_module = Application.get_env(:aurum_finance, :reporting_module)
    Application.put_env(:aurum_finance, :reporting_module, FailingReporting)

    on_exit(fn ->
      if previous_reporting_module do
        Application.put_env(:aurum_finance, :reporting_module, previous_reporting_module)
      else
        Application.delete_env(:aurum_finance, :reporting_module)
      end
    end)

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/net-worth")

    assert has_element?(view, "#net-worth-page")
    assert has_element?(view, "#net-worth-empty")
    assert has_element?(view, "#net-worth-freshness-badge", "Unavailable")
    assert has_element?(view, "[role=alert]")
  end

  test "falls back to Date.utc_today when as_of_date in the URL is invalid", %{conn: conn} do
    entity = insert(:entity, name: "Alpha")
    checking = insert_account(entity, name: "Checking")

    insert_snapshot!(checking, Date.utc_today(), "25.0000", "25.0000")

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/net-worth?as_of_date=bad-date")

    assert has_element?(
             view,
             "#filters_as_of_date[value=\"#{Date.to_iso8601(Date.utc_today())}\"]"
           )
  end

  test "debounces bursts of freshness events into one report reload", %{conn: conn} do
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

    {:ok, view, _html} = conn |> log_in_root() |> live("/reports/net-worth")
    flush_net_worth_report_calls()

    send(view.pid, {:reporting_hub_freshness_invalidated, %{}})
    send(view.pid, {:reporting_hub_freshness_refreshed, %{}})
    send(view.pid, {:reporting_hub_freshness_invalidated, %{}})

    assert_receive {:net_worth_report_called, _as_of_date}, 250
    refute_receive {:net_worth_report_called, _as_of_date}, 150
  end

  describe "drilldown UI" do
    test "S01: opens and closes a drilldown panel for a snapshot-backed row and shows its summary",
         %{
           conn: conn
         } do
      entity = insert(:entity, name: "Alpha")
      offset = insert_category_account(entity, "Offset")
      checking = insert_account(entity, name: "Checking")
      savings = insert_account(entity, name: "Savings")

      no_history =
        insert_account(entity,
          name: "Card",
          account_type: :liability,
          operational_subtype: :credit_card
        )

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "0.0000", ~U[2026-03-10 09:00:00Z])
      insert_snapshot!(savings, ~D[2026-03-10], "200.0000", "0.0000")

      stale_transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: checking.id, amount: Decimal.new("-15.0000")},
            %{account_id: offset.id, amount: Decimal.new("15.0000")}
          ],
          "Stale balance explanation"
        )

      _exact_transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: savings.id, amount: Decimal.new("-25.0000")},
            %{account_id: offset.id, amount: Decimal.new("25.0000")}
          ],
          "Exact balance explanation"
        )

      {:ok, view, _html} =
        conn |> log_in_root() |> live("/reports/net-worth?as_of_date=2026-03-10")

      assert has_element?(
               view,
               "#net-worth-account-row-#{checking.id}[phx-click=\"toggle_drilldown\"]"
             )

      assert has_element?(view, "#net-worth-account-row-#{checking.id}", "Outdated")
      assert has_element?(view, "#net-worth-account-row-#{no_history.id}", "No snapshot")
      refute has_element?(view, "#net-worth-account-row-#{no_history.id}[phx-click]")

      view
      |> element("#net-worth-account-row-#{checking.id}")
      |> render_click()

      assert has_element?(view, "#net-worth-drilldown-#{checking.id}")

      panel_html = view |> element("#net-worth-drilldown-#{checking.id}") |> render()

      assert panel_html =~ "Balance Explanation"
      assert panel_html =~ "Outdated"
      assert panel_html =~ "Balance of 100.00 USD as of 2026-03-10"
      assert has_element?(view, "#net-worth-drilldown-#{checking.id} th", "Date")
      assert has_element?(view, "#net-worth-drilldown-#{checking.id} th", "Description")
      assert has_element?(view, "#net-worth-drilldown-#{checking.id} th", "Amount")

      assert has_element?(
               view,
               "#net-worth-drilldown-#{checking.id}-transaction-#{stale_transaction.id}"
             )

      view
      |> element("#net-worth-account-row-#{checking.id}")
      |> render_click()

      refute has_element?(view, "#net-worth-drilldown-#{checking.id}")
    end

    test "S02: opening a different row closes the previous drilldown panel", %{conn: conn} do
      entity = insert(:entity, name: "Alpha")
      offset = insert_category_account(entity, "Offset")
      first_account = insert_account(entity, name: "First")
      second_account = insert_account(entity, name: "Second")

      insert_snapshot!(first_account, ~D[2026-03-10], "100.0000", "0.0000")
      insert_snapshot!(second_account, ~D[2026-03-10], "200.0000", "0.0000")

      create_transaction!(
        entity,
        ~D[2026-03-10],
        [
          %{account_id: first_account.id, amount: Decimal.new("-10.0000")},
          %{account_id: offset.id, amount: Decimal.new("10.0000")}
        ],
        "First explanation"
      )

      create_transaction!(
        entity,
        ~D[2026-03-10],
        [
          %{account_id: second_account.id, amount: Decimal.new("-20.0000")},
          %{account_id: offset.id, amount: Decimal.new("20.0000")}
        ],
        "Second explanation"
      )

      {:ok, view, _html} =
        conn |> log_in_root() |> live("/reports/net-worth?as_of_date=2026-03-10")

      view
      |> element("#net-worth-account-row-#{first_account.id}")
      |> render_click()

      assert has_element?(view, "#net-worth-drilldown-#{first_account.id}")

      view
      |> element("#net-worth-account-row-#{second_account.id}")
      |> render_click()

      refute has_element?(view, "#net-worth-drilldown-#{first_account.id}")
      assert has_element?(view, "#net-worth-drilldown-#{second_account.id}")
    end

    test "S03: paginates drilldown transactions and resets to page 1 when opening a different row",
         %{
           conn: conn
         } do
      entity = insert(:entity, name: "Alpha")
      offset = insert_category_account(entity, "Offset")
      primary_account = insert_account(entity, name: "Primary")
      secondary_account = insert_account(entity, name: "Secondary")

      insert_snapshot!(primary_account, ~D[2026-03-10], "100.0000", "0.0000")
      insert_snapshot!(secondary_account, ~D[2026-03-10], "200.0000", "0.0000")

      primary_transactions =
        for n <- 1..21 do
          create_transaction!(
            entity,
            ~D[2026-03-10],
            [
              %{account_id: primary_account.id, amount: Decimal.new("-1.0000")},
              %{account_id: offset.id, amount: Decimal.new("1.0000")}
            ],
            "Primary #{n}"
          )
        end

      secondary_transactions =
        for n <- 1..21 do
          create_transaction!(
            entity,
            ~D[2026-03-10],
            [
              %{account_id: secondary_account.id, amount: Decimal.new("-1.0000")},
              %{account_id: offset.id, amount: Decimal.new("1.0000")}
            ],
            "Secondary #{n}"
          )
        end

      {:ok, view, _html} =
        conn |> log_in_root() |> live("/reports/net-worth?as_of_date=2026-03-10")

      view
      |> element("#net-worth-account-row-#{primary_account.id}")
      |> render_click()

      assert has_element?(view, "#net-worth-drilldown-#{primary_account.id}")
      assert has_element?(view, "#net-worth-drilldown-#{primary_account.id}-prev")
      assert has_element?(view, "#net-worth-drilldown-#{primary_account.id}-next")
      assert has_element?(view, "#net-worth-drilldown-#{primary_account.id}", "Page 1 of 2")

      assert has_element?(
               view,
               "#net-worth-drilldown-#{primary_account.id}-transaction-#{List.last(primary_transactions).id}"
             )

      view
      |> element("#net-worth-drilldown-#{primary_account.id}-next")
      |> render_click()

      assert has_element?(view, "#net-worth-drilldown-#{primary_account.id}", "Page 2 of 2")

      assert has_element?(
               view,
               "#net-worth-drilldown-#{primary_account.id}-transaction-#{hd(primary_transactions).id}"
             )

      view
      |> element("#net-worth-account-row-#{secondary_account.id}")
      |> render_click()

      assert has_element?(view, "#net-worth-drilldown-#{secondary_account.id}", "Page 1 of 2")

      assert has_element?(
               view,
               "#net-worth-drilldown-#{secondary_account.id}-transaction-#{List.last(secondary_transactions).id}"
             )
    end
  end

  defp flush_net_worth_report_calls do
    receive do
      {:net_worth_report_called, _as_of_date} -> flush_net_worth_report_calls()
    after
      0 -> :ok
    end
  end

  defp insert_category_account(entity, name) do
    insert_account(entity,
      name: name,
      account_type: :expense,
      management_group: :category,
      operational_subtype: nil,
      institution_name: nil,
      institution_account_ref: nil
    )
  end
end
