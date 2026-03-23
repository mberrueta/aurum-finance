defmodule AurumFinance.Reporting do
  @moduledoc """
  Reporting projection access, rebuild entrypoints, and report-specific read
  models.

  This context exposes the persisted `daily_balance_snapshots` projection as a
  composable query plus explicit account-scoped rebuild APIs. It intentionally
  does not embed report rendering semantics, FX transforms, or worker/job
  orchestration details. Report-specific read models such as Net Worth live in
  focused modules and are surfaced here as stable context entrypoints. The
  context also exposes an enqueue-only global refresh entrypoint for the
  `/reports` hub.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Entities
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Repo
  alias AurumFinance.Reporting.DailyBalanceSnapshot
  alias AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker
  alias AurumFinance.Reporting.NetWorth
  alias AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1
  alias AurumFinance.Reporting.PubSub
  alias Oban.Job

  @type list_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:entity_id, Ecto.UUID.t()}
          | {:date_from, Date.t()}
          | {:date_to, Date.t()}

  @type net_worth_opt :: {:as_of_date, Date.t()}
  @type net_worth_drilldown_opt :: NetWorth.drilldown_option()
  @type refresh_result :: %{
          status: :queued,
          entity_count: non_neg_integer(),
          included_account_count: non_neg_integer(),
          requested_account_ids: [Ecto.UUID.t()]
        }

  @doc """
  Lists persisted daily balance snapshots.

  Results are ordered by `snapshot_date` ascending and then `account_id`
  ascending so account series stay stable for downstream reporting reads.

  ## Examples

      iex> AurumFinance.Reporting.list_daily_balance_snapshots()
      []
  """
  @spec list_daily_balance_snapshots([list_opt()]) :: [DailyBalanceSnapshot.t()]
  def list_daily_balance_snapshots(opts \\ []) do
    opts
    |> list_daily_balance_snapshots_query()
    |> order_by([snapshot], asc: snapshot.snapshot_date, asc: snapshot.account_id)
    |> Repo.all()
  end

  @doc """
  Refreshes one account's daily balance snapshots synchronously.

  `from_date` is explicit:

  - `nil` bootstraps from the account's first effective ledger date
  - earlier dates clamp to that first effective date
  - later dates return a no-op result and do not delete existing snapshots

  The rebuild always remains forward-cumulative for the requested account.

  ## Examples

      iex> account = %AurumFinance.Ledger.Account{
      ...>   id: Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate()
      ...> }
      iex> {:ok, %{account_id: account_id, status: :rebuilt}} =
      ...>   AurumFinance.Reporting.refresh_daily_balance_snapshots(account, nil)
      iex> account_id == account.id
      true
  """
  @spec refresh_daily_balance_snapshots(Account.t(), Date.t() | nil, [term()]) ::
          {:ok, map()} | {:error, term()}
  def refresh_daily_balance_snapshots(%Account{} = account, from_date, _opts \\ []) do
    V1.rebuild(account, from_date)
  end

  @doc """
  Enqueues an asynchronous daily balance snapshot refresh for one account.

  The enqueue path keeps one pending refresh job per account and preserves the
  oldest requested `from_date`. `nil` is normalized before enqueueing to the
  semantic rebuild-from-first-effective-date sentinel.

  ## Examples

      iex> {:ok, %Oban.Job{worker: worker}} =
      ...>   AurumFinance.Reporting.enqueue_daily_balance_snapshot_refresh(
      ...>     Ecto.UUID.generate(),
      ...>     nil
      ...>   )
      iex> worker
      "Elixir.AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker"
  """
  @spec enqueue_daily_balance_snapshot_refresh(Ecto.UUID.t(), Date.t() | nil, [term()]) ::
          {:ok, Job.t()} | {:error, term()}
  def enqueue_daily_balance_snapshot_refresh(account_id, from_date, _opts \\ [])
      when is_binary(account_id) do
    account_id
    |> DailyBalanceSnapshotRefreshWorker.new_job(from_date)
    |> Oban.insert()
    |> enqueue_refresh_job(from_date)
  end

  @doc """
  Returns the earliest persisted snapshot date for one account.

  ## Examples

      iex> account = %AurumFinance.Ledger.Account{id: Ecto.UUID.generate()}
      iex> AurumFinance.Reporting.earliest_snapshot_date_for_account(account)
      nil
  """
  @spec earliest_snapshot_date_for_account(Account.t()) :: Date.t() | nil
  def earliest_snapshot_date_for_account(%Account{id: account_id}) do
    DailyBalanceSnapshot
    |> where([snapshot], snapshot.account_id == ^account_id)
    |> select([snapshot], min(snapshot.snapshot_date))
    |> Repo.one()
  end

  @doc """
  Returns the latest persisted snapshot date for one account.

  ## Examples

      iex> account = %AurumFinance.Ledger.Account{id: Ecto.UUID.generate()}
      iex> AurumFinance.Reporting.latest_snapshot_date_for_account(account)
      nil
  """
  @spec latest_snapshot_date_for_account(Account.t()) :: Date.t() | nil
  def latest_snapshot_date_for_account(%Account{id: account_id}) do
    DailyBalanceSnapshot
    |> where([snapshot], snapshot.account_id == ^account_id)
    |> select([snapshot], max(snapshot.snapshot_date))
    |> Repo.one()
  end

  @doc """
  Returns the Net Worth V1 reporting read model for the provided entity scope.

  The report is built strictly from the persisted
  `daily_balance_snapshots` projection plus current ledger/account facts. Reads
  never trigger recomputation.

  `as_of_date` defaults to `Date.utc_today/0` in V1.

  ## Examples

      iex> {:ok, report} =
      ...>   AurumFinance.Reporting.net_worth_report([], as_of_date: ~D[2026-03-20])
      iex> report.as_of_date
      ~D[2026-03-20]
      iex> report.account_rows
      []
  """
  @spec net_worth_report([Ecto.UUID.t()], [net_worth_opt()]) ::
          {:ok, map()} | {:error, term()}
  def net_worth_report(entity_ids, opts \\ []) when is_list(entity_ids) do
    NetWorth.get_report(entity_ids, opts)
  end

  @doc """
  Returns paginated drilldown transactions for one Net Worth account row.

  ## Examples

      iex> {:ok, result} =
      ...>   AurumFinance.Reporting.net_worth_drilldown_transactions(
      ...>     Ecto.UUID.generate(),
      ...>     ~D[2026-03-20]
      ...>   )
      iex> result.total_count
      0
  """
  @spec net_worth_drilldown_transactions(Ecto.UUID.t(), Date.t(), [net_worth_drilldown_opt()]) ::
          {:ok, NetWorth.drilldown_report()} | {:error, term()}
  def net_worth_drilldown_transactions(account_id, as_of_date, opts \\ []) do
    NetWorth.drilldown_transactions(account_id, as_of_date, opts)
  end

  @doc """
  Enqueues a global reporting refresh for the current reporting scope.

  This API is intended for the `/reports` hub. It only enqueues refresh work
  for the current Net Worth V1 projection family and never recomputes inline.

  ## Examples

      iex> {:ok, result} = AurumFinance.Reporting.enqueue_hub_refresh()
      iex> result.status
      :queued
  """
  @spec enqueue_hub_refresh() :: {:ok, refresh_result()} | {:error, term()}
  def enqueue_hub_refresh do
    Entities.list_entities()
    |> Enum.map(& &1.id)
    |> enqueue_hub_refresh()
  end

  @doc false
  @spec enqueue_hub_refresh([Ecto.UUID.t()]) :: {:ok, refresh_result()} | {:error, term()}
  def enqueue_hub_refresh(entity_ids) when is_list(entity_ids) do
    entity_ids
    |> included_refresh_accounts()
    |> enqueue_hub_refresh_accounts()
  end

  @doc """
  Subscribes the caller to coarse reporting hub freshness updates.

  Subscribers should treat messages as re-read triggers for the hub, not as a
  source of detailed report state.

  ## Examples

      iex> AurumFinance.Reporting.subscribe_hub_freshness()
      :ok
  """
  @spec subscribe_hub_freshness() :: :ok | {:error, term()}
  def subscribe_hub_freshness do
    PubSub.subscribe_hub_freshness()
  end

  defp list_daily_balance_snapshots_query(opts) do
    DailyBalanceSnapshot
    |> filter_query(opts)
  end

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where([snapshot], snapshot.account_id == ^account_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:entity_id, entity_id} | rest]) do
    query
    |> where([snapshot], snapshot.entity_id == ^entity_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:date_from, %Date{} = date_from} | rest]) do
    query
    |> where([snapshot], snapshot.snapshot_date >= ^date_from)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:date_to, %Date{} = date_to} | rest]) do
    query
    |> where([snapshot], snapshot.snapshot_date <= ^date_to)
    |> filter_query(rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end

  defp enqueue_refresh_job({:ok, %Job{conflict?: false} = job}, _from_date), do: {:ok, job}
  defp enqueue_refresh_job({:error, reason}, _from_date), do: {:error, reason}

  defp enqueue_refresh_job({:ok, %Job{} = existing_job}, from_date) do
    existing_job
    |> merge_refresh_job_from_date(from_date)
    |> update_refresh_job()
  end

  defp merge_refresh_job_from_date(%Job{} = existing_job, from_date) do
    merged_from_date =
      existing_job.args["from_date"]
      |> DailyBalanceSnapshotRefreshWorker.load_from_date()
      |> merge_loaded_from_date(from_date)
      |> DailyBalanceSnapshotRefreshWorker.dump_from_date()

    %{existing_job | args: Map.put(existing_job.args, "from_date", merged_from_date)}
  end

  defp merge_loaded_from_date({:error, _reason}, incoming_from_date), do: incoming_from_date

  defp merge_loaded_from_date({:ok, existing_from_date}, incoming_from_date) do
    oldest_from_date(existing_from_date, incoming_from_date)
  end

  defp update_refresh_job(%Job{} = refresh_job) do
    {updated_count, _rows} =
      Job
      |> where([job], job.id == ^refresh_job.id)
      |> Repo.update_all(set: [args: refresh_job.args])

    update_refresh_job_result(updated_count, refresh_job.id)
  end

  defp oldest_from_date(nil, _other_from_date), do: nil
  defp oldest_from_date(_from_date, nil), do: nil

  defp oldest_from_date(%Date{} = left, %Date{} = right) do
    case Date.compare(left, right) do
      :gt -> right
      _ -> left
    end
  end

  defp included_refresh_accounts([]), do: []

  defp included_refresh_accounts(entity_ids) do
    Account
    |> where([account], account.entity_id in ^entity_ids)
    |> where([account], is_nil(account.archived_at))
    |> where([account], account.management_group == :institution)
    |> where([account], account.account_type in [:asset, :liability])
    |> order_by([account], asc: account.entity_id, asc: account.name, asc: account.id)
    |> Repo.all()
  end

  defp enqueue_hub_refresh_accounts(accounts) do
    with {:ok, requested_account_ids} <- enqueue_hub_refresh_requests(accounts) do
      {:ok,
       %{
         status: :queued,
         entity_count: accounts |> Enum.map(& &1.entity_id) |> Enum.uniq() |> length(),
         included_account_count: length(accounts),
         requested_account_ids: requested_account_ids
       }}
    end
  end

  defp enqueue_hub_refresh_requests(accounts) do
    Enum.reduce_while(accounts, {:ok, []}, fn account, {:ok, requested_account_ids} ->
      case enqueue_daily_balance_snapshot_refresh(account.id, nil) do
        {:ok, _job} ->
          {:cont, {:ok, [account.id | requested_account_ids]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, requested_account_ids} -> {:ok, Enum.reverse(requested_account_ids)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_refresh_job_result(1, job_id), do: {:ok, Repo.get!(Job, job_id)}

  defp update_refresh_job_result(_updated_count, _job_id),
    do: {:error, :refresh_job_update_failed}
end
