defmodule AurumFinance.Reporting.LedgerEventBridgeTest do
  use AurumFinance.DataCase, async: false
  use Oban.Testing, repo: AurumFinance.Repo

  alias AurumFinance.Ledger
  alias AurumFinance.Repo
  alias AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker
  alias AurumFinance.Reporting.LedgerEventBridge

  describe "ledger event bridge" do
    test "enqueues one refresh per affected account from created transactions" do
      bridge_pid = start_bridge()
      entity = insert(:entity)
      checking = insert(:account, entity: entity, entity_id: entity.id)

      groceries =
        insert(:account,
          entity: entity,
          entity_id: entity.id,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      assert {:ok, _transaction} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-12],
                 description: "Bridge split purchase",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-15.0000")},
                   %{account_id: groceries.id, amount: Decimal.new("10.0000")},
                   %{account_id: groceries.id, amount: Decimal.new("5.0000")}
                 ]
               })

      _ = :sys.get_state(bridge_pid)

      assert_enqueued(
        worker: DailyBalanceSnapshotRefreshWorker,
        queue: :reporting,
        args: %{"account_id" => checking.id, "from_date" => "2026-03-12"}
      )

      assert_enqueued(
        worker: DailyBalanceSnapshotRefreshWorker,
        queue: :reporting,
        args: %{"account_id" => groceries.id, "from_date" => "2026-03-12"}
      )

      assert matching_refresh_jobs([checking.id, groceries.id], "2026-03-12") == 2
    end

    test "enqueues one refresh per affected account from voided transactions" do
      entity = insert(:entity)
      checking = insert(:account, entity: entity, entity_id: entity.id)

      groceries =
        insert(:account,
          entity: entity,
          entity_id: entity.id,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      assert {:ok, transaction} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-13],
                 description: "Bridge void purchase",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-10.0000")},
                   %{account_id: groceries.id, amount: Decimal.new("10.0000")}
                 ]
               })

      bridge_pid = start_bridge()

      assert {:ok, %{voided: _voided}} = Ledger.void_transaction(transaction)

      _ = :sys.get_state(bridge_pid)

      assert_enqueued(
        worker: DailyBalanceSnapshotRefreshWorker,
        queue: :reporting,
        args: %{"account_id" => checking.id, "from_date" => "2026-03-13"}
      )

      assert_enqueued(
        worker: DailyBalanceSnapshotRefreshWorker,
        queue: :reporting,
        args: %{"account_id" => groceries.id, "from_date" => "2026-03-13"}
      )

      assert matching_refresh_jobs([checking.id, groceries.id], "2026-03-13") == 2
    end
  end

  defp start_bridge do
    bridge_pid = start_supervised!({LedgerEventBridge, []})
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), bridge_pid)
    on_exit(fn -> stop_bridge(bridge_pid) end)
    _ = :sys.get_state(bridge_pid)
    bridge_pid
  end

  defp stop_bridge(bridge_pid) do
    ref = Process.monitor(bridge_pid)

    try do
      GenServer.stop(bridge_pid, :normal, 5_000)
    catch
      :exit, _reason ->
        :ok
    end

    assert_receive {:DOWN, ^ref, :process, ^bridge_pid, _reason}, 1_000
  end

  defp matching_refresh_jobs(account_ids, from_date) do
    account_ids = MapSet.new(account_ids)

    all_enqueued(worker: DailyBalanceSnapshotRefreshWorker, queue: :reporting)
    |> Enum.count(fn job ->
      job.args["from_date"] == from_date and MapSet.member?(account_ids, job.args["account_id"])
    end)
  end
end
