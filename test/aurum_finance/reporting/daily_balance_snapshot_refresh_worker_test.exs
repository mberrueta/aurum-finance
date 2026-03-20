defmodule AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorkerTest do
  use AurumFinance.DataCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker

  describe "new_job/2" do
    test "builds a reporting job and normalizes nil from_date" do
      account_id = Ecto.UUID.generate()

      job = DailyBalanceSnapshotRefreshWorker.new_job(account_id, nil)

      assert job.valid?
      assert Ecto.Changeset.get_field(job, :queue) == "reporting"

      assert Ecto.Changeset.get_field(job, :args) == %{
               "account_id" => account_id,
               "from_date" => "__first_effective_date__"
             }
    end
  end

  describe "enqueue_daily_balance_snapshot_refresh/3" do
    test "enqueues one reporting refresh job" do
      account = insert(:account)

      assert {:ok, %Oban.Job{} = job} =
               Reporting.enqueue_daily_balance_snapshot_refresh(account.id, ~D[2026-03-12])

      assert job.queue == "reporting"

      assert_enqueued(
        worker: DailyBalanceSnapshotRefreshWorker,
        queue: :reporting,
        args: %{
          "account_id" => account.id,
          "from_date" => "2026-03-12"
        }
      )
    end

    test "preserves the oldest requested from_date for an existing pending job" do
      account = insert(:account)

      assert {:ok, %Oban.Job{id: first_job_id}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(account.id, ~D[2026-03-12])

      assert {:ok, %Oban.Job{id: second_job_id, args: args}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(account.id, ~D[2026-03-10])

      assert first_job_id == second_job_id
      assert args["from_date"] == "2026-03-10"

      assert [%Oban.Job{id: persisted_job_id, args: persisted_args}] =
               all_enqueued(worker: DailyBalanceSnapshotRefreshWorker, queue: :reporting)

      assert persisted_job_id == first_job_id
      assert persisted_args["from_date"] == "2026-03-10"
    end

    test "normalizes nil to the earliest-possible sentinel when merging" do
      account = insert(:account)

      assert {:ok, %Oban.Job{id: job_id}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(account.id, ~D[2026-03-12])

      assert {:ok, %Oban.Job{id: same_job_id, args: args}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(account.id, nil)

      assert job_id == same_job_id
      assert args["from_date"] == "__first_effective_date__"
    end
  end

  describe "perform/1" do
    test "discards invalid job args" do
      assert {:discard, "invalid refresh job args"} =
               DailyBalanceSnapshotRefreshWorker.perform(%Oban.Job{args: %{}})
    end

    test "discards stale jobs for deleted accounts" do
      assert {:discard, :account_not_found} =
               DailyBalanceSnapshotRefreshWorker.perform(%Oban.Job{
                 id: 1,
                 args: %{
                   "account_id" => Ecto.UUID.generate(),
                   "from_date" => "__first_effective_date__"
                 }
               })
    end

    test "drains the reporting queue and refreshes snapshots" do
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

      assert {:ok, %Oban.Job{}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(checking.id, nil)

      assert %{failure: 0, success: 1, snoozed: 0} =
               Oban.drain_queue(queue: :reporting, with_scheduled: true)

      assert Reporting.earliest_snapshot_date_for_account(checking) == ~D[2026-03-10]
      assert Reporting.latest_snapshot_date_for_account(checking) == ~D[2026-03-10]
    end

    test "broadcasts a coarse hub freshness refreshed signal after success" do
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

      assert :ok = Reporting.subscribe_hub_freshness()

      assert {:ok, %Oban.Job{}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(checking.id, nil)

      assert %{failure: 0, success: 1, snoozed: 0} =
               Oban.drain_queue(queue: :reporting, with_scheduled: true)

      assert_receive {:reporting_hub_freshness_refreshed,
                      %{
                        entity_id: entity_id,
                        account_id: account_id,
                        refresh_status: :rebuilt,
                        requested_from_date: nil,
                        effective_from_date: ~D[2026-03-10],
                        refreshed_at: refreshed_at
                      }}

      assert entity_id == entity.id
      assert account_id == checking.id
      assert %DateTime{} = refreshed_at
    end

    test "ignores pending sibling jobs from other accounts when merging runtime from_date" do
      entity = insert(:entity)
      checking = insert_account(entity)
      other_account = insert_account(entity, name: "Other checking")

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

      assert {:ok, %Oban.Job{id: checking_job_id}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(checking.id, ~D[2026-03-12])

      assert {:ok, %Oban.Job{}} =
               Reporting.enqueue_daily_balance_snapshot_refresh(other_account.id, nil)

      [checking_job] =
        all_enqueued(worker: DailyBalanceSnapshotRefreshWorker, queue: :reporting)
        |> Enum.filter(&(&1.id == checking_job_id))

      assert :ok = DailyBalanceSnapshotRefreshWorker.perform(checking_job)

      assert Reporting.earliest_snapshot_date_for_account(checking) == ~D[2026-03-12]
      assert Reporting.latest_snapshot_date_for_account(checking) == ~D[2026-03-12]
    end
  end

  defp create_transaction!(entity, date, postings) do
    {:ok, transaction} =
      AurumFinance.Ledger.create_transaction(%{
        entity_id: entity.id,
        date: date,
        description: "Reporting worker test transaction",
        source_type: :manual,
        postings: postings
      })

    transaction
  end
end
