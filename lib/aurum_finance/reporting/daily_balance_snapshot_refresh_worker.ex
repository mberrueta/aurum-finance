defmodule AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker do
  @moduledoc """
  Oban worker responsible for asynchronous daily balance snapshot refreshes.

  Successful refresh completions emit a narrow reporting freshness signal via
  `AurumFinance.Reporting.PubSub`. Consumers should re-read hub/report state
  after receiving that signal instead of deriving row-level detail from it.
  """

  use Oban.Worker,
    queue: :reporting,
    max_attempts: 5,
    unique: [
      period: :infinity,
      fields: [:worker, :queue, :args],
      keys: [:account_id],
      states: [:available, :scheduled, :retryable]
    ]

  import Ecto.Query, warn: false

  alias AurumFinance.Ledger.Account
  alias AurumFinance.Repo
  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.PubSub, as: ReportingPubSub

  @rebuild_from_first_effective_date "__first_effective_date__"

  @doc """
  Builds a new Oban job for one account refresh request.

  `from_date` is normalized before enqueueing so `nil` is persisted as the
  semantic rebuild-from-bootstrap sentinel instead of a missing arg.

  ## Examples

      iex> %Oban.Job{args: %{"account_id" => _, "from_date" => _}} =
      ...>   AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker.new_job(
      ...>     Ecto.UUID.generate(),
      ...>     nil
      ...>   )
  """
  @spec new_job(Ecto.UUID.t(), Date.t() | nil) :: Oban.Job.changeset()
  def new_job(account_id, from_date) when is_binary(account_id) do
    %{
      "account_id" => account_id,
      "from_date" => dump_from_date(from_date)
    }
    |> new(schedule_in: 600)
  end

  @impl Oban.Worker
  def perform(
        %Oban.Job{args: %{"account_id" => account_id, "from_date" => dumped_from_date}} = job
      ) do
    account_id
    |> load_account()
    |> perform_with_account(job, dumped_from_date)
  end

  def perform(%Oban.Job{}), do: {:discard, "invalid refresh job args"}

  @doc false
  @spec dump_from_date(Date.t() | nil) :: String.t()
  def dump_from_date(nil), do: @rebuild_from_first_effective_date
  def dump_from_date(%Date{} = from_date), do: Date.to_iso8601(from_date)

  @doc false
  @spec load_from_date(String.t()) :: {:ok, Date.t() | nil} | {:error, term()}
  def load_from_date(@rebuild_from_first_effective_date), do: {:ok, nil}

  def load_from_date(from_date) when is_binary(from_date) do
    Date.from_iso8601(from_date)
  end

  defp load_account(account_id), do: Repo.get(Account, account_id)

  defp perform_with_account(nil, _job, _dumped_from_date), do: {:discard, :account_not_found}

  defp perform_with_account(%Account{} = account, %Oban.Job{} = job, dumped_from_date) do
    dumped_from_date
    |> load_runtime_from_date(job.id, account.id)
    |> perform_refresh(account)
  end

  defp load_runtime_from_date(dumped_from_date, job_id, account_id) do
    dumped_from_date
    |> load_from_date()
    |> merge_runtime_from_date(job_id, account_id)
  end

  defp merge_runtime_from_date({:error, reason}, _job_id, _account_id), do: {:error, reason}

  defp merge_runtime_from_date({:ok, requested_from_date}, job_id, account_id) do
    job_id
    |> oldest_sibling_from_date(account_id)
    |> merge_requested_from_date(requested_from_date)
    |> then(&{:ok, &1})
  end

  defp oldest_sibling_from_date(job_id, account_id) do
    Oban.Job
    |> where([job], job.worker == ^to_string(__MODULE__))
    |> where([job], job.queue == "reporting")
    |> where([job], job.state in ["available", "scheduled", "retryable"])
    |> where([job], job.id != ^job_id)
    |> where([job], fragment("?->>'account_id' = ?", job.args, ^account_id))
    |> select([job], job.args["from_date"])
    |> Repo.all()
    |> Enum.reduce(:unset, fn dumped_from_date, acc ->
      dumped_from_date
      |> load_from_date()
      |> merge_loaded_from_date(acc)
    end)
  end

  defp merge_loaded_from_date({:ok, from_date}, :unset), do: from_date
  defp merge_loaded_from_date({:ok, from_date}, acc), do: oldest_from_date(acc, from_date)
  defp merge_loaded_from_date({:error, _reason}, acc), do: acc

  defp merge_requested_from_date(:unset, requested_from_date), do: requested_from_date

  defp merge_requested_from_date(oldest_sibling_from_date, requested_from_date),
    do: oldest_from_date(oldest_sibling_from_date, requested_from_date)

  defp oldest_from_date(nil, _other_from_date), do: nil
  defp oldest_from_date(_from_date, nil), do: nil

  defp oldest_from_date(%Date{} = left, %Date{} = right) do
    case Date.compare(left, right) do
      :gt -> right
      _ -> left
    end
  end

  defp perform_refresh({:error, _reason}, _account), do: {:discard, "invalid refresh job args"}

  defp perform_refresh({:ok, from_date}, %Account{} = account) do
    account
    |> Reporting.refresh_daily_balance_snapshots(from_date)
    |> perform_result(account, from_date)
  end

  defp perform_result({:ok, result}, %Account{} = account, requested_from_date) do
    ReportingPubSub.broadcast_hub_freshness_refreshed(%{
      entity_id: account.entity_id,
      account_id: account.id,
      refresh_status: result.status,
      requested_from_date: requested_from_date,
      effective_from_date: Map.get(result, :effective_from_date),
      refreshed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    })

    :ok
  end

  defp perform_result({:error, reason}, %Account{}, _requested_from_date), do: {:error, reason}
end
