defmodule AurumFinanceWeb.FxLive do
  use AurumFinanceWeb, :live_view

  def mount(_params, _session, socket) do
    series = mock_series()
    selected = List.first(series)

    {:ok,
     socket
     |> assign(:active_nav, :fx)
     |> assign(:page_title, dgettext("fx", "page_title"))
     |> assign(:series, series)
     |> assign(:selected_series, selected)
     |> assign(:history, history_for(selected.type))}
  end

  def handle_event("select_series", %{"id" => id}, socket) do
    selected = Enum.find(socket.assigns.series, &(&1.id == id)) || socket.assigns.selected_series

    {:noreply, assign(socket, selected_series: selected, history: history_for(selected.type))}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={dgettext("fx", "page_title")}>
        <:subtitle>
          Named FX series (market / official_tax / ptax / mep). Used for reporting and tax snapshots.
        </:subtitle>
        <:actions>
          <button class="au-btn au-btn-primary">Add rate series (mock)</button>
        </:actions>
      </.page_header>

      <div class="grid grid-cols-1 xl:grid-cols-2 gap-[14px]">
        <.section_panel
          title="Rate series"
          badge={to_string(length(@series))}
          badge_variant={:purple}
        >
          <div class="au-list">
            <button
              :for={series <- @series}
              type="button"
              class={[
                "au-item w-full text-left transition",
                @selected_series.id == series.id &&
                  "border-[rgba(124,108,255,0.32)] bg-[rgba(124,108,255,0.12)]"
              ]}
              phx-click="select_series"
              phx-value-id={series.id}
            >
              <div>
                <div class="text-[13px] text-white/92">{series.label}</div>
                <div class="text-[12px] text-white/68 mt-[2px]">
                  Pair: {series.pair} • Type: <span class="au-mono">{series.type}</span>
                </div>
              </div>
              <.badge>{series.type}</.badge>
            </button>
          </div>
        </.section_panel>

        <.section_panel title={@selected_series.label} badge="history">
          <div class="flex items-center justify-between gap-[10px] mt-[10px]">
            <div>
              <div class="text-[12px] text-white/50">Latest (mock)</div>
              <div class="text-[20px] au-mono text-white/92">{latest_rate(@history)}</div>
            </div>
            <.sparkline series={sparkline_series(@history)} />
          </div>

          <div class="au-hr"></div>

          <p class="text-[12px] text-white/50 leading-relaxed">
            Tax snapshot concept: at event time, store the exact FX rate used (by series name) for auditability.
          </p>

          <div class="au-hr"></div>

          <table class="au-table">
            <thead>
              <tr>
                <th style="width:140px;">Date</th>
                <th class="text-right">Rate</th>
                <th style="width:120px;">Type</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={entry <- Enum.reverse(@history)}>
                <td class="au-mono whitespace-nowrap">{entry.date}</td>
                <td class="au-mono text-right">{format_rate(entry.rate)}</td>
                <td>
                  <.badge>{@selected_series.type}</.badge>
                </td>
              </tr>
            </tbody>
          </table>
        </.section_panel>
      </div>
    </div>
    """
  end

  defp latest_rate([%{rate: rate} | _tail]), do: format_rate(rate)
  defp latest_rate(_), do: "-"

  defp format_rate(rate) when is_number(rate),
    do: :erlang.float_to_binary(rate * 1.0, decimals: 4)

  defp sparkline_series(history), do: Enum.map(history, &(&1.rate * 1000))

  defp history_for("market") do
    history_with_rates([5.0961, 5.1034, 5.0897, 5.0788, 5.0842, 5.0973, 5.1096, 5.1124])
  end

  defp history_for("official_tax") do
    history_with_rates([5.1423, 5.1470, 5.1514, 5.1492, 5.1538, 5.1580, 5.1602, 5.1641])
  end

  defp history_for("ptax") do
    history_with_rates([5.0830, 5.0879, 5.0862, 5.0814, 5.0850, 5.0912, 5.0944, 5.0988])
  end

  defp history_for("mep") do
    history_with_rates([5.2312, 5.2191, 5.2118, 5.2050, 5.2099, 5.2140, 5.2201, 5.2268])
  end

  defp history_for(_), do: history_with_rates([5.1, 5.1, 5.1, 5.1, 5.1, 5.1, 5.1, 5.1])

  defp history_with_rates(rates) do
    dates =
      ~w(2026-02-27 2026-02-28 2026-03-01 2026-03-02 2026-03-03 2026-03-04 2026-03-05 2026-03-06)

    Enum.zip(dates, rates)
    |> Enum.map(fn {date, rate} -> %{date: date, rate: rate} end)
  end

  defp mock_series do
    [
      %{id: "fx_001", label: "USD/BRL Market", pair: "USD/BRL", type: "market"},
      %{id: "fx_002", label: "USD/BRL Official Tax", pair: "USD/BRL", type: "official_tax"},
      %{id: "fx_003", label: "USD/BRL PTAX", pair: "USD/BRL", type: "ptax"},
      %{id: "fx_004", label: "USD/BRL MEP", pair: "USD/BRL", type: "mep"}
    ]
  end
end
