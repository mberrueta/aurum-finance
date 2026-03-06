defmodule AurumFinanceWeb.DashboardLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.DashboardComponents

  def mount(_params, _session, socket) do
    data = mock_data()

    {:ok,
     socket
     |> assign(:active_nav, :dashboard)
     |> assign(:page_title, dgettext("dashboard", "page_title"))
     |> assign(data)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%!-- Page header --%>
      <.page_header title={dgettext("dashboard", "page_title")}>
        <:subtitle>
          {dgettext("dashboard", "header_entity_label")}
          <span class="au-badge au-badge-purple ml-1">{@entity_name}</span>
          &nbsp;•&nbsp; {dgettext("dashboard", "header_display_label")}
          <span class="au-badge au-badge-purple ml-1">{@display_currency}</span>
          &nbsp;•&nbsp; {dgettext("dashboard", "header_rate_label")}
          <span class="au-badge au-badge-purple ml-1">{@rate_type}</span>
        </:subtitle>
        <:actions>
          <button class="au-btn au-btn-primary">
            {dgettext("dashboard", "btn_explain_week")}
          </button>
          <button class="au-btn">
            {dgettext("dashboard", "btn_new_import")}
          </button>
        </:actions>
      </.page_header>

      <%!-- KPI row --%>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-[14px]">
        <.kpi_card :for={kpi <- @kpis} {kpi} />
      </div>

      <%!-- What changed + Alerts --%>
      <div class="au-split mt-[14px]">
        <%!-- What changed this week --%>
        <.au_card>
          <:header>
            <span>{dgettext("dashboard", "section_what_changed")}</span>
            <button class="au-btn">{dgettext("dashboard", "btn_explain")}</button>
          </:header>

          <div class="au-list">
            <.change_item :for={item <- @what_changed} {item} />
          </div>

          <div class="au-hr"></div>

          <div class="flex items-center justify-between text-[13px]">
            <span class="text-white/68">{dgettext("dashboard", "label_net_change")}</span>
            <span class="au-mono">{format_money(@what_changed_total, @display_currency)}</span>
          </div>
        </.au_card>

        <%!-- Alerts & next actions --%>
        <.au_card>
          <:header>
            <span>{dgettext("dashboard", "section_alerts")}</span>
            <.badge variant={:warn}>{length(@alerts)}</.badge>
          </:header>

          <div class="au-list">
            <.alert_item :for={alert <- @alerts} {alert} />
          </div>

          <div class="au-hr"></div>

          <p class="text-[12px] text-white/50 leading-relaxed">
            {dgettext("dashboard", "tip_immutable_facts")}
          </p>
        </.au_card>
      </div>
    </div>
    """
  end

  # ── Mock data (replaced by real context in later milestones) ─────────────────

  defp mock_data do
    series = [
      120_500,
      121_020,
      119_800,
      118_900,
      119_150,
      117_980,
      118_160,
      118_420,
      119_010,
      118_300,
      117_900,
      118_250
    ]

    nw = List.last(series) * 1.0
    prev = Enum.at(series, -2) * 1.0

    %{
      entity_name: "Personal (BR)",
      display_currency: "USD",
      rate_type: "market",
      kpis: [
        %{
          title: dgettext("dashboard", "kpi_net_worth"),
          value: nw,
          currency: "USD",
          delta: nw - prev,
          series: series,
          footer_text: nil
        },
        %{
          title: dgettext("dashboard", "kpi_cash"),
          value: round(nw * 0.18) * 1.0,
          currency: "USD",
          delta: 120.0,
          series: jitter(series, 0.08),
          footer_text: dgettext("dashboard", "kpi_cash_footer")
        },
        %{
          title: dgettext("dashboard", "kpi_investments"),
          value: round(nw * 0.72) * 1.0,
          currency: "USD",
          delta: -1_200.0,
          series: jitter(series, 0.10),
          footer_text: dgettext("dashboard", "kpi_investments_footer")
        },
        %{
          title: dgettext("dashboard", "kpi_liabilities"),
          value: round(nw * 0.22) * 1.0,
          currency: "USD",
          delta: 340.0,
          series: jitter(series, 0.06),
          footer_text: dgettext("dashboard", "kpi_liabilities_footer")
        }
      ],
      what_changed: [
        %{
          label: "NASDAQ ETF (QQQD)",
          sub: dgettext("dashboard", "changed_holdings_reprice"),
          value: -1_200.0,
          currency: "USD",
          sentiment: :bad
        },
        %{
          label: "USD/BRL FX movement",
          sub: dgettext("dashboard", "changed_fx_effect"),
          value: -700.0,
          currency: "USD",
          sentiment: :warn
        },
        %{
          label: "Income: Salary",
          sub: dgettext("dashboard", "changed_cash_inflow"),
          value: 4_200.0,
          currency: "USD",
          sentiment: :good
        },
        %{
          label: "Living expenses",
          sub: dgettext("dashboard", "changed_card_spend"),
          value: -4_640.0,
          currency: "USD",
          sentiment: :warn
        }
      ],
      what_changed_total: -2_340.0,
      alerts: [
        %{
          title: dgettext("dashboard", "alert_missing_fx_title"),
          sub: dgettext("dashboard", "alert_missing_fx_sub"),
          severity: :warn
        },
        %{
          title: dgettext("dashboard", "alert_unreconciled_title"),
          sub: dgettext("dashboard", "alert_unreconciled_sub"),
          severity: :bad
        },
        %{
          title: dgettext("dashboard", "alert_anomaly_title"),
          sub: dgettext("dashboard", "alert_anomaly_sub"),
          severity: :warn
        }
      ]
    }
  end

  # Deterministic jitter — offsets are fixed so the chart looks varied but stable
  defp jitter(series, factor) do
    offsets = [0.02, -0.01, 0.03, -0.02, 0.01, -0.03, 0.02, 0.01, -0.01, 0.02, -0.02, 0.01]

    series
    |> Enum.zip(Stream.cycle(offsets))
    |> Enum.map(fn {v, off} -> v * (1 + factor * off) end)
  end
end
