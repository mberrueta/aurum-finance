defmodule AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1 do
  @moduledoc """
  Version 1 of the daily balance snapshot projection contract.

  This module intentionally stays minimal in the first PR. The reporting layer
  can call `V1` directly while there is only one projection version, and the
  persisted `projection_version` field preserves row-level auditability for a
  future versioned rollout.

  Rebuild/runtime semantics are owned by the projection engine and reporting
  context, not by this contract module.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Repo
  alias AurumFinance.Reporting.DailyBalanceSnapshot

  @projection_version 1
  @decimal_zero Decimal.new("0.0000")

  @doc """
  Returns the persisted projection version for this contract.

  ## Examples

      iex> AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1.projection_version()
      1
  """
  @spec projection_version() :: pos_integer()
  def projection_version, do: @projection_version

  @doc """
  Rebuilds the V1 snapshot series for one account.

  The rebuild is forward-cumulative and replaces the full persisted range from
  the resolved effective start date onward. When `from_date` is nil or older
  than the account's first effective date, the rebuild starts at that first
  effective date. When `from_date` is later than the last effective date, the
  rebuild is a no-op and keeps existing rows untouched.

  If the account no longer has any effective ledger facts, all stale snapshots
  for that account are deleted.

  ## Examples

      iex> account = %AurumFinance.Ledger.Account{
      ...>   id: Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate()
      ...> }
      iex> {:ok, result} =
      ...>   AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1.rebuild(
      ...>     account,
      ...>     nil
      ...>   )
      iex> is_map(result)
      true
  """
  @spec rebuild(Account.t(), Date.t() | nil) :: {:ok, map()} | {:error, term()}
  def rebuild(%Account{} = account, from_date \\ nil) do
    account.id
    |> effective_date_range_for_account()
    |> rebuild_with_effective_range(account, from_date)
  end

  @doc """
  Builds a snapshot changeset for one account using V1-derived fields.

  `entity_id`, `account_id`, and `projection_version` are derived from the
  resolved account plus the module version, so caller-provided values for those
  keys are ignored.

  ## Examples

      iex> account = %AurumFinance.Ledger.Account{
      ...>   id: Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate()
      ...> }
      iex> changeset =
      ...>   AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1.changeset(
      ...>     %AurumFinance.Reporting.DailyBalanceSnapshot{},
      ...>     account,
      ...>     %{
      ...>       snapshot_date: ~D[2026-03-10],
      ...>       closing_balance: Decimal.new("100.0000"),
      ...>       daily_delta: Decimal.new("5.0000"),
      ...>       computed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      ...>     }
      ...>   )
      iex> Ecto.Changeset.get_field(changeset, :projection_version)
      1
  """
  @spec changeset(DailyBalanceSnapshot.t(), Account.t(), map()) :: Ecto.Changeset.t()
  def changeset(snapshot \\ %DailyBalanceSnapshot{}, %Account{} = account, attrs) do
    attrs
    |> normalize_attrs()
    |> Map.put(:account_id, account.id)
    |> Map.put(:entity_id, account.entity_id)
    |> Map.put(:projection_version, projection_version())
    |> then(&DailyBalanceSnapshot.changeset(snapshot, &1))
  end

  defp normalize_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.drop([
      :account_id,
      :entity_id,
      :projection_version,
      "account_id",
      "entity_id",
      "projection_version"
    ])
  end

  defp rebuild_for_effective_range(
         %Account{} = account,
         first_effective_date,
         last_effective_date,
         from_date
       ) do
    first_effective_date
    |> normalize_effective_from_date(last_effective_date, from_date)
    |> rebuild_from_effective_date(account, last_effective_date)
  end

  defp rebuild_with_effective_range(nil, %Account{} = account, _from_date) do
    {:ok,
     %{
       account_id: account.id,
       deleted_count: delete_all_snapshots_for_account(account.id),
       inserted_count: 0,
       effective_from_date: nil,
       last_effective_date: nil,
       status: :deleted_stale
     }}
  end

  defp rebuild_with_effective_range(
         {first_effective_date, last_effective_date},
         %Account{} = account,
         from_date
       ) do
    rebuild_for_effective_range(
      account,
      first_effective_date,
      last_effective_date,
      from_date
    )
  end

  defp rebuild_from_effective_date(
         {:noop, effective_from_date},
         %Account{} = account,
         last_effective_date
       ) do
    {:ok,
     %{
       account_id: account.id,
       deleted_count: 0,
       inserted_count: 0,
       effective_from_date: effective_from_date,
       last_effective_date: last_effective_date,
       status: :noop
     }}
  end

  defp rebuild_from_effective_date(
         {:ok, effective_from_date},
         %Account{} = account,
         last_effective_date
       ) do
    prior_closing_balance =
      closing_balance_before_date(account.id, effective_from_date)

    computed_at = utc_now()

    snapshot_entries =
      account
      |> daily_deltas_by_date(effective_from_date, last_effective_date)
      |> generate_snapshot_entries(
        account,
        effective_from_date,
        last_effective_date,
        prior_closing_balance,
        computed_at
      )

    replace_snapshot_range(account.id, effective_from_date, snapshot_entries)
    |> normalize_replace_result(account.id, effective_from_date, last_effective_date)
  end

  defp normalize_effective_from_date(first_effective_date, _last_effective_date, nil) do
    {:ok, first_effective_date}
  end

  defp normalize_effective_from_date(
         first_effective_date,
         last_effective_date,
         %Date{} = from_date
       ) do
    cond do
      Date.compare(from_date, first_effective_date) == :lt ->
        {:ok, first_effective_date}

      Date.compare(from_date, last_effective_date) == :gt ->
        {:noop, from_date}

      true ->
        {:ok, from_date}
    end
  end

  defp effective_date_range_for_account(account_id) do
    Posting
    |> join(:inner, [posting], transaction in Transaction,
      on: transaction.id == posting.transaction_id
    )
    |> where([posting], posting.account_id == ^account_id)
    |> select([_posting, transaction], {min(transaction.date), max(transaction.date)})
    |> Repo.one()
    |> normalize_effective_date_range()
  end

  defp normalize_effective_date_range({nil, nil}), do: nil

  defp normalize_effective_date_range({%Date{} = first_date, %Date{} = last_date}),
    do: {first_date, last_date}

  defp daily_deltas_by_date(%Account{id: account_id}, effective_from_date, last_effective_date) do
    account_id
    |> effective_movement_query(effective_from_date, last_effective_date)
    |> Repo.all()
    |> Map.new(fn %{snapshot_date: snapshot_date, daily_delta: daily_delta} ->
      {snapshot_date, daily_delta}
    end)
  end

  defp effective_movement_query(account_id, effective_from_date, last_effective_date) do
    Posting
    |> join(:inner, [posting], transaction in Transaction,
      on: transaction.id == posting.transaction_id
    )
    |> where([posting], posting.account_id == ^account_id)
    |> where([_posting, transaction], transaction.date >= ^effective_from_date)
    |> where([_posting, transaction], transaction.date <= ^last_effective_date)
    |> group_by([_posting, transaction], transaction.date)
    |> select([posting, transaction], %{
      snapshot_date: transaction.date,
      daily_delta: sum(posting.amount)
    })
  end

  defp closing_balance_before_date(account_id, effective_from_date) do
    Posting
    |> join(:inner, [posting], transaction in Transaction,
      on: transaction.id == posting.transaction_id
    )
    |> where([posting], posting.account_id == ^account_id)
    |> where([_posting, transaction], transaction.date < ^effective_from_date)
    |> select([posting], sum(posting.amount))
    |> Repo.one()
    |> normalize_decimal()
  end

  defp generate_snapshot_entries(
         daily_deltas_by_date,
         %Account{} = account,
         effective_from_date,
         last_effective_date,
         prior_closing_balance,
         computed_at
       ) do
    effective_from_date
    |> Date.range(last_effective_date)
    |> Enum.map_reduce(prior_closing_balance, fn snapshot_date, closing_balance ->
      daily_delta =
        daily_deltas_by_date
        |> Map.get(snapshot_date, @decimal_zero)
        |> normalize_decimal()

      next_closing_balance = Decimal.add(closing_balance, daily_delta)

      snapshot_entry =
        snapshot_entry(
          account,
          snapshot_date,
          next_closing_balance,
          daily_delta,
          computed_at
        )

      {snapshot_entry, next_closing_balance}
    end)
    |> elem(0)
  end

  defp snapshot_entry(account, snapshot_date, closing_balance, daily_delta, computed_at) do
    now = computed_at

    %{
      account_id: account.id,
      entity_id: account.entity_id,
      snapshot_date: snapshot_date,
      closing_balance: closing_balance,
      daily_delta: daily_delta,
      computed_at: computed_at,
      projection_version: projection_version(),
      inserted_at: now,
      updated_at: now
    }
  end

  defp replace_snapshot_range(account_id, effective_from_date, snapshot_entries) do
    Repo.transaction(fn ->
      deleted_count =
        DailyBalanceSnapshot
        |> where([snapshot], snapshot.account_id == ^account_id)
        |> where([snapshot], snapshot.snapshot_date >= ^effective_from_date)
        |> Repo.delete_all()
        |> elem(0)

      inserted_count =
        case snapshot_entries do
          [] ->
            0

          entries ->
            Repo.insert_all(DailyBalanceSnapshot, entries)
            |> elem(0)
        end

      %{deleted_count: deleted_count, inserted_count: inserted_count}
    end)
  end

  defp normalize_replace_result(
         {:ok, %{deleted_count: deleted_count, inserted_count: inserted_count}},
         account_id,
         effective_from_date,
         last_effective_date
       ) do
    {:ok,
     %{
       account_id: account_id,
       deleted_count: deleted_count,
       inserted_count: inserted_count,
       effective_from_date: effective_from_date,
       last_effective_date: last_effective_date,
       status: :rebuilt
     }}
  end

  defp normalize_replace_result(
         {:error, reason},
         _account_id,
         _effective_from_date,
         _last_effective_date
       ) do
    {:error, reason}
  end

  defp delete_all_snapshots_for_account(account_id) do
    DailyBalanceSnapshot
    |> where([snapshot], snapshot.account_id == ^account_id)
    |> Repo.delete_all()
    |> elem(0)
  end

  defp normalize_decimal(nil), do: @decimal_zero
  defp normalize_decimal(%Decimal{} = decimal), do: decimal

  defp utc_now do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end
end
