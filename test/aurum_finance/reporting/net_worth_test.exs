defmodule AurumFinance.Reporting.NetWorthTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.ReportingTestHelpers

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
end
