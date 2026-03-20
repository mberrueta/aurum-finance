defmodule AurumFinance.Reporting.PubSub do
  @moduledoc """
  Narrow PubSub helpers for reporting hub freshness signals.

  This module intentionally does not provide a general event framework. It is a
  reporting-specific bridge for coarse `/reports` hub freshness updates.

  Subscribers should treat received events as re-read triggers, not as a source
  of detailed reporting state.

  The current V1 contract is intentionally small:

  - `{:reporting_hub_freshness_invalidated, %{entity_id, account_ids, from_date, occurred_at}}`
    is emitted after ledger writes enqueue reporting refresh work.
  - `{:reporting_hub_freshness_refreshed,
     %{entity_id, account_id, refresh_status, requested_from_date, effective_from_date, refreshed_at}}`
    is emitted after one account refresh completes.
  """

  @hub_freshness_topic "reporting:hub_freshness"

  @type refresh_status :: :rebuilt | :noop | :deleted_stale

  @type hub_freshness_invalidated :: %{
          entity_id: Ecto.UUID.t(),
          account_ids: [Ecto.UUID.t()],
          from_date: Date.t(),
          occurred_at: DateTime.t()
        }

  @type hub_freshness_refreshed :: %{
          entity_id: Ecto.UUID.t(),
          account_id: Ecto.UUID.t(),
          refresh_status: refresh_status(),
          requested_from_date: Date.t() | nil,
          effective_from_date: Date.t() | nil,
          refreshed_at: DateTime.t()
        }

  @type hub_freshness_message ::
          {:reporting_hub_freshness_invalidated, hub_freshness_invalidated()}
          | {:reporting_hub_freshness_refreshed, hub_freshness_refreshed()}

  @doc """
  Subscribes the caller to coarse reporting hub freshness updates.

  ## Examples

      iex> AurumFinance.Reporting.PubSub.subscribe_hub_freshness()
      :ok
  """
  @spec subscribe_hub_freshness() :: :ok | {:error, term()}
  def subscribe_hub_freshness do
    Phoenix.PubSub.subscribe(AurumFinance.PubSub, @hub_freshness_topic)
  end

  @doc """
  Broadcasts that reporting freshness became stale due to a relevant ledger write.

  Subscribers should re-read their coarse hub freshness state after receiving
  this message.
  """
  @spec broadcast_hub_freshness_invalidated(hub_freshness_invalidated()) :: :ok
  def broadcast_hub_freshness_invalidated(payload) when is_map(payload) do
    broadcast({:reporting_hub_freshness_invalidated, payload})
  end

  @doc """
  Broadcasts that one reporting refresh completed for an included account.

  Subscribers should use this as a signal to re-read coarse hub freshness
  rather than trying to derive row-level report semantics from the payload.
  """
  @spec broadcast_hub_freshness_refreshed(hub_freshness_refreshed()) :: :ok
  def broadcast_hub_freshness_refreshed(payload) when is_map(payload) do
    broadcast({:reporting_hub_freshness_refreshed, payload})
  end

  defp broadcast(message) do
    AurumFinance.PubSub
    |> Phoenix.PubSub.broadcast(@hub_freshness_topic, message)
    |> normalize_broadcast_result()
  end

  defp normalize_broadcast_result(:ok), do: :ok
  defp normalize_broadcast_result({:error, _reason}), do: :ok
end
