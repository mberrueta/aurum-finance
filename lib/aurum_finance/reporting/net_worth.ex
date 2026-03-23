defmodule AurumFinance.Reporting.NetWorth do
  @moduledoc """
  Net Worth V1 reporting read model.

  This module stays deliberately narrow and explainability-first:

  - included accounts are non-archived institution-managed asset/liability accounts
  - the selected balance is the latest snapshot on or before the requested as-of date
  - rows without a qualifying snapshot remain visible as `:no_history`
  - freshness is report-specific and based on later-inserted ledger facts

  Reads never trigger snapshot recomputation.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Repo
  alias AurumFinance.Reporting.DailyBalanceSnapshot

  @decimal_zero Decimal.new("0.0000")

  @type coverage_status :: :exact | :carried_forward | :refreshable_gap | :no_history
  @type freshness_status :: :up_to_date | :outdated
  @type option :: {:as_of_date, Date.t()}
  @type drilldown_option :: {:page, pos_integer()} | {:per_page, pos_integer()}

  @type entity_display :: %{
          id: Ecto.UUID.t(),
          name: String.t()
        }

  @type snapshot_display :: %{
          date: Date.t(),
          computed_at: DateTime.t(),
          closing_balance: Decimal.t(),
          daily_delta: Decimal.t(),
          projection_version: pos_integer()
        }

  @type account_row :: %{
          account_id: Ecto.UUID.t(),
          account_name: String.t(),
          account_type: :asset | :liability,
          currency_code: String.t(),
          entity: entity_display(),
          snapshot: snapshot_display() | nil,
          snapshot_date_used: Date.t() | nil,
          coverage: coverage_status(),
          ledger_balance: Decimal.t() | nil,
          balance: Decimal.t() | nil,
          contributes_to_totals?: boolean()
        }

  @type currency_summary :: %{
          currency_code: String.t(),
          assets: Decimal.t(),
          liabilities: Decimal.t(),
          net_worth: Decimal.t(),
          account_count: non_neg_integer(),
          covered_account_count: non_neg_integer(),
          no_history_count: non_neg_integer()
        }

  @type coverage_counts :: %{
          exact: non_neg_integer(),
          carried_forward: non_neg_integer(),
          refreshable_gap: non_neg_integer(),
          no_history: non_neg_integer()
        }

  @type report :: %{
          as_of_date: Date.t(),
          freshness_status: freshness_status(),
          refresh_suggested?: boolean(),
          empty?: boolean(),
          included_account_count: non_neg_integer(),
          entity_count: non_neg_integer(),
          show_entity_column?: boolean(),
          coverage_counts: coverage_counts(),
          currency_summaries: [currency_summary()],
          account_rows: [account_row()]
        }

  @type drilldown_transaction :: %{
          transaction_id: Ecto.UUID.t(),
          date: Date.t(),
          description: String.t(),
          net_amount: Decimal.t()
        }

  @type drilldown_report :: %{
          transactions: [drilldown_transaction()],
          total_count: non_neg_integer(),
          page: pos_integer(),
          per_page: pos_integer(),
          total_pages: non_neg_integer()
        }

  @doc """
  Returns the Net Worth V1 report for the provided entity scope.

  `:as_of_date` defaults to `Date.utc_today/0` in V1.

  ## Examples

      iex> {:ok, report} =
      ...>   AurumFinance.Reporting.NetWorth.get_report([], as_of_date: ~D[2026-03-20])
      iex> report.as_of_date
      ~D[2026-03-20]
      iex> report.account_rows
      []
  """
  @spec get_report([Ecto.UUID.t()], [option()]) :: {:ok, report()} | {:error, term()}
  def get_report(entity_ids, opts \\ []) when is_list(entity_ids) do
    entity_ids
    |> normalize_entity_ids()
    |> get_report_for_scope(opts)
  end

  @doc """
  Returns paginated transactions that explain one account snapshot balance.

  The drilldown is bounded by the snapshot date used by the report. It groups
  postings by transaction so each row represents one transaction.

  ## Examples

      iex> {:ok, result} =
      ...>   AurumFinance.Reporting.NetWorth.drilldown_transactions(
      ...>     Ecto.UUID.generate(),
      ...>     ~D[2026-03-20]
      ...>   )
      iex> result.total_count
      0
      iex> result.page
      1
      iex> result.per_page
      20
  """
  @spec drilldown_transactions(Ecto.UUID.t(), Date.t(), [drilldown_option()]) ::
          {:ok, drilldown_report()} | {:error, term()}
  def drilldown_transactions(account_id, as_of_date, opts \\ []) do
    with :ok <- validate_account_id(account_id),
         {:ok, %Date{} = as_of_date} <- validate_as_of_date(as_of_date),
         {:ok, page, per_page} <- resolve_drilldown_pagination(opts) do
      page_result =
        account_id
        |> drilldown_transactions_query(as_of_date)
        |> order_by(
          [posting, transaction, _account, _entity],
          desc: transaction.date,
          desc: transaction.inserted_at,
          desc: transaction.id
        )
        |> Repo.paginate(page: page, page_size: per_page)

      {:ok,
       %{
         transactions: page_result.entries,
         total_count: page_result.total_entries,
         page: page_result.page_number,
         per_page: page_result.page_size,
         total_pages: page_result.total_pages
       }}
    end
  end

  defp get_report_for_scope([], opts) do
    opts
    |> resolve_as_of_date()
    |> empty_report()
    |> then(&{:ok, &1})
  end

  defp get_report_for_scope(entity_ids, opts) do
    as_of_date = resolve_as_of_date(opts)
    rows = Repo.all(account_rows_query(entity_ids, as_of_date))
    stale_ids = stale_account_ids(rows, as_of_date)

    entity_ids
    |> build_account_rows(rows, as_of_date, stale_ids)
    |> build_report(as_of_date)
    |> then(&{:ok, &1})
  end

  defp normalize_entity_ids(entity_ids) do
    entity_ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp resolve_as_of_date(opts) when is_list(opts) do
    opts
    |> Keyword.get(:as_of_date)
    |> resolve_as_of_date()
  end

  defp resolve_as_of_date(nil), do: Date.utc_today()
  defp resolve_as_of_date(%Date{} = date), do: date

  defp resolve_as_of_date(other) do
    raise ArgumentError, "expected :as_of_date to be a Date, got: #{inspect(other)}"
  end

  defp empty_report(%Date{} = as_of_date) do
    %{
      as_of_date: as_of_date,
      freshness_status: :up_to_date,
      refresh_suggested?: false,
      empty?: true,
      included_account_count: 0,
      entity_count: 0,
      show_entity_column?: false,
      coverage_counts: empty_coverage_counts(),
      currency_summaries: [],
      account_rows: []
    }
  end

  defp build_account_rows(entity_ids, rows, as_of_date, stale_ids) do
    stale_ids = MapSet.new(stale_ids)
    entity_ids_set = MapSet.new(entity_ids)

    rows
    |> Enum.map(&build_account_row(&1, as_of_date, stale_ids))
    |> Enum.sort_by(fn row ->
      {row.currency_code, row.entity.name, row.account_name}
    end)
    |> then(fn rows -> {rows, MapSet.size(entity_ids_set)} end)
  end

  defp build_account_row(row, as_of_date, stale_ids) do
    coverage = coverage_status(row, as_of_date, stale_ids)
    ledger_balance = row.snapshot_closing_balance

    %{
      account_id: row.account_id,
      account_name: row.account_name,
      account_type: row.account_type,
      currency_code: row.currency_code,
      entity: %{
        id: row.entity_id,
        name: row.entity_name
      },
      snapshot: snapshot_display(row),
      snapshot_date_used: row.snapshot_date,
      coverage: coverage,
      ledger_balance: ledger_balance,
      balance: presented_balance(coverage, row.account_type, ledger_balance),
      contributes_to_totals?: coverage != :no_history
    }
  end

  defp snapshot_display(%{snapshot_date: nil}), do: nil

  defp snapshot_display(row) do
    %{
      date: row.snapshot_date,
      computed_at: row.snapshot_computed_at,
      closing_balance: row.snapshot_closing_balance,
      daily_delta: row.snapshot_daily_delta,
      projection_version: row.snapshot_projection_version
    }
  end

  defp coverage_status(%{snapshot_date: nil}, _as_of_date, _stale_ids), do: :no_history

  defp coverage_status(row, as_of_date, stale_ids) do
    cond do
      MapSet.member?(stale_ids, row.account_id) -> :refreshable_gap
      Date.compare(row.snapshot_date, as_of_date) == :eq -> :exact
      true -> :carried_forward
    end
  end

  defp presented_balance(:no_history, _account_type, _ledger_balance), do: nil
  defp presented_balance(_coverage, :liability, %Decimal{} = balance), do: Decimal.abs(balance)
  defp presented_balance(_coverage, _account_type, %Decimal{} = balance), do: balance
  defp presented_balance(_coverage, _account_type, nil), do: nil

  defp build_report({account_rows, entity_count}, as_of_date) do
    coverage_counts = build_coverage_counts(account_rows)

    %{
      as_of_date: as_of_date,
      freshness_status: freshness_status(coverage_counts),
      refresh_suggested?: coverage_counts.refreshable_gap > 0,
      empty?: account_rows == [],
      included_account_count: length(account_rows),
      entity_count: entity_count,
      show_entity_column?: entity_count > 1,
      coverage_counts: coverage_counts,
      currency_summaries: build_currency_summaries(account_rows),
      account_rows: account_rows
    }
  end

  defp build_coverage_counts(account_rows) do
    Enum.reduce(account_rows, empty_coverage_counts(), fn row, acc ->
      Map.update!(acc, row.coverage, &(&1 + 1))
    end)
  end

  defp empty_coverage_counts do
    %{exact: 0, carried_forward: 0, refreshable_gap: 0, no_history: 0}
  end

  defp freshness_status(%{refreshable_gap: 0}), do: :up_to_date
  defp freshness_status(%{refreshable_gap: _count}), do: :outdated

  defp build_currency_summaries(account_rows) do
    account_rows
    |> Enum.reduce(%{}, &accumulate_currency_summary/2)
    |> Map.values()
    |> Enum.sort_by(& &1.currency_code)
  end

  defp accumulate_currency_summary(row, acc) do
    summary = Map.get(acc, row.currency_code, empty_currency_summary(row.currency_code))
    Map.put(acc, row.currency_code, update_currency_summary(summary, row))
  end

  defp update_currency_summary(summary, %{coverage: :no_history}) do
    %{
      summary
      | account_count: summary.account_count + 1,
        no_history_count: summary.no_history_count + 1
    }
  end

  defp update_currency_summary(summary, %{account_type: :asset, balance: balance}) do
    summary
    |> Map.update!(:assets, &Decimal.add(&1, balance))
    |> bump_covered_summary_counts()
    |> put_net_worth()
  end

  defp update_currency_summary(summary, %{account_type: :liability, balance: balance}) do
    summary
    |> Map.update!(:liabilities, &Decimal.add(&1, balance))
    |> bump_covered_summary_counts()
    |> put_net_worth()
  end

  defp bump_covered_summary_counts(summary) do
    %{
      summary
      | account_count: summary.account_count + 1,
        covered_account_count: summary.covered_account_count + 1
    }
  end

  defp put_net_worth(summary) do
    %{summary | net_worth: Decimal.sub(summary.assets, summary.liabilities)}
  end

  defp empty_currency_summary(currency_code) do
    %{
      currency_code: currency_code,
      assets: @decimal_zero,
      liabilities: @decimal_zero,
      net_worth: @decimal_zero,
      account_count: 0,
      covered_account_count: 0,
      no_history_count: 0
    }
  end

  defp validate_account_id(account_id) when is_binary(account_id), do: :ok
  defp validate_account_id(account_id), do: {:error, {:invalid_account_id, account_id}}

  defp validate_as_of_date(%Date{} = date), do: {:ok, date}
  defp validate_as_of_date(other), do: {:error, {:invalid_as_of_date, other}}

  defp resolve_drilldown_pagination(opts) when is_list(opts) do
    with {:ok, page} <- normalize_positive_integer(Keyword.get(opts, :page, 1), :page),
         {:ok, per_page} <-
           normalize_positive_integer(Keyword.get(opts, :per_page, 20), :per_page) do
      {:ok, page, per_page}
    end
  end

  defp resolve_drilldown_pagination(other), do: {:error, {:invalid_options, other}}

  defp normalize_positive_integer(value, _key) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_positive_integer(value, key), do: {:error, {:invalid_option, key, value}}

  defp drilldown_transactions_query(account_id, %Date{} = as_of_date) do
    from posting in Posting,
      join: transaction in Transaction,
      on: transaction.id == posting.transaction_id,
      join: account in Account,
      on: account.id == posting.account_id and account.entity_id == transaction.entity_id,
      join: entity in Entity,
      on: entity.id == account.entity_id and entity.id == transaction.entity_id,
      where: posting.account_id == ^account_id,
      where: transaction.date <= ^as_of_date,
      group_by: [
        transaction.id,
        transaction.date,
        transaction.description,
        transaction.inserted_at
      ],
      select: %{
        transaction_id: transaction.id,
        date: transaction.date,
        description: transaction.description,
        net_amount: sum(posting.amount)
      }
  end

  defp account_rows_query(entity_ids, %Date{} = as_of_date) do
    latest_snapshot_query =
      from snapshot in DailyBalanceSnapshot,
        where:
          snapshot.account_id == parent_as(:account).id and
            snapshot.snapshot_date <= ^as_of_date,
        order_by: [desc: snapshot.snapshot_date, desc: snapshot.computed_at, desc: snapshot.id],
        limit: 1,
        select: %{
          snapshot_date: snapshot.snapshot_date,
          snapshot_computed_at: snapshot.computed_at,
          snapshot_closing_balance: snapshot.closing_balance,
          snapshot_daily_delta: snapshot.daily_delta,
          snapshot_projection_version: snapshot.projection_version
        }

    from account in Account,
      as: :account,
      join: entity in Entity,
      on: entity.id == account.entity_id,
      where: account.entity_id in ^entity_ids,
      where: is_nil(account.archived_at),
      where: account.management_group == :institution,
      where: account.account_type in [:asset, :liability],
      left_lateral_join: snapshot in subquery(latest_snapshot_query),
      on: true,
      order_by: [asc: account.currency_code, asc: entity.name, asc: account.name, asc: account.id],
      select: %{
        account_id: account.id,
        account_name: account.name,
        account_type: account.account_type,
        currency_code: account.currency_code,
        entity_id: entity.id,
        entity_name: entity.name,
        snapshot_date: snapshot.snapshot_date,
        snapshot_computed_at: snapshot.snapshot_computed_at,
        snapshot_closing_balance: snapshot.snapshot_closing_balance,
        snapshot_daily_delta: snapshot.snapshot_daily_delta,
        snapshot_projection_version: snapshot.snapshot_projection_version
      }
  end

  defp stale_account_ids(rows, %Date{} = as_of_date) do
    rows
    |> stale_snapshot_cutoffs()
    |> stale_account_ids_for_cutoffs(as_of_date)
  end

  defp stale_snapshot_cutoffs(rows) do
    Enum.reduce(rows, [], fn row, acc ->
      case row.snapshot_computed_at do
        %DateTime{} = computed_at -> [{row.account_id, computed_at} | acc]
        nil -> acc
      end
    end)
  end

  defp stale_account_ids_for_cutoffs([], _as_of_date), do: []

  defp stale_account_ids_for_cutoffs(account_cutoffs, %Date{} = as_of_date) do
    inserted_after_snapshot =
      Enum.reduce(account_cutoffs, false, fn {account_id, snapshot_computed_at}, dynamic ->
        dynamic(
          [posting, transaction],
          ^dynamic or
            (posting.account_id == ^account_id and transaction.inserted_at > ^snapshot_computed_at)
        )
      end)

    Posting
    |> join(:inner, [posting], transaction in Transaction,
      on: transaction.id == posting.transaction_id
    )
    |> where([_posting, transaction], transaction.date <= ^as_of_date)
    |> where(^inserted_after_snapshot)
    |> distinct([posting], posting.account_id)
    |> select([posting, _transaction], posting.account_id)
    |> Repo.all()
  end
end
