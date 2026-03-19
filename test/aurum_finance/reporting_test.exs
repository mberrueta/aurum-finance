defmodule AurumFinance.ReportingTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Ledger
  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.DailyBalanceSnapshot
  alias AurumFinance.Repo

  describe "list_daily_balance_snapshots/1" do
    test "filters by account, entity, and date range" do
      entity_a = insert(:entity)
      entity_b = insert(:entity)
      account_a = insert_account(entity_a)
      account_b = insert_account(entity_b)

      insert_snapshot!(account_a, ~D[2026-03-10], "10.0000", "10.0000")
      insert_snapshot!(account_a, ~D[2026-03-11], "11.0000", "1.0000")
      insert_snapshot!(account_b, ~D[2026-03-10], "50.0000", "50.0000")

      assert Enum.map(
               Reporting.list_daily_balance_snapshots(account_id: account_a.id),
               & &1.snapshot_date
             ) ==
               [~D[2026-03-10], ~D[2026-03-11]]

      assert Enum.map(
               Reporting.list_daily_balance_snapshots(entity_id: entity_b.id),
               & &1.account_id
             ) ==
               [account_b.id]

      assert Enum.map(
               Reporting.list_daily_balance_snapshots(
                 account_id: account_a.id,
                 date_from: ~D[2026-03-11],
                 date_to: ~D[2026-03-11]
               ),
               & &1.snapshot_date
             ) == [~D[2026-03-11]]
    end
  end

  describe "refresh_daily_balance_snapshots/3 no-op semantics" do
    test "rebuilds one account series and exposes earliest/latest helpers" do
      entity = insert(:entity)
      checking = insert_account(entity)

      expense =
        insert_account(entity,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      create_transaction!(entity, ~D[2026-03-10], [
        %{account_id: checking.id, amount: Decimal.new("-10.0000")},
        %{account_id: expense.id, amount: Decimal.new("10.0000")}
      ])

      create_transaction!(entity, ~D[2026-03-12], [
        %{account_id: checking.id, amount: Decimal.new("-5.0000")},
        %{account_id: expense.id, amount: Decimal.new("5.0000")}
      ])

      assert {:ok, result} = Reporting.refresh_daily_balance_snapshots(checking, nil)
      assert result.status == :rebuilt
      assert result.effective_from_date == ~D[2026-03-10]

      assert Reporting.earliest_snapshot_date_for_account(checking) == ~D[2026-03-10]
      assert Reporting.latest_snapshot_date_for_account(checking) == ~D[2026-03-12]

      snapshots = Reporting.list_daily_balance_snapshots(account_id: checking.id)

      assert Enum.map(snapshots, & &1.snapshot_date) == [
               ~D[2026-03-10],
               ~D[2026-03-11],
               ~D[2026-03-12]
             ]
    end
  end

  describe "refresh_daily_balance_snapshots/3" do
    test "preserves noop semantics when from_date is after the last effective date" do
      entity = insert(:entity)
      checking = insert_account(entity)

      expense =
        insert_account(entity,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      create_transaction!(entity, ~D[2026-03-10], [
        %{account_id: checking.id, amount: Decimal.new("-10.0000")},
        %{account_id: expense.id, amount: Decimal.new("10.0000")}
      ])

      assert {:ok, _result} = Reporting.refresh_daily_balance_snapshots(checking, nil)

      [snapshot] = Reporting.list_daily_balance_snapshots(account_id: checking.id)
      computed_at_before_noop = snapshot.computed_at

      assert {:ok, result} =
               Reporting.refresh_daily_balance_snapshots(
                 checking,
                 ~D[2026-03-11]
               )

      assert result.status == :noop

      assert Reporting.list_daily_balance_snapshots(account_id: checking.id)
             |> List.first()
             |> Map.fetch!(:computed_at) ==
               computed_at_before_noop
    end
  end

  defp insert_snapshot!(account, snapshot_date, closing_balance, daily_delta) do
    %DailyBalanceSnapshot{}
    |> DailyBalanceSnapshot.changeset(%{
      account_id: account.id,
      entity_id: account.entity_id,
      snapshot_date: snapshot_date,
      closing_balance: Decimal.new(closing_balance),
      daily_delta: Decimal.new(daily_delta),
      computed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      projection_version: 1
    })
    |> Repo.insert!()
  end

  defp create_transaction!(entity, date, postings) do
    {:ok, transaction} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: date,
        description: "Reporting context test transaction",
        source_type: :manual,
        postings: postings
      })

    transaction
  end
end
