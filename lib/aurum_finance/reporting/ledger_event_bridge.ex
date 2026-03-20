defmodule AurumFinance.Reporting.LedgerEventBridge do
  @moduledoc """
  Reporting-owned bridge from ledger write notifications to snapshot refresh
  enqueue requests.

  The bridge keeps the dependency direction one-way:

  - `Ledger` emits neutral domain notifications through `AurumFinance.Ledger.PubSub`
  - `Reporting` subscribes and translates those notifications into refresh jobs

  This module intentionally does not recalculate snapshots inline. It only
  enqueues one refresh per affected account, emits a coarse reporting freshness
  invalidation signal, and lets the reporting worker apply the approved debounce
  and `from_date` merge rules.
  """

  use GenServer

  alias AurumFinance.Ledger.PubSub
  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.PubSub, as: ReportingPubSub

  @doc """
  Starts the bridge process and subscribes it to ledger transaction events.

  In normal runtime this process is supervised by `AurumFinance.Application`.
  Tests can start it explicitly and grant SQL sandbox access before exercising
  enqueue behavior.

  ## Examples

      iex> {:ok, _pid} = AurumFinance.Reporting.LedgerEventBridge.start_link()
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    :ok = PubSub.subscribe_transactions()
    {:ok, %{}}
  end

  @impl true
  def handle_info({:transaction_created, notification}, state) do
    :ok = enqueue_snapshot_refreshes(notification)
    {:noreply, state}
  end

  def handle_info({:transaction_voided, notification}, state) do
    :ok = enqueue_snapshot_refreshes(notification)
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp enqueue_snapshot_refreshes(
         %{
           entity_id: entity_id,
           account_ids: account_ids,
           from_date: from_date
         } = _notification
       ) do
    account_ids = Enum.uniq(account_ids)

    account_ids
    |> Enum.each(&enqueue_snapshot_refresh(&1, from_date))

    ReportingPubSub.broadcast_hub_freshness_invalidated(%{
      entity_id: entity_id,
      account_ids: account_ids,
      from_date: from_date,
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    })

    :ok
  end

  defp enqueue_snapshot_refresh(account_id, from_date) do
    account_id
    |> Reporting.enqueue_daily_balance_snapshot_refresh(from_date)
    |> normalize_enqueue_result()
  end

  defp normalize_enqueue_result({:ok, _job}), do: :ok
  defp normalize_enqueue_result({:error, _reason}), do: :ok
end
