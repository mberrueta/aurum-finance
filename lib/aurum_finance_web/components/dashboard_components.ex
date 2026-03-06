defmodule AurumFinanceWeb.DashboardComponents do
  @moduledoc """
  Components specific to the Dashboard page.

  Components:
    - kpi_card/1    — metric card with big value, delta footer, and sparkline
    - change_item/1 — row in the "what changed" list
    - alert_item/1  — row in the "alerts & next actions" list
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.UiComponents

  @doc """
  Purpose: renders a KPI summary card on the dashboard.

  Use: pass title, value/currency, delta, and sparkline series.

  Example:

      <.kpi_card
        title="Net worth"
        value={118_420.0}
        currency="USD"
        delta={260.0}
        series={[120_500, 119_800, 118_420]}
      />
  """
  attr :title, :string, required: true
  attr :value, :float, required: true
  attr :currency, :string, required: true
  attr :delta, :float, required: true
  attr :footer_text, :string, default: nil
  attr :series, :list, required: true

  def kpi_card(assigns) do
    ~H"""
    <div class="au-card">
      <div class="flex items-center justify-between gap-[10px] text-[13px] font-semibold text-white/68">
        <span>{@title}</span>
        <.badge variant={:purple}>{dgettext("dashboard", "badge_mock")}</.badge>
      </div>

      <div class="mt-[10px] text-[24px] tracking-[0.2px] au-mono text-white/92">
        {format_money(@value, @currency)}
      </div>

      <div class="mt-[10px] flex items-center justify-between gap-[10px] text-[12px] text-white/68">
        <span>{@footer_text || delta_label(@delta, @currency)}</span>
        <.sparkline series={@series} />
      </div>
    </div>
    """
  end

  defp delta_label(delta, currency) do
    formatted = format_money(delta, currency)
    "#{formatted} #{dgettext("dashboard", "kpi_since_last_point")}"
  end

  @doc """
  Purpose: renders one "what changed" line item.

  Use: pass item label/subtext/value and optional `sentiment`.

  Example:

      <.change_item
        label="USD/BRL FX movement"
        sub="Display currency effect"
        value={-700.0}
        currency="USD"
        sentiment={:warn}
      />
  """
  attr :label, :string, required: true
  attr :sub, :string, required: true
  attr :value, :float, required: true
  attr :currency, :string, required: true
  attr :sentiment, :atom, default: :default, values: [:good, :bad, :warn, :default]

  def change_item(assigns) do
    ~H"""
    <div class="au-item">
      <div>
        <div class="text-[13px] text-white/92">{@label}</div>
        <div class="text-[12px] text-white/68 mt-[2px]">{@sub}</div>
      </div>
      <div class="text-right shrink-0">
        <div class="au-mono text-[13px]">{format_money(@value, @currency)}</div>
        <div class="mt-1">
          <.badge variant={@sentiment}>{dgettext("dashboard", "badge_impact")}</.badge>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Purpose: renders one alert row in the dashboard alerts panel.

  Use: pass title/subtext and optional severity (`:warn`, `:bad`, `:info`).

  Example:

      <.alert_item
        title="Missing FX rate"
        sub="USD/ARS official_tax not available"
        severity={:warn}
      />
  """
  attr :title, :string, required: true
  attr :sub, :string, required: true
  attr :severity, :atom, default: :warn, values: [:warn, :bad, :info]

  def alert_item(assigns) do
    ~H"""
    <div class="au-item">
      <div>
        <div class="text-[13px] text-white/92">{@title}</div>
        <div class="text-[12px] text-white/68 mt-[2px]">{@sub}</div>
      </div>
      <.badge variant={severity_variant(@severity)}>
        {severity_label(@severity)}
      </.badge>
    </div>
    """
  end

  defp severity_variant(:warn), do: :warn
  defp severity_variant(:bad), do: :bad
  defp severity_variant(_), do: :default

  defp severity_label(:warn), do: dgettext("dashboard", "severity_warn")
  defp severity_label(:bad), do: dgettext("dashboard", "severity_bad")
  defp severity_label(_), do: dgettext("dashboard", "severity_info")
end
