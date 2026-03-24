defmodule AurumFinance.Fx.GlobalSyncScheduler do
  @moduledoc """
  GenServer that runs a daily scan of all provider-backed FX series and
  enqueues sync jobs for any series that are stale (i.e., their most recent
  rate record is before yesterday or they have no records at all).

  On startup, an immediate `:run` message is scheduled to catch up after
  deploys or restarts. Subsequent runs are scheduled every 24 hours.

  ## Design note

  This uses a GenServer with `Process.send_after/3` rather than
  `Oban.Plugins.Cron` because the project does not currently configure that
  plugin. If `Oban.Plugins.Cron` is added later, this scheduler could be
  replaced by a cron entry. See config/config.exs for the Oban plugin list.
  """

  use GenServer

  import Ecto.Query, warn: false

  alias AurumFinance.Fx.FxRateRecord
  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Fx.SyncWorker
  alias AurumFinance.Repo

  require Logger

  @daily_interval_ms :timer.hours(24)

  # ---------------------------------------------------------------------------
  # Client API
  # ---------------------------------------------------------------------------

  @doc false
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(_opts) do
    schedule_run(0)
    {:ok, %{}}
  end

  @impl GenServer
  def handle_info(:run, state) do
    run_scan()
    schedule_run(@daily_interval_ms)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp schedule_run(delay_ms) do
    Process.send_after(self(), :run, delay_ms)
  end

  defp run_scan do
    yesterday = Date.add(Date.utc_today(), -1)

    yesterday
    |> find_stale_series()
    |> enqueue_stale_jobs()
  end

  defp enqueue_stale_jobs([]) do
    Logger.debug("FX global sync: no stale series found", event: "fx.scheduler.noop")
  end

  defp enqueue_stale_jobs(stale_series) do
    jobs =
      Enum.map(stale_series, fn {series, max_date} ->
        from_date = compute_from_date(series, max_date)
        to_date = series.to_date || Date.utc_today()
        SyncWorker.new_job(series.id, from_date, to_date)
      end)

    {:ok, inserted} = Oban.insert_all(jobs)

    Logger.info("FX global sync: enqueued stale series",
      event: "fx.scheduler.enqueued",
      series_count: length(inserted)
    )
  end

  defp find_stale_series(yesterday) do
    # Find all provider_module series that are still active
    # (to_date is nil or >= yesterday)
    max_dates =
      from(r in FxRateRecord,
        group_by: r.fx_series_id,
        select: {r.fx_series_id, max(r.effective_date)}
      )

    series_with_max =
      FxSeries
      |> where([s], s.source_kind == :provider_module)
      |> where([s], is_nil(s.to_date) or s.to_date >= ^yesterday)
      |> join(:left, [s], m in subquery(max_dates), on: m.fx_series_id == s.id)
      |> select([s, m], {s, m.effective_date})
      |> Repo.all()

    Enum.filter(series_with_max, fn {_series, max_date} ->
      is_nil(max_date) or Date.compare(max_date, yesterday) == :lt
    end)
  end

  defp compute_from_date(series, nil), do: series.from_date

  defp compute_from_date(series, %Date{} = max_date) do
    next = Date.add(max_date, 1)

    case Date.compare(next, series.from_date) do
      :lt -> series.from_date
      _ -> next
    end
  end
end
