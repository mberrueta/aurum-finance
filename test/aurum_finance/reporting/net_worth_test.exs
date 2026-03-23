defmodule AurumFinance.Reporting.NetWorthTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.ReportingTestHelpers

  alias AurumFinance.Ledger
  alias AurumFinance.Reporting

  describe "net_worth_report/2" do
    test "returns an empty report when no institution-managed asset or liability accounts are in scope" do
      entity = insert(:entity, name: "Alpha")

      _category_account =
        insert_account(entity,
          name: "Groceries",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      _system_managed_account =
        insert_account(entity,
          name: "Opening Balances",
          account_type: :equity,
          management_group: :system_managed,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      assert {:ok, report} = Reporting.net_worth_report([entity.id], as_of_date: ~D[2026-03-10])

      assert report.empty? == true
      assert report.included_account_count == 0
      assert report.freshness_status == :up_to_date
      assert report.refresh_suggested? == false
      assert report.currency_summaries == []
      assert report.account_rows == []

      assert report.coverage_counts == %{
               exact: 0,
               carried_forward: 0,
               refreshable_gap: 0,
               no_history: 0
             }
    end

    test "filters the canonical account scope and keeps no-history rows visible" do
      entity = insert(:entity, name: "Alpha")
      other_entity = insert(:entity, name: "Beta")

      carried_asset = insert_account(entity, name: "Checking")

      no_history_liability =
        insert_account(entity,
          name: "Card",
          account_type: :liability,
          operational_subtype: :credit_card
        )

      _archived_asset =
        insert_account(entity,
          name: "Archived",
          archived_at: ~U[2026-03-10 12:00:00Z]
        )

      _category_account =
        insert_account(entity,
          name: "Groceries",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category,
          institution_name: nil,
          institution_account_ref: nil
        )

      _out_of_scope_asset = insert_account(other_entity, name: "Foreign")

      insert_snapshot!(carried_asset, ~D[2026-03-09], "100.0000", "5.0000")

      assert {:ok, report} = Reporting.net_worth_report([entity.id], as_of_date: ~D[2026-03-10])

      assert report.freshness_status == :up_to_date
      assert report.refresh_suggested? == false
      assert report.included_account_count == 2

      assert report.coverage_counts == %{
               exact: 0,
               carried_forward: 1,
               refreshable_gap: 0,
               no_history: 1
             }

      assert Enum.map(report.account_rows, & &1.account_name) == ["Card", "Checking"]

      checking_row = Enum.find(report.account_rows, &(&1.account_name == "Checking"))

      assert checking_row.account_id == carried_asset.id
      assert checking_row.coverage == :carried_forward
      assert checking_row.balance == Decimal.new("100.0000")
      assert checking_row.ledger_balance == Decimal.new("100.0000")
      assert checking_row.entity == %{id: entity.id, name: "Alpha"}
      assert checking_row.snapshot_date_used == ~D[2026-03-09]
      assert checking_row.contributes_to_totals? == true
      assert checking_row.snapshot.closing_balance == Decimal.new("100.0000")
      assert checking_row.snapshot.daily_delta == Decimal.new("5.0000")
      assert checking_row.snapshot.date == ~D[2026-03-09]
      assert checking_row.snapshot.projection_version == 1
      assert %DateTime{} = checking_row.snapshot.computed_at

      assert Enum.find(report.account_rows, &(&1.account_name == "Card")) == %{
               account_id: no_history_liability.id,
               account_name: "Card",
               account_type: :liability,
               balance: nil,
               contributes_to_totals?: false,
               coverage: :no_history,
               currency_code: "USD",
               entity: %{id: entity.id, name: "Alpha"},
               ledger_balance: nil,
               snapshot: nil,
               snapshot_date_used: nil
             }

      assert report.currency_summaries == [
               %{
                 account_count: 2,
                 assets: Decimal.new("100.0000"),
                 covered_account_count: 1,
                 currency_code: "USD",
                 liabilities: Decimal.new("0.0000"),
                 net_worth: Decimal.new("100.0000"),
                 no_history_count: 1
               }
             ]
    end

    test "returns per-currency summaries and presents liabilities as positive owed amounts" do
      entity = insert(:entity)

      usd_asset = insert_account(entity, name: "Checking")

      usd_liability =
        insert_account(entity,
          name: "Credit Card",
          account_type: :liability,
          operational_subtype: :credit_card
        )

      eur_asset =
        insert_account(entity,
          name: "Broker EUR",
          currency_code: "EUR",
          operational_subtype: :brokerage_cash
        )

      insert_snapshot!(usd_asset, ~D[2026-03-10], "100.0000", "10.0000")
      insert_snapshot!(usd_liability, ~D[2026-03-10], "-40.0000", "-5.0000")
      insert_snapshot!(eur_asset, ~D[2026-03-10], "50.0000", "2.0000")

      assert {:ok, report} = Reporting.net_worth_report([entity.id], as_of_date: ~D[2026-03-10])

      liability_row = Enum.find(report.account_rows, &(&1.account_name == "Credit Card"))

      assert liability_row.coverage == :exact
      assert liability_row.ledger_balance == Decimal.new("-40.0000")
      assert liability_row.balance == Decimal.new("40.0000")

      assert report.currency_summaries == [
               %{
                 account_count: 1,
                 assets: Decimal.new("50.0000"),
                 covered_account_count: 1,
                 currency_code: "EUR",
                 liabilities: Decimal.new("0.0000"),
                 net_worth: Decimal.new("50.0000"),
                 no_history_count: 0
               },
               %{
                 account_count: 2,
                 assets: Decimal.new("100.0000"),
                 covered_account_count: 2,
                 currency_code: "USD",
                 liabilities: Decimal.new("40.0000"),
                 net_worth: Decimal.new("60.0000"),
                 no_history_count: 0
               }
             ]
    end

    test "selects the latest snapshot on or before the as-of date and ignores later snapshots" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      insert_snapshot!(checking, ~D[2026-03-08], "80.0000", "8.0000", ~U[2026-03-08 09:00:00Z])
      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "20.0000", ~U[2026-03-10 09:00:00Z])
      insert_snapshot!(checking, ~D[2026-03-12], "140.0000", "40.0000", ~U[2026-03-12 09:00:00Z])

      assert {:ok, report} = Reporting.net_worth_report([entity.id], as_of_date: ~D[2026-03-11])

      assert report.freshness_status == :up_to_date
      assert report.refresh_suggested? == false

      assert [row] = report.account_rows

      assert row == %{
               account_id: checking.id,
               account_name: "Checking",
               account_type: :asset,
               balance: Decimal.new("100.0000"),
               contributes_to_totals?: true,
               coverage: :carried_forward,
               currency_code: "USD",
               entity: %{id: entity.id, name: "Alpha"},
               ledger_balance: Decimal.new("100.0000"),
               snapshot: %{
                 closing_balance: Decimal.new("100.0000"),
                 computed_at: row.snapshot.computed_at,
                 daily_delta: Decimal.new("20.0000"),
                 date: ~D[2026-03-10],
                 projection_version: 1
               },
               snapshot_date_used: ~D[2026-03-10]
             }

      assert DateTime.compare(row.snapshot.computed_at, ~U[2026-03-10 09:00:00Z]) == :eq

      assert report.currency_summaries == [
               %{
                 account_count: 1,
                 assets: Decimal.new("100.0000"),
                 covered_account_count: 1,
                 currency_code: "USD",
                 liabilities: Decimal.new("0.0000"),
                 net_worth: Decimal.new("100.0000"),
                 no_history_count: 0
               }
             ]
    end

    test "marks rows as refreshable_gap when later-inserted relevant ledger facts exist" do
      entity = insert(:entity)
      checking = insert_account(entity, name: "Checking")

      expense =
        insert_account(entity,
          name: "Utilities",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category,
          institution_name: nil,
          institution_account_ref: nil
        )

      computed_at = ~U[2026-03-10 09:00:00Z]

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "10.0000", computed_at)

      create_transaction!(entity, ~D[2026-03-10], [
        %{account_id: checking.id, amount: Decimal.new("-20.0000")},
        %{account_id: expense.id, amount: Decimal.new("20.0000")}
      ])

      assert {:ok, report} = Reporting.net_worth_report([entity.id], as_of_date: ~D[2026-03-10])

      assert report.freshness_status == :outdated
      assert report.refresh_suggested? == true
      assert report.coverage_counts.refreshable_gap == 1

      assert Enum.find(report.account_rows, &(&1.account_id == checking.id)).coverage ==
               :refreshable_gap
    end

    test "returns entity metadata for multi-entity scopes" do
      entity_a = insert(:entity, name: "Alpha")
      entity_b = insert(:entity, name: "Beta")

      account_a = insert_account(entity_a, name: "A Cash")
      account_b = insert_account(entity_b, name: "B Cash")

      insert_snapshot!(account_a, ~D[2026-03-10], "10.0000", "10.0000")
      insert_snapshot!(account_b, ~D[2026-03-10], "20.0000", "20.0000")

      assert {:ok, report} =
               Reporting.net_worth_report([entity_a.id, entity_b.id], as_of_date: ~D[2026-03-10])

      assert report.entity_count == 2
      assert report.show_entity_column? == true

      assert Enum.map(report.account_rows, & &1.entity.name) == ["Alpha", "Beta"]
    end

    test "normalizes nil and duplicate entity ids in scope input" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      insert_snapshot!(checking, ~D[2026-03-10], "10.0000", "10.0000")

      assert {:ok, report} =
               Reporting.net_worth_report([nil, entity.id, entity.id], as_of_date: ~D[2026-03-10])

      assert report.included_account_count == 1
      assert Enum.map(report.account_rows, & &1.account_id) == [checking.id]
    end

    test "marks exact-date snapshots as refreshable_gap when later inserts land on the same date" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      expense =
        insert_account(entity,
          name: "Dining",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category,
          institution_name: nil,
          institution_account_ref: nil
        )

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "10.0000", ~U[2026-03-10 09:00:00Z])

      create_transaction!(entity, ~D[2026-03-10], [
        %{account_id: checking.id, amount: Decimal.new("-30.0000")},
        %{account_id: expense.id, amount: Decimal.new("30.0000")}
      ])

      assert {:ok, report} = Reporting.net_worth_report([entity.id], as_of_date: ~D[2026-03-10])

      assert report.freshness_status == :outdated
      assert report.coverage_counts.refreshable_gap == 1

      assert Enum.find(report.account_rows, &(&1.account_id == checking.id)).coverage ==
               :refreshable_gap
    end
  end

  describe "drilldown_transactions/3" do
    test "S01: groups postings by transaction_id and sums duplicate postings for the selected account" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      offset =
        insert_account(entity,
          name: "Offset",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "0.0000")

      transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: checking.id, amount: Decimal.new("10.0000")},
            %{account_id: checking.id, amount: Decimal.new("-4.0000")},
            %{account_id: offset.id, amount: Decimal.new("-6.0000")}
          ],
          "Split balance explanation"
        )

      assert {:ok,
              %{
                transactions: [row],
                total_count: 1,
                page: 1,
                per_page: 20,
                total_pages: 1
              }} =
               Reporting.net_worth_drilldown_transactions(checking.id, ~D[2026-03-10])

      assert row.transaction_id == transaction.id
      assert row.date == ~D[2026-03-10]
      assert row.description == "Split balance explanation"
      assert row.net_amount == Decimal.new("6.0000")
    end

    test "S02: excludes transactions after the snapshot date boundary" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      offset =
        insert_account(entity,
          name: "Offset",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "0.0000")

      before_transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: checking.id, amount: Decimal.new("-12.0000")},
            %{account_id: offset.id, amount: Decimal.new("12.0000")}
          ],
          "Before boundary"
        )

      _after_transaction =
        create_transaction!(
          entity,
          ~D[2026-03-11],
          [
            %{account_id: checking.id, amount: Decimal.new("-99.0000")},
            %{account_id: offset.id, amount: Decimal.new("99.0000")}
          ],
          "After boundary"
        )

      assert {:ok, %{transactions: [row], total_count: 1}} =
               Reporting.net_worth_drilldown_transactions(checking.id, ~D[2026-03-10])

      assert row.transaction_id == before_transaction.id
      assert row.description == "Before boundary"
      assert row.net_amount == Decimal.new("-12.0000")
    end

    test "S03: orders transactions by date desc and inserted_at desc" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      offset =
        insert_account(entity,
          name: "Offset",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "0.0000")

      _earlier_transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: checking.id, amount: Decimal.new("-10.0000")},
            %{account_id: offset.id, amount: Decimal.new("10.0000")}
          ],
          "Earlier inserted"
        )

      later_transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: checking.id, amount: Decimal.new("-20.0000")},
            %{account_id: offset.id, amount: Decimal.new("20.0000")}
          ],
          "Later inserted"
        )

      assert {:ok, %{transactions: [first, second]}} =
               Reporting.net_worth_drilldown_transactions(checking.id, ~D[2026-03-10])

      assert first.transaction_id == later_transaction.id
      assert first.description == "Later inserted"
      assert second.description == "Earlier inserted"
    end

    test "S04: paginates results with Scrivener defaults and page boundaries" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      offset =
        insert_account(entity,
          name: "Offset",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "0.0000")

      created_transactions =
        for n <- 1..21 do
          create_transaction!(
            entity,
            ~D[2026-03-10],
            [
              %{account_id: checking.id, amount: Decimal.new("-1.0000")},
              %{account_id: offset.id, amount: Decimal.new("1.0000")}
            ],
            "Paginated #{n}"
          )
        end

      assert {:ok,
              %{
                transactions: page_one_entries,
                total_count: 21,
                page: 1,
                per_page: 20,
                total_pages: 2
              }} =
               Reporting.net_worth_drilldown_transactions(checking.id, ~D[2026-03-10],
                 page: 1,
                 per_page: 20
               )

      assert length(page_one_entries) == 20
      assert hd(page_one_entries).transaction_id == List.last(created_transactions).id
      assert List.last(page_one_entries).transaction_id == Enum.at(created_transactions, 1).id

      assert {:ok,
              %{
                transactions: page_two_entries,
                total_count: 21,
                page: 2,
                per_page: 20,
                total_pages: 2
              }} =
               Reporting.net_worth_drilldown_transactions(checking.id, ~D[2026-03-10],
                 page: 2,
                 per_page: 20
               )

      assert length(page_two_entries) == 1
      assert hd(page_two_entries).transaction_id == hd(created_transactions).id
    end

    test "S05: returns an empty result set when the account has no transactions" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "0.0000")

      assert {:ok,
              %{
                transactions: [],
                total_count: 0,
                page: 1,
                per_page: 20,
                total_pages: 1
              }} =
               Reporting.net_worth_drilldown_transactions(checking.id, ~D[2026-03-10])
    end

    test "S06: returns an empty result set for a non-existent account_id" do
      assert {:ok,
              %{
                transactions: [],
                total_count: 0,
                page: 1,
                per_page: 20,
                total_pages: 1
              }} =
               Reporting.net_worth_drilldown_transactions(Ecto.UUID.generate(), ~D[2026-03-10])
    end

    test "S07: preserves liability account raw posting amounts without taking abs" do
      entity = insert(:entity, name: "Alpha")

      liability =
        insert_account(entity,
          name: "Credit Card",
          account_type: :liability,
          operational_subtype: :credit_card
        )

      offset =
        insert_account(entity,
          name: "Offset",
          account_type: :asset,
          operational_subtype: :bank_checking
        )

      insert_snapshot!(liability, ~D[2026-03-10], "-40.0000", "0.0000")

      transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: liability.id, amount: Decimal.new("-15.0000")},
            %{account_id: offset.id, amount: Decimal.new("15.0000")}
          ],
          "Liability movement"
        )

      assert {:ok, %{transactions: [row], total_count: 1}} =
               Reporting.net_worth_drilldown_transactions(liability.id, ~D[2026-03-10])

      assert row.transaction_id == transaction.id
      assert row.net_amount == Decimal.new("-15.0000")
    end

    test "S08: retains voided transactions because the current projection does not filter them out" do
      entity = insert(:entity, name: "Alpha")
      checking = insert_account(entity, name: "Checking")

      offset =
        insert_account(entity,
          name: "Offset",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      insert_snapshot!(checking, ~D[2026-03-10], "100.0000", "0.0000")

      transaction =
        create_transaction!(
          entity,
          ~D[2026-03-10],
          [
            %{account_id: checking.id, amount: Decimal.new("-25.0000")},
            %{account_id: offset.id, amount: Decimal.new("25.0000")}
          ],
          "Voided movement"
        )

      {:ok, %{voided: voided, reversal: reversal}} = Ledger.void_transaction(transaction)

      assert %DateTime{} = voided.voided_at

      assert {:ok, %{transactions: rows, total_count: 2}} =
               Reporting.net_worth_drilldown_transactions(checking.id, ~D[2026-03-10])

      assert Enum.map(rows, & &1.transaction_id) == [reversal.id, voided.id]
      assert Enum.map(rows, & &1.net_amount) == [Decimal.new("25.0000"), Decimal.new("-25.0000")]
    end

    test "S09: keeps the entity boundary explicit when two entities have overlapping dates" do
      entity_a = insert(:entity, name: "Alpha")
      entity_b = insert(:entity, name: "Beta")

      account_a = insert_account(entity_a, name: "A Cash")
      account_b = insert_account(entity_b, name: "B Cash")

      offset_a =
        insert_account(entity_a,
          name: "A Offset",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      offset_b =
        insert_account(entity_b,
          name: "B Offset",
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      insert_snapshot!(account_a, ~D[2026-03-10], "10.0000", "0.0000")
      insert_snapshot!(account_b, ~D[2026-03-10], "20.0000", "0.0000")

      transaction_a =
        create_transaction!(
          entity_a,
          ~D[2026-03-10],
          [
            %{account_id: account_a.id, amount: Decimal.new("-11.0000")},
            %{account_id: offset_a.id, amount: Decimal.new("11.0000")}
          ],
          "Alpha transaction"
        )

      _transaction_b =
        create_transaction!(
          entity_b,
          ~D[2026-03-10],
          [
            %{account_id: account_b.id, amount: Decimal.new("-22.0000")},
            %{account_id: offset_b.id, amount: Decimal.new("22.0000")}
          ],
          "Beta transaction"
        )

      assert {:ok, %{transactions: [row], total_count: 1}} =
               Reporting.net_worth_drilldown_transactions(account_a.id, ~D[2026-03-10])

      assert row.transaction_id == transaction_a.id
      assert row.description == "Alpha transaction"
      assert row.net_amount == Decimal.new("-11.0000")
    end
  end
end
