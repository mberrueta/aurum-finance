defmodule AurumFinanceWeb.TransactionsComponents do
  @moduledoc """
  Components for the Transactions page.
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.BadgeComponent, only: [account_type_label: 1]
  import AurumFinanceWeb.UiComponents

  attr :id, :string, required: true
  attr :transaction, :map, required: true
  attr :expanded_transaction_id, :any, default: nil

  def tx_row(assigns) do
    ~H"""
    <tbody id={@id} class="border-t border-white/6 first:border-t-0">
      <tr
        id={"#{@id}-summary"}
        phx-click="toggle_transaction"
        phx-value-id={@transaction.id}
        class="cursor-pointer transition hover:bg-white/[0.04]"
      >
        <td class="px-4 py-3 au-mono whitespace-nowrap text-white/72">
          {Date.to_iso8601(@transaction.date)}
        </td>
        <td class="px-4 py-3 text-white/92">
          <div>{@transaction.description}</div>
          <div :if={@transaction.correlation_id} class="mt-1 text-xs text-white/45 au-mono">
            {dgettext("transactions", "label_correlation_id")}: {@transaction.correlation_id}
          </div>
        </td>
        <td class="px-4 py-3">
          <.badge variant={source_badge_variant(@transaction.source_type)}>
            {source_badge_label(@transaction.source_type)}
          </.badge>
        </td>
        <td class="px-4 py-3 au-mono text-white/72">
          {length(@transaction.postings)}
        </td>
        <td class="px-4 py-3">
          <.badge :if={@transaction.voided_at} variant={:bad}>
            {dgettext("transactions", "badge_voided")}
          </.badge>
        </td>
      </tr>
      <tr :if={@expanded_transaction_id == @transaction.id} id={"#{@id}-detail"}>
        <td colspan="5" class="px-4 pb-4">
          <.tx_posting_detail transaction={@transaction} />
        </td>
      </tr>
    </tbody>
    """
  end

  attr :transaction, :map, required: true

  def tx_posting_detail(assigns) do
    ~H"""
    <div class="mt-2 rounded-2xl border border-white/10 bg-white/[0.03] p-4">
      <div class="flex flex-wrap items-center gap-2">
        <h4 class="text-sm font-semibold text-white/90">
          {dgettext("transactions", "posting_detail_title")}
        </h4>
        <.badge variant={source_badge_variant(@transaction.source_type)}>
          {source_badge_label(@transaction.source_type)}
        </.badge>
        <.badge :if={@transaction.voided_at} variant={:bad}>
          {dgettext("transactions", "badge_voided")}
        </.badge>
      </div>

      <div class="mt-3 grid gap-3 text-sm text-white/68 sm:grid-cols-3">
        <div>
          <div class="text-[11px] uppercase tracking-[0.16em] text-white/38">
            {dgettext("transactions", "col_date")}
          </div>
          <div class="mt-1 text-white/88 au-mono">{Date.to_iso8601(@transaction.date)}</div>
        </div>
        <div>
          <div class="text-[11px] uppercase tracking-[0.16em] text-white/38">
            {dgettext("transactions", "col_description")}
          </div>
          <div class="mt-1 text-white/88">{@transaction.description}</div>
        </div>
        <div :if={@transaction.voided_at}>
          <div class="text-[11px] uppercase tracking-[0.16em] text-white/38">
            {dgettext("transactions", "label_voided_at")}
          </div>
          <div class="mt-1 text-white/88 au-mono">{DateTime.to_iso8601(@transaction.voided_at)}</div>
        </div>
      </div>

      <div class="mt-4 overflow-x-auto">
        <table class="au-table">
          <thead>
            <tr>
              <th>{dgettext("transactions", "col_account")}</th>
              <th>{dgettext("transactions", "col_account_type")}</th>
              <th>{dgettext("transactions", "col_amount")}</th>
              <th>{dgettext("transactions", "col_currency")}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={posting <- @transaction.postings} id={"posting-#{posting.id}"}>
              <td class="text-white/88">{posting.account.name}</td>
              <td class="text-white/72">{account_type_label(posting.account.account_type)}</td>
              <td class={["au-mono whitespace-nowrap", amount_class(posting.amount)]}>
                {Decimal.to_string(posting.amount)}
              </td>
              <td class="au-mono text-white/72">{posting.account.currency_code}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp amount_class(%Decimal{} = amount) do
    if Decimal.negative?(amount), do: "au-debit", else: "au-credit"
  end

  defp source_badge_variant(:manual), do: :purple
  defp source_badge_variant(:import), do: :good
  defp source_badge_variant(:system), do: :warn

  defp source_badge_label(:manual), do: dgettext("transactions", "badge_manual")
  defp source_badge_label(:import), do: dgettext("transactions", "badge_import")
  defp source_badge_label(:system), do: dgettext("transactions", "badge_system")
end
