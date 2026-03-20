defmodule AurumFinanceWeb.ReportsLive do
  @moduledoc """
  Reporting hub for the first real report surface.
  """

  use AurumFinanceWeb, :live_view

  alias AurumFinance.Entities
  alias AurumFinance.Reporting

  @hub_refresh_debounce_ms 75

  @impl true
  def mount(_params, _session, socket) do
    entity_ids = visible_entity_ids()
    socket = assign_hub(socket, entity_ids)

    if connected?(socket) do
      _ = reporting_module().subscribe_hub_freshness()
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("refresh_reporting", _params, socket) do
    case reporting_module().enqueue_hub_refresh(socket.assigns.entity_ids) do
      {:ok, _result} ->
        {:noreply,
         socket
         |> assign(:refresh_requested?, true)
         |> put_flash(:info, dgettext("reports", "hub_refresh_enqueued"))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, dgettext("reports", "hub_refresh_failed"))}
    end
  end

  @impl true
  def handle_info({:reporting_hub_freshness_invalidated, _payload}, socket) do
    {:noreply, schedule_hub_refresh(socket)}
  end

  @impl true
  def handle_info({:reporting_hub_freshness_refreshed, _payload}, socket) do
    {:noreply, socket |> assign(:refresh_requested?, false) |> schedule_hub_refresh()}
  end

  @impl true
  def handle_info(:refresh_hub, socket) do
    {:noreply,
     socket
     |> assign(:hub_refresh_scheduled?, false)
     |> refresh_hub()}
  end

  @impl true
  def handle_info(_message, socket), do: {:noreply, socket}

  defp assign_hub(socket, entity_ids) do
    socket
    |> assign(
      active_nav: :reports,
      page_title: dgettext("reports", "page_title"),
      entity_ids: entity_ids,
      refresh_requested?: false,
      hub_report_load_failed?: false,
      hub_refresh_scheduled?: false
    )
    |> then(&load_hub_report(&1, entity_ids))
    |> then(fn {loaded_socket, report} ->
      loaded_socket
      |> assign(:hub_report, report)
      |> assign_hub_report_derivatives(report)
    end)
  end

  defp refresh_hub(socket) do
    {socket, report} = load_hub_report(socket, socket.assigns.entity_ids)

    socket
    |> assign(:hub_report, report)
    |> assign_hub_report_derivatives(report)
  end

  defp schedule_hub_refresh(%{assigns: %{hub_refresh_scheduled?: true}} = socket), do: socket

  defp schedule_hub_refresh(socket) do
    Process.send_after(self(), :refresh_hub, @hub_refresh_debounce_ms)
    assign(socket, :hub_refresh_scheduled?, true)
  end

  defp load_hub_report(socket, entity_ids) do
    case reporting_module().net_worth_report(entity_ids) do
      {:ok, report} ->
        {
          socket
          |> clear_flash(:error)
          |> assign(:hub_report_load_failed?, false),
          report
        }

      {:error, _reason} ->
        report = empty_report(Date.utc_today())

        {
          socket
          |> put_flash(:error, dgettext("reports", "report_load_failed"))
          |> assign(:hub_report_load_failed?, true),
          report
        }
    end
  end

  defp visible_entity_ids do
    Entities.list_entities()
    |> Enum.map(& &1.id)
  end

  defp reporting_module do
    Application.get_env(:aurum_finance, :reporting_module, Reporting)
  end

  defp empty_report(as_of_date) do
    %{
      as_of_date: as_of_date,
      freshness_status: :up_to_date,
      refresh_suggested?: false,
      empty?: true,
      included_account_count: 0,
      entity_count: 0,
      show_entity_column?: false,
      coverage_counts: %{exact: 0, carried_forward: 0, refreshable_gap: 0, no_history: 0},
      currency_summaries: [],
      account_rows: []
    }
  end

  defp assign_hub_report_derivatives(socket, report) do
    assign(socket,
      freshness_badge_variant:
        freshness_badge_variant(report.freshness_status, socket.assigns.hub_report_load_failed?),
      freshness_badge_label:
        freshness_badge_label(report.freshness_status, socket.assigns.hub_report_load_failed?),
      net_worth_badge_variant:
        net_worth_badge_variant(report, socket.assigns.hub_report_load_failed?),
      net_worth_status: net_worth_status(report, socket.assigns.hub_report_load_failed?),
      compact_currency_summaries: compact_currency_summaries(report.currency_summaries)
    )
  end

  defp freshness_badge_variant(_status, true), do: :bad
  defp freshness_badge_variant(:up_to_date, false), do: :good
  defp freshness_badge_variant(:outdated, false), do: :warn

  defp freshness_badge_label(_status, true),
    do: dgettext("reports", "report_freshness_unavailable")

  defp freshness_badge_label(:up_to_date, false),
    do: dgettext("reports", "hub_freshness_up_to_date")

  defp freshness_badge_label(:outdated, false), do: dgettext("reports", "hub_freshness_outdated")

  defp net_worth_badge_variant(_report, true), do: :bad
  defp net_worth_badge_variant(%{empty?: true}, false), do: :warn
  defp net_worth_badge_variant(_report, false), do: :good

  defp net_worth_status(_report, true), do: dgettext("reports", "hub_report_status_unavailable")

  defp net_worth_status(%{empty?: true}, false),
    do: dgettext("reports", "hub_report_status_empty")

  defp net_worth_status(_report, false), do: dgettext("reports", "hub_report_status_ready")

  defp compact_currency_summaries(currency_summaries) do
    Enum.map(currency_summaries, fn summary ->
      summary
      |> Map.put(:net_worth_compact, compact_money(summary.net_worth, summary.currency_code))
      |> Map.put(:assets_display, format_money(summary.assets, summary.currency_code))
      |> Map.put(:liabilities_display, format_money(summary.liabilities, summary.currency_code))
    end)
  end

  defp compact_money(amount, currency_code) do
    sign = if Decimal.negative?(amount), do: "-", else: ""

    # The hub only needs an approximate compact display like "USD 5.0K".
    # The precise monetary values remain rendered separately below.
    compact_value =
      amount
      |> Decimal.abs()
      |> Decimal.to_float()
      |> compact_number()

    "#{currency_code} #{sign}#{compact_value}"
  end

  defp compact_number(value) when value >= 1_000_000 do
    value
    |> Kernel./(1_000_000)
    |> format_compact_number("M")
  end

  defp compact_number(value) when value >= 1_000 do
    value
    |> Kernel./(1_000)
    |> format_compact_number("K")
  end

  defp compact_number(value), do: format_compact_number(value, "")

  defp format_compact_number(value, suffix) do
    decimals =
      cond do
        suffix == "" -> 2
        value >= 100 -> 0
        value >= 10 -> 1
        true -> 1
      end

    value
    |> :erlang.float_to_binary(decimals: decimals)
    |> String.trim_trailing(".0")
    |> Kernel.<>(suffix)
  end
end
