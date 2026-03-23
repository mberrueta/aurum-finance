defmodule AurumFinanceWeb.NetWorthComponents do
  @moduledoc """
  Components for the Net Worth page.
  """

  use AurumFinanceWeb, :html

  attr :account_id, :string, required: true
  attr :account_row, :map, required: true
  attr :drilldown_data, :map, required: true
  attr :drilldown_page, :integer, required: true

  def drilldown_panel(assigns) do
    ~H"""
    <div class="rounded-3xl border border-white/10 bg-[#0b1324] p-4 shadow-[0_18px_40px_rgba(4,11,25,0.28)] sm:p-5">
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div class="min-w-0 space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <h3 class="text-sm font-semibold tracking-[0.08em] text-white/90 uppercase">
              {dgettext("reports", "drilldown_header")}
            </h3>
            <.badge :if={@account_row.coverage == :refreshable_gap} variant={:warn}>
              {dgettext("reports", "drilldown_outdated_badge")}
            </.badge>
          </div>
          <p class="text-sm text-white/70">
            {dgettext("reports", "drilldown_summary",
              amount: format_money(@account_row.balance, @account_row.currency_code),
              date: Date.to_iso8601(@account_row.snapshot_date_used)
            )}
          </p>
        </div>

        <div
          :if={@drilldown_data.total_pages > 1}
          class="flex items-center gap-2 text-xs text-white/54"
        >
          <span class="rounded-full border border-white/10 px-3 py-1">
            {dgettext("reports", "drilldown_page_info",
              page: @drilldown_page,
              total_pages: @drilldown_data.total_pages
            )}
          </span>
          <.button
            id={"net-worth-drilldown-prev-#{@account_id}"}
            type="button"
            phx-click="change_drilldown_page"
            phx-value-page={@drilldown_page - 1}
            disabled={@drilldown_page <= 1}
            title={dgettext("reports", "drilldown_prev")}
            aria-label={dgettext("reports", "drilldown_prev")}
            class="au-btn px-3"
          >
            <.icon name="hero-chevron-left" class="size-4" />
          </.button>
          <.button
            id={"net-worth-drilldown-next-#{@account_id}"}
            type="button"
            phx-click="change_drilldown_page"
            phx-value-page={@drilldown_page + 1}
            disabled={@drilldown_page >= @drilldown_data.total_pages}
            variant="primary"
            title={dgettext("reports", "drilldown_next")}
            aria-label={dgettext("reports", "drilldown_next")}
            class="px-3"
          >
            <.icon name="hero-chevron-right" class="size-4" />
          </.button>
        </div>
      </div>

      <div class="mt-4 overflow-x-auto">
        <table class="au-table">
          <thead>
            <tr>
              <th>{dgettext("reports", "drilldown_table_date")}</th>
              <th>{dgettext("reports", "drilldown_table_description")}</th>
              <th class="text-right">{dgettext("reports", "drilldown_table_amount")}</th>
            </tr>
          </thead>
          <tbody :if={@drilldown_data.transactions != []}>
            <tr
              :for={transaction <- @drilldown_data.transactions}
              id={"net-worth-drilldown-#{@account_id}-transaction-#{transaction.transaction_id}"}
              class="text-sm text-white/82"
            >
              <td class="au-mono whitespace-nowrap text-white/68">
                {Date.to_iso8601(transaction.date)}
              </td>
              <td class="text-white/90">{transaction.description}</td>
              <td class={[
                "au-mono whitespace-nowrap text-right",
                drilldown_amount_class(transaction.net_amount)
              ]}>
                {format_money(transaction.net_amount, @account_row.currency_code)}
              </td>
            </tr>
          </tbody>
        </table>

        <div :if={@drilldown_data.transactions == []} class="py-8">
          <.empty_state text={dgettext("reports", "drilldown_no_transactions")} />
        </div>
      </div>
    </div>
    """
  end

  defp drilldown_amount_class(%Decimal{} = amount) do
    if Decimal.negative?(amount), do: "au-debit", else: "au-credit"
  end
end
