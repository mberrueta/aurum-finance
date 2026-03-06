defmodule AurumFinanceWeb.UiComponents do
  @moduledoc """
  Shared UI primitives — available in all LiveViews via html_helpers().

  Components:
    - page_header/1   — page title row with optional subtitle and action buttons
    - badge/1         — colored status pill (variants: default, good, warn, bad, purple)
    - sparkline/1     — inline SVG sparkline from a list of numbers
    - empty_state/1   — dashed placeholder box
    - au_card/1       — content card with optional header row
    - section_panel/1 — common titled section card with optional badge/actions
    - info_label/1    — field label with small info tooltip icon
    - info_callout/1  — informative callout with tone-based colors/icons

  Utility:
    - format_money/2  — formats a number as "sign + value + currency code"
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  @doc """
  Purpose: renders the standard page title row.

  Use: add title, optional subtitle slot, and optional actions slot.

  Example:

      <.page_header title="Dashboard">
        <:subtitle>Entity <.badge>Personal</.badge></:subtitle>
        <:actions><button class="au-btn">Refresh</button></:actions>
      </.page_header>
  """
  attr :title, :string, required: true
  slot :subtitle
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="au-page-title">
      <div>
        <h2 class="text-xl font-semibold tracking-[0.2px] text-white/92">{@title}</h2>
        <p :if={@subtitle != []} class="text-[13px] text-white/68 mt-[6px]">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex gap-[10px] flex-wrap items-center">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  @doc """
  Purpose: renders a compact status/metadata pill.

  Use: pass text in the inner slot and choose `variant` when needed.

  Example:

      <.badge variant={:warn}>Needs review</.badge>
  """
  attr :variant, :atom, default: :default, values: [:default, :good, :warn, :bad, :purple]
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span class={["au-badge", badge_class(@variant)]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  defp badge_class(:good), do: "au-badge-good"
  defp badge_class(:warn), do: "au-badge-warn"
  defp badge_class(:bad), do: "au-badge-bad"
  defp badge_class(:purple), do: "au-badge-purple"
  defp badge_class(_), do: ""

  @doc """
  Purpose: renders a tiny trend chart for KPI cards and summaries.

  Use: provide a numeric `series` list with at least 2 points.

  Example:

      <.sparkline series={[100, 103, 98, 110, 108]} />
  """
  attr :series, :list, required: true
  attr :class, :string, default: nil

  def sparkline(assigns) do
    assigns = assign(assigns, :svg_path, build_sparkline_path(assigns.series))

    ~H"""
    <svg
      class={["au-spark", @class]}
      viewBox="0 0 110 24"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden="true"
      style="width:110px;height:24px;"
    >
      <path
        d={@svg_path}
        fill="none"
        stroke="rgba(124,108,255,.95)"
        stroke-width="2"
        stroke-linecap="round"
      />
      <path d={"#{@svg_path} L 108 22 L 2 22 Z"} fill="rgba(124,108,255,.12)" />
    </svg>
    """
  end

  defp build_sparkline_path(series) when length(series) < 2, do: ""

  defp build_sparkline_path(series) do
    w = 110
    h = 24
    pad = 2
    min = Enum.min(series) * 1.0
    max = Enum.max(series) * 1.0
    span = max(max - min, 1.0)
    count = length(series)

    series
    |> Enum.with_index()
    |> Enum.map(fn {v, i} ->
      x = pad + i * (w - 2 * pad) / (count - 1)
      y = h - pad - (v * 1.0 - min) / span * (h - 2 * pad)
      {Float.round(x, 2), Float.round(y, 2)}
    end)
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {{x, y}, i} ->
      cmd = if i == 0, do: "M", else: "L"
      "#{cmd}#{x} #{y}"
    end)
  end

  @doc """
  Purpose: renders an empty/placeholder section state.

  Use: pass text via `text` attr or with an inner slot.

  Example:

      <.empty_state text="No transactions yet" />
  """
  attr :text, :string, default: nil
  slot :inner_block

  def empty_state(assigns) do
    ~H"""
    <div class="au-empty">
      {render_slot(@inner_block) || @text}
    </div>
    """
  end

  @doc """
  Purpose: renders a bordered section card container.

  Use: put title/actions in `:header`, body content in default slot.

  Example:

      <.au_card>
        <:header><span>Summary</span></:header>
        <p>Body content</p>
      </.au_card>
  """
  attr :class, :string, default: nil
  slot :header
  slot :inner_block, required: true

  def au_card(assigns) do
    ~H"""
    <div class={["au-card", @class]}>
      <div
        :if={@header != []}
        class="flex items-center justify-between gap-[10px] mb-3 text-[13px] font-semibold text-white/68"
      >
        {render_slot(@header)}
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Purpose: standard reusable section pattern with title + optional badge/action.

  Use: set `title`; optionally set `badge` and `badge_variant`; add actions slot.

  Example:

      <.section_panel title="What changed" badge="4" badge_variant={:purple}>
        <:actions><button class="au-btn">Explain</button></:actions>
        <div class="au-list">...</div>
      </.section_panel>
  """
  attr :title, :string, required: true
  attr :class, :string, default: nil
  attr :badge, :string, default: nil
  attr :badge_variant, :atom, default: :default, values: [:default, :good, :warn, :bad, :purple]
  slot :actions
  slot :inner_block, required: true

  def section_panel(assigns) do
    ~H"""
    <.au_card class={@class}>
      <:header>
        <span>{@title}</span>
        <div class="flex items-center gap-[8px]">
          <.badge :if={@badge} variant={@badge_variant}>{@badge}</.badge>
          {render_slot(@actions)}
        </div>
      </:header>
      {render_slot(@inner_block)}
    </.au_card>
    """
  end

  @doc """
  Purpose: label helper with an inline info icon and native tooltip.
  """
  attr :for, :string, required: true
  attr :text, :string, required: true
  attr :tooltip, :string, required: true

  def info_label(assigns) do
    ~H"""
    <div class="flex items-center gap-2 mb-1">
      <label for={@for} class="label mb-0">{@text}</label>
      <span
        class="inline-flex items-center justify-center size-4 rounded-full border border-white/30 text-[10px] text-white/80 cursor-help select-none"
        title={@tooltip}
        aria-label={@tooltip}
      >
        i
      </span>
    </div>
    """
  end

  @doc """
  Purpose: renders an informational callout with tone-based style.
  """
  attr :title, :string, required: true
  attr :tone, :atom, default: :info, values: [:info, :warn, :tip]
  slot :inner_block, required: true

  def info_callout(assigns) do
    ~H"""
    <div class={["rounded-xl border p-3", callout_class(@tone)]}>
      <div class="flex items-start gap-3">
        <span class={[
          "inline-flex items-center justify-center size-5 rounded-full text-[11px] font-semibold",
          callout_icon_class(@tone)
        ]}>
          {callout_icon(@tone)}
        </span>
        <div class="min-w-0">
          <h4 class="text-[13px] font-semibold text-white/90">{@title}</h4>
          <div class="text-[12px] text-white/75 mt-1 leading-relaxed">
            {render_slot(@inner_block)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp callout_class(:info), do: "border-cyan-300/30 bg-cyan-400/10"
  defp callout_class(:warn), do: "border-amber-300/30 bg-amber-400/10"
  defp callout_class(:tip), do: "border-emerald-300/30 bg-emerald-400/10"
  defp callout_class(_), do: "border-white/20 bg-white/5"

  defp callout_icon_class(:info), do: "bg-cyan-300/20 text-cyan-100"
  defp callout_icon_class(:warn), do: "bg-amber-300/20 text-amber-100"
  defp callout_icon_class(:tip), do: "bg-emerald-300/20 text-emerald-100"
  defp callout_icon_class(_), do: "bg-white/20 text-white"

  defp callout_icon(:info), do: "i"
  defp callout_icon(:warn), do: "!"
  defp callout_icon(:tip), do: "t"
  defp callout_icon(_), do: "i"

  @doc """
  Purpose: formats numeric amounts for consistent UI display.

  Use: pass amount and currency code.

  Example:

      iex> format_money(-2640.0, "USD")
      "-2,640.00 USD"
  """
  def format_money(amount, currency) when is_number(amount) do
    sign = if amount < 0, do: "-", else: ""
    abs_val = abs(amount * 1.0)
    int_part = trunc(abs_val)
    dec_part = round((abs_val - int_part) * 100)
    int_str = int_part |> Integer.to_string() |> thousands_sep()
    dec_str = dec_part |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{sign}#{int_str}.#{dec_str} #{currency}"
  end

  defp thousands_sep(str) do
    str
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end
end
