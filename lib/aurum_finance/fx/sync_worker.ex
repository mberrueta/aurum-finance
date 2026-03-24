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
        args: %{
          "fx_series_id" => fx_series_id,
          "from_date" => from_date_str,
          "to_date" => to_date_str
        }
      }) do
    with {:ok, from_date} <- Date.from_iso8601(from_date_str),
         {:ok, to_date} <- Date.from_iso8601(to_date_str) do
      series = Fx.get_fx_series!(fx_series_id)

      Logger.info("FX sync started",
        event: "fx.sync.start",
        fx_series_id: fx_series_id,
        from_date: from_date_str,
        to_date: to_date_str,
        provider: series.provider_module
      )

      series.provider_module
      |> Provider.fetch_rates(series, from_date, to_date)
      |> handle_fetch_result(series)
    end
  end

  def perform(%Oban.Job{}), do: {:discard, "invalid sync job args"}

  defp handle_fetch_result({:ok, rows}, series) do
    {:ok, count} = Fx.upsert_rate_records(series.id, rows)

    Logger.info("FX sync completed",
      event: "fx.sync.complete",
      fx_series_id: series.id,
      provider: series.provider_module,
      upserted_count: count
    )

    :ok
  end

  defp handle_fetch_result({:error, reason}, series) do
    Logger.warning("FX sync failed",
      event: "fx.sync.error",
      fx_series_id: series.id,
      provider: series.provider_module,
      reason: inspect(reason)
    )

    {:error, reason}
  end
end
