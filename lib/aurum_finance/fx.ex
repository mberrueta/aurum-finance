defmodule AurumFinance.Fx do
  @moduledoc """
  The FX context manages named exchange rate series and their daily rate
  records.

  FX series are global resources (not entity-scoped). Each series links a
  currency pair to a source (`csv_upload` or `provider_module`) and holds daily
  `fx_rate_records` with one rate per date.

  The context exposes CRUD operations, list-page aggregates, compatible-series
  filtering for report-time selection, and a bounded lookup API that finds the
  most recent rate within a 4-day staleness window.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Fx.FxRateRecord
  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Fx.SyncWorker
  alias AurumFinance.Repo

  require Logger

  @staleness_window_days 4

  # ---------------------------------------------------------------------------
  # FX Series CRUD
  # ---------------------------------------------------------------------------

  @doc """
  Lists all FX series with aggregated `row_count` and `last_ingested_date`.

  The aggregates are computed via a subquery join so there is no N+1 per
  series row.

  ## Examples

      iex> AurumFinance.Fx.list_fx_series()
      []
  """
  @spec list_fx_series(keyword()) :: [FxSeries.t()]
  def list_fx_series(opts \\ []) do
    rate_stats =
      from(r in FxRateRecord,
        group_by: r.fx_series_id,
        select: %{
          fx_series_id: r.fx_series_id,
          row_count: count(r.id),
          last_ingested_date: max(r.effective_date)
        }
      )

    FxSeries
    |> join(:left, [s], stats in subquery(rate_stats), on: stats.fx_series_id == s.id)
    |> select_merge([s, stats], %{
      row_count: coalesce(stats.row_count, 0),
      last_ingested_date: stats.last_ingested_date
    })
    |> filter_query(opts)
    |> order_by([s], asc: s.name)
    |> Repo.all()
  end

  @doc """
  Fetches an FX series by id. Raises `Ecto.NoResultsError` if not found.

  ## Examples

      iex> AurumFinance.Fx.get_fx_series!(Ecto.UUID.generate())
      ** (Ecto.NoResultsError)
  """
  @spec get_fx_series!(Ecto.UUID.t()) :: FxSeries.t()
  def get_fx_series!(id) do
    Repo.get!(FxSeries, id)
  end

  @doc """
  Fetches an FX series by slug. Raises `Ecto.NoResultsError` if not found.

  ## Examples

      iex> AurumFinance.Fx.get_fx_series_by_slug!("nonexistent")
      ** (Ecto.NoResultsError)
  """
  @spec get_fx_series_by_slug!(String.t()) :: FxSeries.t()
  def get_fx_series_by_slug!(slug) do
    Repo.get_by!(FxSeries, slug: slug)
  end

  @doc """
  Creates a new FX series.

  Uses `FxSeries.create_changeset/2` which auto-generates the slug and
  enforces identity-field immutability semantics at creation.

  ## Examples

  ```elixir
  {:ok, series} =
    AurumFinance.Fx.create_fx_series(%{
      name: "BCB PTAX USD/BRL",
      base_currency_code: "USD",
      quote_currency_code: "BRL",
      from_date: ~D[2024-01-01],
      source_kind: :provider_module,
      provider_module: "bcb_ptax"
    })
  ```
  """
  @spec create_fx_series(map()) :: {:ok, FxSeries.t()} | {:error, Ecto.Changeset.t()}
  def create_fx_series(attrs) do
    with {:ok, series} <-
           %FxSeries{}
           |> FxSeries.create_changeset(attrs)
           |> Repo.insert() do
      maybe_enqueue_backfill(series)
      {:ok, series}
    end
  end

  @doc """
  Updates an existing FX series.

  Only mutable fields (`name`, `description`, `from_date`, `to_date`) are
  accepted. Identity fields are rejected by the update changeset.

  ## Examples

  ```elixir
  {:ok, updated} = AurumFinance.Fx.update_fx_series(series, %{name: "New name"})
  ```
  """
  @spec update_fx_series(FxSeries.t(), map()) ::
          {:ok, FxSeries.t()} | {:error, Ecto.Changeset.t()}
  def update_fx_series(%FxSeries{} = series, attrs) do
    series
    |> FxSeries.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an FX series only when it has zero rate records.

  Returns `{:error, :has_records}` when the series still contains rate data.

  ## Examples

  ```elixir
  {:ok, deleted} = AurumFinance.Fx.delete_fx_series(empty_series)
  {:error, :has_records} = AurumFinance.Fx.delete_fx_series(series_with_rates)
  ```
  """
  @spec delete_fx_series(FxSeries.t()) ::
          {:ok, FxSeries.t()} | {:error, :has_records} | {:error, Ecto.Changeset.t()}
  def delete_fx_series(%FxSeries{} = series) do
    series.id
    |> count_rate_records()
    |> do_delete(series)
  end

  defp count_rate_records(fx_series_id) do
    FxRateRecord
    |> where([r], r.fx_series_id == ^fx_series_id)
    |> select([r], count(r.id))
    |> Repo.one()
  end

  defp do_delete(0, series), do: Repo.delete(series)
  defp do_delete(_count, _series), do: {:error, :has_records}

  @doc """
  Returns an `FxSeries` changeset for form rendering.

  ## Examples

      iex> changeset = AurumFinance.Fx.change_fx_series(%AurumFinance.Fx.FxSeries{})
      iex> changeset.valid?
      false
  """
  @spec change_fx_series(FxSeries.t(), map()) :: Ecto.Changeset.t()
  def change_fx_series(series, attrs \\ %{})
  def change_fx_series(%FxSeries{id: nil} = series, attrs), do: FxSeries.create_changeset(series, attrs)
  def change_fx_series(%FxSeries{} = series, attrs), do: FxSeries.update_changeset(series, attrs)

  # ---------------------------------------------------------------------------
  # Compatible series filtering
  # ---------------------------------------------------------------------------

  @doc """
  Lists FX series compatible with converting from `account_currency_code` to
  `target_currency_code` as of `as_of_date`.

  A series is compatible when:
  - its currency pair matches the requested conversion in either direction
  - its `from_date <= as_of_date`
  - its `to_date` is nil (still active) or `to_date >= as_of_date`

  Each returned series carries a virtual `inverted?` boolean field indicating
  whether the series pair is inverted relative to the account-to-target
  direction.

  ## Examples

  ```elixir
  compatible =
    AurumFinance.Fx.list_compatible_fx_series("USD", "BRL", ~D[2026-03-20])
  ```
  """
  @spec list_compatible_fx_series(String.t(), String.t(), Date.t()) :: [map()]
  def list_compatible_fx_series(account_currency_code, target_currency_code, as_of_date) do
    direct_query =
      FxSeries
      |> where(
        [s],
        s.base_currency_code == ^account_currency_code and
          s.quote_currency_code == ^target_currency_code
      )
      |> where([s], s.from_date <= ^as_of_date)
      |> where([s], is_nil(s.to_date) or s.to_date >= ^as_of_date)
      |> select_merge([s], %{inverted?: false})

    inverted_query =
      FxSeries
      |> where(
        [s],
        s.base_currency_code == ^target_currency_code and
          s.quote_currency_code == ^account_currency_code
      )
      |> where([s], s.from_date <= ^as_of_date)
      |> where([s], is_nil(s.to_date) or s.to_date >= ^as_of_date)
      |> select_merge([s], %{inverted?: true})

    direct_results = Repo.all(direct_query)
    inverted_results = Repo.all(inverted_query)

    (direct_results ++ inverted_results)
    |> Enum.sort_by(& &1.name)
  end

  # ---------------------------------------------------------------------------
  # FX rate lookup
  # ---------------------------------------------------------------------------

  @doc """
  Looks up the most recent FX rate for a series on or before `as_of_date`,
  bounded by a #{@staleness_window_days}-day staleness window.

  When `invert: true` is passed, the returned `rate_value` is `1 / rate_value`
  computed at runtime. Inversion never modifies persisted data.

  Returns `{:ok, result_map}` with `:rate_value`, `:effective_date`, and
  `:inverted` fields, or `{:error, :rate_not_found}` when no rate exists
  within the staleness window.

  ## Examples

  ```elixir
  {:ok, %{rate_value: rate, effective_date: date, inverted: false}} =
    AurumFinance.Fx.lookup_fx_rate(series.id, ~D[2026-03-20])

  {:ok, %{rate_value: inverted_rate, inverted: true}} =
    AurumFinance.Fx.lookup_fx_rate(series.id, ~D[2026-03-20], invert: true)

  {:error, :rate_not_found} =
    AurumFinance.Fx.lookup_fx_rate(series.id, ~D[2020-01-01])
  ```
  """
  @spec lookup_fx_rate(Ecto.UUID.t(), Date.t(), keyword()) ::
          {:ok, %{rate_value: Decimal.t(), effective_date: Date.t(), inverted: boolean()}}
          | {:error, :rate_not_found}
  def lookup_fx_rate(fx_series_id, as_of_date, opts \\ []) do
    invert = Keyword.get(opts, :invert, false)
    earliest_allowed = Date.add(as_of_date, -@staleness_window_days)

    record =
      FxRateRecord
      |> where([r], r.fx_series_id == ^fx_series_id)
      |> where([r], r.effective_date <= ^as_of_date)
      |> where([r], r.effective_date >= ^earliest_allowed)
      |> order_by([r], desc: r.effective_date)
      |> limit(1)
      |> Repo.one()

    build_lookup_result(record, invert)
  end

  defp build_lookup_result(nil, _invert), do: {:error, :rate_not_found}

  defp build_lookup_result(%FxRateRecord{} = record, true) do
    {:ok,
     %{
       rate_value: Decimal.div(Decimal.new(1), record.rate_value),
       effective_date: record.effective_date,
       inverted: true
     }}
  end

  defp build_lookup_result(%FxRateRecord{} = record, false) do
    {:ok,
     %{
       rate_value: record.rate_value,
       effective_date: record.effective_date,
       inverted: false
     }}
  end

  # ---------------------------------------------------------------------------
  # Rate record upsert
  # ---------------------------------------------------------------------------

  @doc """
  Bulk-upserts rate records for a given FX series.

  Uses `Repo.insert_all/3` with `ON CONFLICT` to replace existing rate values
  when the `(fx_series_id, effective_date)` pair already exists. Returns
  `{:ok, count}` where `count` is the number of rows inserted or updated.

  ## Examples

  ```elixir
  {:ok, 2} =
    AurumFinance.Fx.upsert_rate_records(series.id, [
      %{date: ~D[2024-01-02], value: Decimal.new("5.50")},
      %{date: ~D[2024-01-03], value: Decimal.new("5.55")}
    ])
  ```
  """
  @spec upsert_rate_records(Ecto.UUID.t(), [%{date: Date.t(), value: Decimal.t()}]) ::
          {:ok, non_neg_integer()}
  def upsert_rate_records(_fx_series_id, []), do: {:ok, 0}

  def upsert_rate_records(fx_series_id, rows) when is_list(rows) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    entries =
      Enum.map(rows, fn %{date: date, value: value} ->
        %{
          id: Ecto.UUID.generate(),
          fx_series_id: fx_series_id,
          effective_date: date,
          rate_value: value,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(FxRateRecord, entries,
        on_conflict: {:replace, [:rate_value, :updated_at]},
        conflict_target: [:fx_series_id, :effective_date]
      )

    {:ok, count}
  end

  # ---------------------------------------------------------------------------
  # Sync entrypoints
  # ---------------------------------------------------------------------------

  @doc """
  Enqueues an FX sync job for the given series, covering the range from the
  day after the most recent existing rate record (or `series.from_date` if no
  records exist) through `series.to_date` or today.

  Only meaningful for `provider_module` series.

  ## Examples

  ```elixir
  {:ok, %Oban.Job{}} = AurumFinance.Fx.enqueue_fx_sync(series)
  ```
  """
  @spec enqueue_fx_sync(FxSeries.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue_fx_sync(%FxSeries{source_kind: :provider_module} = series) do
    max_date = max_effective_date(series.id)
    from_date = compute_sync_from_date(series, max_date)
    to_date = series.to_date || Date.utc_today()

    case Date.compare(from_date, to_date) do
      :gt ->
        {:error, :already_up_to_date}

      _ ->
        series.id
        |> SyncWorker.new_job(from_date, to_date)
        |> Oban.insert()
    end
  end

  def enqueue_fx_sync(%FxSeries{source_kind: :csv_upload}) do
    {:error, :not_a_provider_series}
  end

  # ---------------------------------------------------------------------------
  # Private helpers for sync
  # ---------------------------------------------------------------------------

  defp maybe_enqueue_backfill(%FxSeries{source_kind: :provider_module} = series) do
    to_date = series.to_date || Date.utc_today()

    series.id
    |> SyncWorker.new_job(series.from_date, to_date)
    |> Oban.insert()
    |> log_backfill_result(series, to_date)
  end

  defp maybe_enqueue_backfill(%FxSeries{}), do: :noop

  defp log_backfill_result({:ok, job}, series, to_date) do
    Logger.info("FX backfill enqueued for new series",
      event: "fx.backfill.enqueued",
      fx_series_id: series.id,
      from_date: Date.to_iso8601(series.from_date),
      to_date: Date.to_iso8601(to_date)
    )

    {:ok, job}
  end

  defp log_backfill_result({:error, reason}, series, _to_date) do
    Logger.warning("FX backfill enqueue failed",
      event: "fx.backfill.error",
      fx_series_id: series.id,
      reason: inspect(reason)
    )

    {:error, reason}
  end

  defp max_effective_date(fx_series_id) do
    FxRateRecord
    |> where([r], r.fx_series_id == ^fx_series_id)
    |> select([r], max(r.effective_date))
    |> Repo.one()
  end

  defp compute_sync_from_date(series, nil), do: series.from_date

  defp compute_sync_from_date(series, %Date{} = max_date) do
    next = Date.add(max_date, 1)

    case Date.compare(next, series.from_date) do
      :lt -> series.from_date
      _ -> next
    end
  end

  # ---------------------------------------------------------------------------
  # Private filter helpers
  # ---------------------------------------------------------------------------

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:source_kind, source_kind} | rest]) do
    query
    |> where([s], s.source_kind == ^source_kind)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:base_currency_code, code} | rest]) do
    query
    |> where([s], s.base_currency_code == ^code)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:quote_currency_code, code} | rest]) do
    query
    |> where([s], s.quote_currency_code == ^code)
    |> filter_query(rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end
end
