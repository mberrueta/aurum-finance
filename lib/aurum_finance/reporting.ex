defmodule AurumFinance.Reporting do
  @moduledoc """
  Reporting projection access and rebuild entrypoints.

  This context exposes the persisted `daily_balance_snapshots` projection as a
  composable query plus explicit account-scoped rebuild APIs. It intentionally
  does not embed report rendering semantics, FX transforms, or worker/job
  orchestration details.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Ledger.Account
  alias AurumFinance.Repo
  alias AurumFinance.Reporting.DailyBalanceSnapshot
  alias AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1

  @type list_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:entity_id, Ecto.UUID.t()}
          | {:date_from, Date.t()}
          | {:date_to, Date.t()}

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
end
