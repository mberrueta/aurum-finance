defmodule AurumFinanceWeb.TransactionsLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Ledger

  describe "mount" do
    test "renders real transactions and expands posting detail", %{conn: conn} do
      entity = insert_entity(name: "Transactions Entity")
      checking = insert_account(entity, %{name: "Checking Live"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Live",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Weekly groceries",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-45.00")},
            %{account_id: groceries.id, amount: Decimal.new("45.00")}
          ]
        })

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions")

      view
      |> form("#transactions-entity-selector", entity_id: entity.id)
      |> render_change()

      assert has_element?(view, "#transaction-#{transaction.id}")
      assert has_element?(view, "#transaction-#{transaction.id}-summary")
      refute has_element?(view, "#transaction-#{transaction.id}-detail")

      view
      |> element("#transaction-#{transaction.id}-summary")
      |> render_click()

      assert has_element?(view, "#transaction-#{transaction.id}-detail")
      assert render(view) =~ "Checking Live"
      assert render(view) =~ "USD"
    end

    test "renders empty state when the selected entity has no transactions", %{conn: conn} do
      entity = insert_entity(name: "Transactions Empty Entity")

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions")

      view
      |> form("#transactions-entity-selector", entity_id: entity.id)
      |> render_change()

      assert has_element?(view, "#transactions-page")
      assert render(view) =~ "No transactions found for the selected filters."
    end
  end

  describe "filtering" do
    test "filters by account and date preset while keeping the page read-only", %{conn: conn} do
      entity = insert_entity(name: "Transactions Filter Entity")
      checking = insert_account(entity, %{name: "Checking Filter"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Filter",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      savings =
        insert_account(entity, %{name: "Savings Filter", operational_subtype: :bank_savings})

      {:ok, tx_a} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: Date.add(Date.utc_today(), -2),
          description: "Groceries filter",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-20.00")},
            %{account_id: groceries.id, amount: Decimal.new("20.00")}
          ]
        })

      {:ok, tx_b} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2025-12-31],
          description: "Savings transfer",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-50.00")},
            %{account_id: savings.id, amount: Decimal.new("50.00")}
          ]
        })

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions")

      view
      |> form("#transactions-entity-selector", entity_id: entity.id)
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}")

      refute has_element?(view, "#new-transaction-btn")
      refute has_element?(view, "[data-role='transaction-create']")
      refute render(view) =~ "Void transaction"

      view
      |> element("#transactions-toggle-filters")
      |> render_click()

      view
      |> form("#transactions-filter-form", filters: %{"account_id" => groceries.id})
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&account:#{groceries.id}")

      assert has_element?(view, "#transaction-#{tx_a.id}")
      refute has_element?(view, "#transaction-#{tx_b.id}")

      view
      |> element("#transactions-date-preset-this_year")
      |> render_click()

      assert_patch(
        view,
        "/transactions?q=entity:#{entity.id}&account:#{groceries.id}&date:this_year"
      )

      assert has_element?(view, "#transaction-#{tx_a.id}")
      refute has_element?(view, "#transaction-#{tx_b.id}")
    end

    test "hydrates filters from the compact query string", %{conn: conn} do
      entity = insert_entity(name: "Transactions Query Entity")
      checking = insert_account(entity, %{name: "Checking Query"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Query",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      travel =
        insert_account(entity, %{
          name: "Travel Query",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, tx_a} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: Date.add(Date.utc_today(), -1),
          description: "Query groceries",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-35.00")},
            %{account_id: groceries.id, amount: Decimal.new("35.00")}
          ]
        })

      {:ok, tx_b} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: Date.add(Date.utc_today(), -1),
          description: "Query travel",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-60.00")},
            %{account_id: travel.id, amount: Decimal.new("60.00")}
          ]
        })

      path = "/transactions?q=entity:#{entity.id}&account:#{groceries.id}&date:this_month"

      {:ok, view, _html} = conn |> log_in_root() |> live(path)

      assert has_element?(view, "#transaction-#{tx_a.id}")
      refute has_element?(view, "#transaction-#{tx_b.id}")
      assert has_element?(view, "#transactions-date-preset-this_month")
      assert has_element?(view, "#transactions-filter-form")
    end

    test "excludes voided transactions by default and includes them when requested", %{conn: conn} do
      entity = insert_entity(name: "Transactions Voided Entity")
      checking = insert_account(entity, %{name: "Checking Voided"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Voided",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Voided groceries",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-45.00")},
            %{account_id: groceries.id, amount: Decimal.new("45.00")}
          ]
        })

      assert {:ok, %{voided: voided, reversal: reversal}} = Ledger.void_transaction(transaction)

      {:ok, view, _html} =
        conn
        |> log_in_root()
        |> live("/transactions?q=entity:#{entity.id}")

      refute has_element?(view, "#transaction-#{voided.id}")
      assert has_element?(view, "#transaction-#{reversal.id}")

      view
      |> element("#transactions-toggle-filters")
      |> render_click()

      view
      |> form("#transactions-filter-form", filters: %{"include_voided" => "true"})
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&voided:true")
      assert has_element?(view, "#transaction-#{voided.id}")
      assert has_element?(view, "#transaction-#{reversal.id}")
    end

    test "filters by source type", %{conn: conn} do
      entity = insert_entity(name: "Transactions Source Entity")
      checking = insert_account(entity, %{name: "Checking Source"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Source",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, manual_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Manual groceries",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-20.00")},
            %{account_id: groceries.id, amount: Decimal.new("20.00")}
          ]
        })

      {:ok, import_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Imported groceries",
          source_type: :import,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-25.00")},
            %{account_id: groceries.id, amount: Decimal.new("25.00")}
          ]
        })

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions?q=entity:#{entity.id}")

      view
      |> element("#transactions-toggle-filters")
      |> render_click()

      view
      |> form("#transactions-filter-form", filters: %{"source_type" => "import"})
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&source:import")
      assert has_element?(view, "#transaction-#{import_tx.id}")
      refute has_element?(view, "#transaction-#{manual_tx.id}")
    end
  end

  describe "read-only invariant" do
    test "does not render mutation buttons or mutation forms", %{conn: conn} do
      entity = insert_entity(name: "Transactions Readonly Entity")
      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions?q=entity:#{entity.id}")

      html = render(view)

      refute html =~ "New Transaction"
      refute html =~ "Void transaction"
      refute html =~ "Edit transaction"
      refute html =~ ~s(phx-submit="create")
      refute html =~ ~s(phx-submit="save")
    end
  end
end
