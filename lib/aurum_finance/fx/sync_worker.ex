defmodule AurumFinance.Fx.SyncWorker do
  @moduledoc """
  Oban worker that fetches exchange rates from an external provider and
  upserts them into the `fx_rate_records` table.

  Job args: `%{"fx_series_id" => id, "from_date" => "YYYY-MM-DD", "to_date" => "YYYY-MM-DD"}`

  The worker loads the series, delegates to the appropriate provider via the
  `Provider` registry, and bulk-upserts returned rows. On provider failure the
  job returns `{:error, reason}` to trigger Oban retry with backoff.

  Uniqueness is scoped to `(fx_series_id, from_date, to_date)` with a 60-second
  period to prevent duplicate enqueue races.
  """

  use Oban.Worker,
    queue: :fx,
    max_attempts: 5,
    unique: [
      period: 60,
      fields: [:worker, :queue, :args],
      keys: [:fx_series_id, :from_date, :to_date],
      states: [:available, :scheduled, :retryable]
    ]

  alias AurumFinance.Fx
  alias AurumFinance.Fx.Provider

  require Logger

  @doc """
  Builds a new Oban job changeset for syncing a date range for an FX series.

  ## Examples

      iex> job = AurumFinance.Fx.SyncWorker.new_job(Ecto.UUID.generate(), ~D[2024-01-01], ~D[2024-01-31])
      iex> %Oban.Job{args: %{"fx_series_id" => _, "from_date" => "2024-01-01", "to_date" => "2024-01-31"}} = job
  """
  @spec new_job(Ecto.UUID.t(), Date.t(), Date.t()) :: Oban.Job.changeset()
  def new_job(fx_series_id, %Date{} = from_date, %Date{} = to_date) do
    %{
      "fx_series_id" => fx_series_id,
      "from_date" => Date.to_iso8601(from_date),
      "to_date" => Date.to_iso8601(to_date)
    }
    |> new()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        attempt: attempt,
        max_attempts: max_attempts,
        args: %{
          "fx_series_id" => fx_series_id,
          "from_date" => from_date_str,
          "to_date" => to_date_str
        }
      }) do
    with {:ok, from_date} <- Date.from_iso8601(from_date_str),
         {:ok, to_date} <- Date.from_iso8601(to_date_str) do
      series = Fx.get_fx_series!(fx_series_id)
      :ok = Fx.record_sync_tracking(series, :active, attempted_at: now())

      Logger.info("FX sync started",
        event: "fx.sync.start",
        fx_series_id: fx_series_id,
        from_date: from_date_str,
        to_date: to_date_str,
        provider: series.provider_module
      )

      series.provider_module
      |> Provider.fetch_rates(series, from_date, to_date)
      |> handle_fetch_result(series, attempt, max_attempts)
    end
  end

  def perform(%Oban.Job{}), do: {:discard, "invalid sync job args"}

  defp handle_fetch_result({:ok, rows}, series, _attempt, _max_attempts) do
    {:ok, count} = Fx.upsert_rate_records(series.id, rows)

    :ok =
      Fx.record_sync_tracking(series, completed_status(series),
        sync_message: nil,
        attempted_at: now()
      )

    Logger.info("FX sync completed",
      event: "fx.sync.complete",
      fx_series_id: series.id,
      provider: series.provider_module,
      upserted_count: count
    )

    :ok
  end

  defp handle_fetch_result({:error, reason}, series, attempt, max_attempts) do
    maybe_record_terminal_failure(series, reason, attempt, max_attempts)

    Logger.warning("FX sync failed",
      event: "fx.sync.error",
      fx_series_id: series.id,
      provider: series.provider_module,
      reason: inspect(reason)
    )

    {:error, reason}
  end

  defp maybe_record_terminal_failure(series, reason, attempt, max_attempts)
       when attempt >= max_attempts do
    Fx.record_sync_tracking(series, :error,
      sync_message: inspect(reason),
      attempted_at: now()
    )
  end

  defp maybe_record_terminal_failure(_series, _reason, _attempt, _max_attempts), do: :ok

  defp completed_status(%{to_date: %Date{} = to_date}) do
    case Date.compare(to_date, Date.utc_today()) do
      :lt -> :stopped
      _ -> :active
    end
  end

  defp completed_status(_series), do: :active

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
