defmodule AurumFinanceWeb.TransactionsComponents do
  @moduledoc """
  Components for the Transactions page.

  Components:
    - tx_row/1 — a single row in the transactions table
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.UiComponents

  @doc """
  Purpose: renders one row inside the transactions table.

  Use: pass a transaction map with date, description, amount, category, tags, and source.

  Example:

      <.tx_row
        tx=%{
          date: "2026-03-02",
          description: "QQQD BUY",
          amount: -2640.0,
          currency: "USD",
          category: "Investments:Buy",
          tags: ["etf"],
          source: "import:broker_statement",
          overridden: true
        }
      />
  """
  attr :tx, :map, required: true

  def tx_row(assigns) do
    ~H"""
    <tr>
      <td class="au-mono whitespace-nowrap">{@tx.date}</td>
      <td>
        <div class="text-white/92">{@tx.description}</div>
        <div class="flex gap-[4px] mt-[4px] flex-wrap items-center">
          <span class="text-[12px] text-white/50">{dgettext("transactions", "col_tags")}:</span>
          <.badge :for={tag <- @tx.tags}>{tag}</.badge>
        </div>
      </td>
      <td class={["au-mono whitespace-nowrap", amount_class(@tx.amount)]}>
        {format_money(@tx.amount, @tx.currency)}
      </td>
      <td class="au-mono">{@tx.currency}</td>
      <td>
        <div class="text-white/92">{@tx.category}</div>
        <div class="mt-[4px]">
          <.badge variant={overlay_variant(@tx.overridden)}>
            {overlay_label(@tx.overridden)}
          </.badge>
        </div>
      </td>
      <td class="au-mono text-white/68">{@tx.source}</td>
    </tr>
    """
  end

  defp amount_class(amount) when amount < 0, do: "au-debit"
  defp amount_class(_), do: "au-credit"

  defp overlay_variant(true), do: :warn
  defp overlay_variant(_), do: :good

  defp overlay_label(true), do: dgettext("transactions", "overlay_manual")
  defp overlay_label(_), do: dgettext("transactions", "overlay_rule")
end
