defmodule AurumFinance.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        AurumFinanceWeb.Telemetry,
        AurumFinance.Repo,
        {DNSCluster, query: Application.get_env(:aurum_finance, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: AurumFinance.PubSub},
        {Oban, Application.fetch_env!(:aurum_finance, Oban)},
        AurumFinanceWeb.Endpoint
      ]
      |> maybe_add_reporting_ledger_event_bridge()

    opts = [strategy: :one_for_one, name: AurumFinance.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AurumFinanceWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_add_reporting_ledger_event_bridge(children),
    do: maybe_add_reporting_ledger_event_bridge(children, bridge_enabled?())

  defp maybe_add_reporting_ledger_event_bridge(children, true),
    do: [AurumFinance.Reporting.LedgerEventBridge | children]

  defp maybe_add_reporting_ledger_event_bridge(children, false), do: children

  defp bridge_enabled? do
    Application.get_env(:aurum_finance, :start_reporting_ledger_event_bridge, true)
  end
end
