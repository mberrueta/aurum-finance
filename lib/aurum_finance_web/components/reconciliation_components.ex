defmodule AurumFinanceWeb.ReconciliationComponents do
  @moduledoc """
  Components for the Reconciliation page.

  Components:
    - session_item/1        — a row in the sessions list
    - statement_line_row/1  — a row in the statement lines table
    - discrepancy_item/1    — a row in the discrepancies list
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.UiComponents

  @doc """
  Purpose: renders a reconciliation session summary row.

  Use: pass a `session` map with account, period, and status.

  Example:

      <.session_item session=%{account: "a_cash_br", period: "2026-03", status: "in_progress"} />
  """
  attr :session, :map, required: true

  def session_item(assigns) do
    ~H"""
    <div class="au-item cursor-pointer">
      <div>
        <div class="text-[13px] text-white/92">{@session.account} • {@session.period}</div>
        <div class="text-[12px] text-white/68 mt-[2px]">
          {dgettext("reconciliation", "label_status")}: {@session.status}
        </div>
      </div>
      <.badge variant={:warn}>{dgettext("reconciliation", "badge_in_progress")}</.badge>
    </div>
    """
  end

  @doc """
  Purpose: renders one statement line with matching status and linked transaction.

  Use: pass statement `line` and optional `match` map.

  Example:

      <.statement_line_row
        line=%{date: "2026-03-01", desc: "UBER *TRIP", amount: -47.90, currency: "BRL"}
        match=%{state: "reconciled", tx: "tx_002", confidence: 0.96}
      />
  """
  attr :line, :map, required: true
  attr :match, :map, default: nil

  def statement_line_row(assigns) do
    ~H"""
    <tr>
      <td class="au-mono whitespace-nowrap">{@line.date}</td>
      <td>{@line.desc}</td>
      <td class="au-mono whitespace-nowrap">{format_money(@line.amount, @line.currency)}</td>
      <td>
        <.badge variant={state_variant(match_state(@match))}>
          {state_label(match_state(@match))}
        </.badge>
      </td>
      <td>
        <%= if @match && @match.tx do %>
          <span class="au-mono text-[12px] text-white/68">{@match.tx}</span>
          <span class="au-badge ml-[6px]">{round((@match.confidence || 0) * 100)}%</span>
        <% else %>
          <.badge variant={:bad}>{dgettext("reconciliation", "label_match_none")}</.badge>
        <% end %>
      </td>
    </tr>
    """
  end

  defp match_state(nil), do: :unreconciled
  defp match_state(%{state: "reconciled"}), do: :reconciled
  defp match_state(%{state: "cleared"}), do: :cleared
  defp match_state(%{state: "unreconciled"}), do: :unreconciled
  defp match_state(%{state: _}), do: :default

  defp state_variant(:reconciled), do: :good
  defp state_variant(:cleared), do: :purple
  defp state_variant(:unreconciled), do: :bad
  defp state_variant(_), do: :default

  defp state_label(:reconciled), do: dgettext("reconciliation", "status_reconciled")
  defp state_label(:cleared), do: dgettext("reconciliation", "status_cleared")
  defp state_label(:unreconciled), do: dgettext("reconciliation", "status_unreconciled")
  defp state_label(s), do: to_string(s)

  @doc """
  Purpose: renders one discrepancy row surfaced by reconciliation checks.

  Use: pass a `discrepancy` map with `msg`, `type`, and `severity`.

  Example:

      <.discrepancy_item
        discrepancy=%{
          msg: "Statement line has no matching posting.",
          type: "missing_tx",
          severity: "warn"
        }
      />
  """
  attr :discrepancy, :map, required: true

  def discrepancy_item(assigns) do
    ~H"""
    <div class="au-item">
      <div>
        <div class="text-[13px] text-white/92">{@discrepancy.msg}</div>
        <div class="text-[12px] text-white/68 mt-[2px]">
          {dgettext("reconciliation", "label_type")}: {@discrepancy.type}
        </div>
      </div>
      <.badge variant={severity_variant(@discrepancy.severity)}>
        {@discrepancy.severity}
      </.badge>
    </div>
    """
  end

  defp severity_variant("warn"), do: :warn
  defp severity_variant("bad"), do: :bad
  defp severity_variant(_), do: :default
end
