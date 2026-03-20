defmodule AurumFinanceWeb.ReportsLive do
  @moduledoc """
  Reporting hub for the first real report surface.
  """

  use AurumFinanceWeb, :live_view

  alias AurumFinance.Entities
  alias AurumFinance.Reporting

  @impl true
  def mount(_params, _session, socket) do
    entity_ids = visible_entity_ids()
    socket = assign_hub(socket, entity_ids)

    if connected?(socket) do
      _ = Reporting.subscribe_hub_freshness()
    end

    {:ok, socket}
  end

  @impl true
  def handle_event("refresh_reporting", _params, socket) do
    case Reporting.enqueue_hub_refresh(socket.assigns.entity_ids) do
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
    {:noreply, refresh_hub(socket)}
  end

  @impl true
  def handle_info({:reporting_hub_freshness_refreshed, _payload}, socket) do
    {:noreply, socket |> refresh_hub() |> assign(:refresh_requested?, false)}
  end

  @impl true
  def handle_info(_message, socket), do: {:noreply, socket}

  defp assign_hub(socket, entity_ids) do
    report = load_hub_report(entity_ids)

    socket
    |> assign(
      active_nav: :reports,
      page_title: dgettext("reports", "page_title"),
      entity_ids: entity_ids,
      hub_report: report,
      refresh_requested?: false
    )
    |> assign_hub_report_derivatives(report)
  end

  defp refresh_hub(socket) do
    report = load_hub_report(socket.assigns.entity_ids)

    socket
    |> assign(:hub_report, report)
    |> assign_hub_report_derivatives(report)
  end

  defp load_hub_report(entity_ids) do
    {:ok, report} = Reporting.net_worth_report(entity_ids)
    report
  end

  defp visible_entity_ids do
    Entities.list_entities()
    |> Enum.map(& &1.id)
  end

  defp assign_hub_report_derivatives(socket, report) do
    assign(socket,
      freshness_badge_variant: freshness_badge_variant(report.freshness_status),
      freshness_badge_label: freshness_badge_label(report.freshness_status),
      net_worth_badge_variant: net_worth_badge_variant(report),
      net_worth_status: net_worth_status(report),
      compact_currency_summaries: compact_currency_summaries(report.currency_summaries)
    )
  end

  defp freshness_badge_variant(:up_to_date), do: :good
  defp freshness_badge_variant(:outdated), do: :warn

  defp freshness_badge_label(:up_to_date), do: dgettext("reports", "hub_freshness_up_to_date")
  defp freshness_badge_label(:outdated), do: dgettext("reports", "hub_freshness_outdated")

  defp net_worth_badge_variant(%{empty?: true}), do: :warn
  defp net_worth_badge_variant(_report), do: :good

  defp net_worth_status(%{empty?: true}), do: dgettext("reports", "hub_report_status_empty")
  defp net_worth_status(_report), do: dgettext("reports", "hub_report_status_ready")

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
