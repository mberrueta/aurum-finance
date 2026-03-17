defmodule AurumFinanceWeb.TransactionsLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Classification
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

    test "expands a transaction when the compact query includes tx", %{conn: conn} do
      entity = insert_entity(name: "Transactions Deep Link Entity")
      checking = insert_account(entity, %{name: "Checking Deep Link"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Deep Link",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Deep link groceries",
          source_type: :import,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-45.00")},
            %{account_id: groceries.id, amount: Decimal.new("45.00")}
          ]
        })

      path = "/transactions?q=entity:#{entity.id}&tx:#{transaction.id}"

      {:ok, view, _html} = conn |> log_in_root() |> live(path)

      assert has_element?(view, "#transaction-#{transaction.id}")
      assert has_element?(view, "#transaction-#{transaction.id}-detail")
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

      view
      |> element("#transactions-clear-filters")
      |> render_click()

      assert_patch(view, "/transactions?q=entity:#{entity.id}")
      assert has_element?(view, "#transaction-#{tx_a.id}")
      assert has_element?(view, "#transaction-#{tx_b.id}")
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
      |> form("#transactions-filter-form", filters: %{"source_type" => "import"})
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&source:import")
      assert has_element?(view, "#transaction-#{import_tx.id}")
      refute has_element?(view, "#transaction-#{manual_tx.id}")
    end

    test "filters by free text across description and tags", %{conn: conn} do
      entity = insert_entity(name: "Transactions Search Entity")
      checking = insert_account(entity, %{name: "Checking Search"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Search",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, description_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Netflix annual plan",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-35.00")},
            %{account_id: groceries.id, amount: Decimal.new("35.00")}
          ]
        })

      {:ok, tag_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Airport coffee",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-12.00")},
            %{account_id: groceries.id, amount: Decimal.new("12.00")}
          ]
        })

      {:ok, other_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Local bakery",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-8.00")},
            %{account_id: groceries.id, amount: Decimal.new("8.00")}
          ]
        })

      {:ok, _record} =
        Classification.set_manual_field(
          tag_tx.id,
          "tags",
          "travel",
          entity_id: entity.id,
          actor: "test",
          channel: :web
        )

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions?q=entity:#{entity.id}")

      view
      |> form("#transactions-filter-form", filters: %{"search_text" => "netflix"})
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&search:netflix")
      assert has_element?(view, "#transaction-#{description_tx.id}")
      refute has_element?(view, "#transaction-#{tag_tx.id}")
      refute has_element?(view, "#transaction-#{other_tx.id}")

      view
      |> form("#transactions-filter-form", filters: %{"search_text" => "travel"})
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&search:travel")
      assert has_element?(view, "#transaction-#{tag_tx.id}")
      refute has_element?(view, "#transaction-#{description_tx.id}")
      refute has_element?(view, "#transaction-#{other_tx.id}")
    end

    test "filters by classification category", %{conn: conn} do
      entity = insert_entity(name: "Transactions Category Filter Entity")
      checking = insert_account(entity, %{name: "Checking Category Filter"})

      groceries =
        insert_account(entity, %{
          name: "Groceries Category Filter",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      travel =
        insert_account(entity, %{
          name: "Travel Category Filter",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, groceries_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Supermarket run",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-42.00")},
            %{account_id: groceries.id, amount: Decimal.new("42.00")}
          ]
        })

      {:ok, travel_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Flight ticket",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-180.00")},
            %{account_id: travel.id, amount: Decimal.new("180.00")}
          ]
        })

      {:ok, _record} =
        Classification.set_manual_field(
          groceries_tx.id,
          "category",
          groceries.id,
          entity_id: entity.id,
          actor: "test",
          channel: :web
        )

      {:ok, _record} =
        Classification.set_manual_field(
          travel_tx.id,
          "category",
          travel.id,
          entity_id: entity.id,
          actor: "test",
          channel: :web
        )

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions?q=entity:#{entity.id}")

      view
      |> form("#transactions-filter-form", filters: %{"category_account_id" => groceries.id})
      |> render_change()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&category:#{groceries.id}")
      assert has_element?(view, "#transaction-#{groceries_tx.id}")
      refute has_element?(view, "#transaction-#{travel_tx.id}")
    end

    test "clicking category, tag, and source in the table applies matching filters", %{conn: conn} do
      entity = insert_entity(name: "Transactions Inline Filter Entity")
      checking = insert_account(entity, %{name: "Checking Inline Filter"})

      shopping =
        insert_account(entity, %{
          name: "Shopping",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      groceries =
        insert_account(entity, %{
          name: "Groceries Inline Filter",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, target_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Online marketplace order",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-55.00")},
            %{account_id: shopping.id, amount: Decimal.new("55.00")}
          ]
        })

      {:ok, other_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Store purchase",
          source_type: :import,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-22.00")},
            %{account_id: groceries.id, amount: Decimal.new("22.00")}
          ]
        })

      {:ok, _record} =
        Classification.set_manual_field(
          target_tx.id,
          "category",
          shopping.id,
          entity_id: entity.id,
          actor: "test",
          channel: :web
        )

      {:ok, _record} =
        Classification.set_manual_field(
          target_tx.id,
          "tags",
          "ecommerce",
          entity_id: entity.id,
          actor: "test",
          channel: :web
        )

      {:ok, _record} =
        Classification.set_manual_field(
          other_tx.id,
          "category",
          groceries.id,
          entity_id: entity.id,
          actor: "test",
          channel: :web
        )

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions?q=entity:#{entity.id}")

      refute has_element?(view, "#transaction-#{target_tx.id}-detail")

      view
      |> element("#transaction-#{target_tx.id}-filter-category")
      |> render_click()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&category:#{shopping.id}")
      assert has_element?(view, "#transaction-#{target_tx.id}")
      refute has_element?(view, "#transaction-#{other_tx.id}")
      refute has_element?(view, "#transaction-#{target_tx.id}-detail")

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions?q=entity:#{entity.id}")

      view
      |> element("#transaction-#{target_tx.id}-filter-tag-0")
      |> render_click()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&search:ecommerce")
      assert has_element?(view, "#transaction-#{target_tx.id}")
      refute has_element?(view, "#transaction-#{other_tx.id}")

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions?q=entity:#{entity.id}")

      view
      |> element("#transaction-#{target_tx.id}-filter-source")
      |> render_click()

      assert_patch(view, "/transactions?q=entity:#{entity.id}&source:manual")
      assert has_element?(view, "#transaction-#{target_tx.id}")
      refute has_element?(view, "#transaction-#{other_tx.id}")
    end
  end

  describe "classification UI" do
    test "applies rules for a single transaction and renders rule provenance with scope", %{
      conn: conn
    } do
      entity = insert_entity(name: "Transactions Single Apply Entity")
      checking = insert_account(entity, %{name: "Checking Single Apply"})

      commute_category =
        insert_account(entity, %{
          name: "Commute Category",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      scope_group =
        insert_account_rule_group(checking, %{name: "Account Scoped Rules", priority: 1})

      scope_rule =
        insert_rule(scope_group, %{
          name: "Uber commute",
          expression: ~s|description contains "uber"|,
          actions: [
            %{field: :category, operation: :set, value: commute_category.id},
            %{field: :tags, operation: :add, value: "commute"}
          ]
        })

      {:ok, transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: Date.utc_today(),
          description: "uber downtown",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-18.00")},
            %{account_id: commute_category.id, amount: Decimal.new("18.00")}
          ]
        })

      {:ok, view, _html} =
        conn
        |> log_in_root()
        |> live("/transactions?q=entity:#{entity.id}")

      view
      |> element("#transaction-#{transaction.id}-summary")
      |> render_click()

      view
      |> element("#transaction-#{transaction.id}-apply-rules")
      |> render_click()

      _ = :sys.get_state(view.pid)

      record = Classification.get_classification_record(transaction.id)
      assert record.category_account_id == commute_category.id
      assert record.tags == ["commute"]

      assert has_element?(
               view,
               "#transaction-#{transaction.id}-classification-summary",
               scope_group.name
             )

      assert has_element?(
               view,
               "#transaction-#{transaction.id}-classification-summary",
               scope_rule.name
             )

      scope_label =
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "transactions",
          "classification_scope_account"
        )

      assert has_element?(
               view,
               "#transaction-#{transaction.id}-classification-summary",
               scope_label
             )
    end

    test "bulk applies rules for the selected entity and current date range", %{conn: conn} do
      entity = insert_entity(name: "Transactions Bulk Apply Entity")
      checking = insert_account(entity, %{name: "Checking Bulk Apply"})

      rent_category =
        insert_account(entity, %{
          name: "Rent Category",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      group = insert_rule_group(entity, %{name: "Rent Group", priority: 1})

      insert_rule(group, %{
        name: "Rent Matcher",
        expression: ~s|description contains "rent"|,
        actions: [%{field: :tags, operation: :add, value: "housing"}]
      })

      {:ok, in_range_transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: Date.utc_today(),
          description: "rent payment",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-1000.00")},
            %{account_id: rent_category.id, amount: Decimal.new("1000.00")}
          ]
        })

      {:ok, out_of_range_transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: Date.add(Date.utc_today(), -400),
          description: "rent payment old",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-950.00")},
            %{account_id: rent_category.id, amount: Decimal.new("950.00")}
          ]
        })

      {:ok, view, _html} = conn |> log_in_root() |> live("/transactions")

      view
      |> form("#transactions-entity-selector", entity_id: entity.id)
      |> render_change()

      view
      |> element("#transactions-date-preset-this_year")
      |> render_click()

      view
      |> element("#transactions-bulk-apply")
      |> render_click()

      _ = :sys.get_state(view.pid)

      assert has_element?(view, "#transactions-bulk-apply-summary")
      assert %{} = Classification.get_classification_record(in_range_transaction.id)
      assert is_nil(Classification.get_classification_record(out_of_range_transaction.id))
    end

    test "bulk apply stays disabled until a concrete date preset is selected", %{conn: conn} do
      entity = insert_entity(name: "Transactions Bulk Apply Disabled Entity")
      _checking = insert_account(entity, %{name: "Checking Bulk Apply Disabled"})

      {:ok, view, _html} =
        conn
        |> log_in_root()
        |> live("/transactions?q=entity:#{entity.id}")

      assert has_element?(view, "#transactions-bulk-apply[disabled]")

      view
      |> element("#transactions-date-preset-this_month")
      |> render_click()

      refute has_element?(view, "#transactions-bulk-apply[disabled]")
    end

    test "manual overrides keep the row reopenable after saving", %{conn: conn} do
      entity = insert_entity(name: "Transactions Classification Entity")
      checking = insert_account(entity, %{name: "Checking Classification"})

      fuel =
        insert_account(entity, %{
          name: "Fuel Category",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Fuel station",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-70.00")},
            %{account_id: fuel.id, amount: Decimal.new("70.00")}
          ]
        })

      {:ok, view, _html} =
        conn
        |> log_in_root()
        |> live("/transactions?q=entity:#{entity.id}")

      view
      |> element("#transaction-#{transaction.id}-summary")
      |> render_click()

      view
      |> element("#transaction-#{transaction.id}-edit-classification")
      |> render_click()

      view
      |> form("#transaction-#{transaction.id}-field-tags-manual-form", %{
        "transaction_id" => transaction.id,
        "field" => "tags",
        "manual_override" => %{"value" => "gass"}
      })
      |> render_submit()

      assert Classification.get_classification_record(transaction.id).tags == ["gass"]
      assert has_element?(view, "#transaction-#{transaction.id}-field-tags-clear-override")

      view
      |> element("#transaction-#{transaction.id}-summary")
      |> render_click()

      refute has_element?(view, "#transaction-#{transaction.id}-detail")

      view
      |> element("#transaction-#{transaction.id}-summary")
      |> render_click()

      assert has_element?(view, "#transaction-#{transaction.id}-detail")
      refute has_element?(view, "#transaction-#{transaction.id}-field-tags-manual-form")
      assert has_element?(view, "#transaction-#{transaction.id}-edit-classification")

      view
      |> element("#transaction-#{transaction.id}-edit-classification")
      |> render_click()

      assert has_element?(view, "#transaction-#{transaction.id}-field-tags-clear-override")

      locked_label =
        Gettext.dgettext(AurumFinanceWeb.Gettext, "transactions", "classification_locked")

      manual_state_label =
        Gettext.dgettext(AurumFinanceWeb.Gettext, "transactions", "classification_state_manual")

      assert has_element?(
               view,
               "#transaction-#{transaction.id}-classification-summary",
               locked_label
             )

      assert has_element?(
               view,
               "#transaction-#{transaction.id}-classification-summary",
               manual_state_label
             )

      view
      |> element("#transaction-#{transaction.id}-field-tags-clear-override")
      |> render_click()

      cleared_record = Classification.get_classification_record(transaction.id)
      assert cleared_record.tags == ["gass"]
      refute cleared_record.tags_manually_overridden
      refute has_element?(view, "#transaction-#{transaction.id}-field-tags-clear-override")
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
