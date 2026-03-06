defmodule AurumFinanceWeb.ReportsLive do
  use AurumFinanceWeb, :live_view

  def mount(_params, _session, socket) do
    entity = mock_entity()
    net_worth_series = [120_500, 121_020, 119_800, 118_900, 119_150, 117_980, 118_160, 118_420]

    {:ok,
     socket
     |> assign(:active_nav, :reports)
     |> assign(:page_title, dgettext("reports", "page_title"))
     |> assign(:entity, entity)
     |> assign(:net_worth_series, net_worth_series)
     |> assign(:cashflow, mock_cashflow())}
  end

  def render(assigns) do
    ~H"""
    <div id="reports-page">
      <.page_header title={dgettext("reports", "page_title")}>
        <:subtitle>
          Derived read models for explainable reporting. UI-only charts and drilldowns.
        </:subtitle>
        <:actions>
          <button class="au-btn au-btn-primary">Export PDF (mock)</button>
        </:actions>
      </.page_header>

      <div class="grid grid-cols-1 xl:grid-cols-3 gap-[14px]">
        <.section_panel title="Net worth history" badge="mock">
          <div class="mt-[12px]">
            <.sparkline series={@net_worth_series} />
          </div>
          <div class="mt-[10px] flex items-center justify-between gap-[10px]">
            <span class="text-[12px] text-white/50">Recomputed from facts + overlays</span>
            <button class="au-btn">Drilldown</button>
          </div>
        </.section_panel>

        <.section_panel title="Cashflow (month)" badge="mock">
          <div class="au-list">
            <div :for={item <- @cashflow} class="au-item">
              <div>
                <div class="text-[13px] text-white/92">{item.category}</div>
                <div class="text-[12px] text-white/68 mt-[2px]">category rollup</div>
              </div>
              <div class="au-mono">{format_money(item.value, "USD")}</div>
            </div>
          </div>
        </.section_panel>

        <.section_panel title="Portfolio allocation" badge="mock">
          <p class="text-[12px] text-white/50 mt-[10px]">Holdings for selected entity</p>
          <div class="au-list">
            <div :for={holding <- @entity.holdings} class="au-item">
              <div>
                <div class="text-[13px] text-white/92">{holding.symbol} - {holding.name}</div>
                <div class="text-[12px] text-white/68 mt-[2px]">
                  qty {holding.qty} • price {format_money(holding.price, holding.currency)}
                </div>
              </div>
              <.badge variant={if holding.change_pct_7d >= 0, do: :good, else: :bad}>
                7d {pct_label(holding.change_pct_7d)}
              </.badge>
            </div>
          </div>
        </.section_panel>
      </div>

      <.section_panel title="Drilldown (mock)" badge="transactions" class="mt-[14px]">
        <p class="text-[12px] text-white/50 mt-[10px]">
          Each report line links back to exact transactions and evidence.
        </p>
        <div class="au-hr"></div>
        <.link navigate={~p"/transactions"} class="au-btn">
          Open transactions
        </.link>
      </.section_panel>
    </div>
    """
  end

  defp pct_label(v) when v > 0, do: "+" <> :erlang.float_to_binary(v * 1.0, decimals: 1) <> "%"
  defp pct_label(v), do: :erlang.float_to_binary(v * 1.0, decimals: 1) <> "%"

  defp mock_cashflow do
    [
      %{category: "Income", value: 4_200.0},
      %{category: "Housing", value: -1_500.0},
      %{category: "Food", value: -780.0},
      %{category: "Transport", value: -260.0},
      %{category: "Other", value: -400.0}
    ]
  end

  defp mock_entity do
    %{
      name: "Personal (BR)",
      holdings: [
        %{
          symbol: "QQQD",
          name: "Nasdaq ETF",
          qty: 83,
          price: 31.84,
          currency: "USD",
          change_pct_7d: -1.4
        },
        %{
          symbol: "VT",
          name: "Vanguard Total World",
          qty: 120,
          price: 103.22,
          currency: "USD",
          change_pct_7d: 0.9
        },
        %{
          symbol: "BOVA11",
          name: "iShares Ibovespa",
          qty: 55,
          price: 111.90,
          currency: "BRL",
          change_pct_7d: 1.2
        }
      ]
    }
  end
end
