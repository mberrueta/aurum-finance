defmodule AurumFinance.Reporting.PubSubTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias AurumFinance.Reporting.PubSub

  defmodule FailingPubSub do
    def subscribe(_server, _topic), do: :ok
    def broadcast(_server, _topic, _message), do: {:error, :pubsub_down}
  end

  defmodule RecordingPubSub do
    def subscribe(_server, _topic), do: :ok

    def broadcast(server, topic, message) do
      send(self(), {:broadcast_called, server, topic, message})
      :ok
    end
  end

  setup do
    previous_module = Application.get_env(:aurum_finance, :reporting_pubsub_module)
    previous_server = Application.get_env(:aurum_finance, :reporting_pubsub_server)

    on_exit(fn ->
      restore_env(:reporting_pubsub_module, previous_module)
      restore_env(:reporting_pubsub_server, previous_server)
    end)

    :ok
  end

  test "broadcasts invalidated events through the configured pubsub module" do
    Application.put_env(:aurum_finance, :reporting_pubsub_module, RecordingPubSub)
    Application.put_env(:aurum_finance, :reporting_pubsub_server, :reporting_pubsub_test)

    assert :ok =
             PubSub.broadcast_hub_freshness_invalidated(%{
               entity_id: "entity-id",
               account_ids: ["account-id"],
               from_date: ~D[2026-03-20],
               occurred_at: ~U[2026-03-20 12:00:00Z]
             })

    assert_receive {:broadcast_called, :reporting_pubsub_test, "reporting:hub_freshness",
                    {:reporting_hub_freshness_invalidated, payload}}

    assert payload.entity_id == "entity-id"
    assert payload.account_ids == ["account-id"]
    assert payload.from_date == ~D[2026-03-20]
  end

  test "logs broadcast failures instead of swallowing them silently" do
    Application.put_env(:aurum_finance, :reporting_pubsub_module, FailingPubSub)
    Application.put_env(:aurum_finance, :reporting_pubsub_server, :reporting_pubsub_test)

    log =
      capture_log(fn ->
        assert :ok =
                 PubSub.broadcast_hub_freshness_refreshed(%{
                   entity_id: "entity-id",
                   account_id: "account-id",
                   refresh_status: :rebuilt,
                   requested_from_date: ~D[2026-03-20],
                   effective_from_date: ~D[2026-03-20],
                   refreshed_at: ~U[2026-03-20 12:00:00Z]
                 })
      end)

    assert log =~ "reporting hub freshness broadcast failed"
    assert log =~ ":pubsub_down"
  end

  defp restore_env(key, nil), do: Application.delete_env(:aurum_finance, key)
  defp restore_env(key, value), do: Application.put_env(:aurum_finance, key, value)
end
