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
  alias AurumFinance.Repo

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
    %FxSeries{}
    |> FxSeries.create_changeset(attrs)
    |> Repo.insert()
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
    record_count =
      FxRateRecord
      |> where([r], r.fx_series_id == ^series.id)
      |> select([r], count(r.id))
      |> Repo.one()

    if record_count > 0 do
      {:error, :has_records}
    else
      Repo.delete(series)
    end
  end

  @doc """
  Returns an `FxSeries` changeset for form rendering.

  ## Examples

      iex> changeset = AurumFinance.Fx.change_fx_series(%AurumFinance.Fx.FxSeries{})
      iex> changeset.valid?
      false
  """
  @spec change_fx_series(FxSeries.t(), map()) :: Ecto.Changeset.t()
  def change_fx_series(%FxSeries{} = series, attrs \\ %{}) do
    if series.id do
      FxSeries.update_changeset(series, attrs)
    else
      FxSeries.create_changeset(series, attrs)
    end
  end

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
