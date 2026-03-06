defmodule AurumFinanceWeb.TransactionsLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.TransactionsComponents

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_nav, :transactions)
     |> assign(:page_title, dgettext("transactions", "page_title"))
     |> assign(:transactions, mock_transactions())}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={dgettext("transactions", "page_title")}>
        <:subtitle>{dgettext("transactions", "page_subtitle")}</:subtitle>
        <:actions>
          <button class="au-btn au-btn-primary">{dgettext("transactions", "btn_add_manual")}</button>
          <button class="au-btn">{dgettext("transactions", "btn_import")}</button>
        </:actions>
      </.page_header>

      <%!-- Active filters --%>
      <div class="flex gap-[10px] flex-wrap mb-[12px]">
        <.badge>{dgettext("transactions", "filter_date")}</.badge>
        <.badge>{dgettext("transactions", "filter_source")}</.badge>
        <.badge>{dgettext("transactions", "filter_account")}</.badge>
        <.badge>{dgettext("transactions", "filter_category")}</.badge>
      </div>

      <%!-- Transactions table --%>
      <.au_card>
        <table class="au-table">
          <thead>
            <tr>
              <th>{dgettext("transactions", "col_date")}</th>
              <th>{dgettext("transactions", "col_description")}</th>
              <th>{dgettext("transactions", "col_amount")}</th>
              <th>{dgettext("transactions", "col_currency")}</th>
              <th>{dgettext("transactions", "col_category")}</th>
              <th>{dgettext("transactions", "col_source")}</th>
            </tr>
          </thead>
          <tbody>
            <.tx_row :for={tx <- @transactions} tx={tx} />
          </tbody>
        </table>
      </.au_card>
    </div>
    """
  end

  # ── Mock data ──────────────────────────────────────────────────────────────────

  defp mock_transactions do
    [
      %{
        date: "2026-03-02",
        description: "Broker Buy: QQQD (83 shares)",
        amount: -2_640.0,
        currency: "USD",
        category: "Investments:Buy",
        tags: ["etf", "nasdaq"],
        source: "import:broker_statement",
        overridden: true
      },
      %{
        date: "2026-03-01",
        description: "Uber trip",
        amount: -47.90,
        currency: "BRL",
        category: "Transport",
        tags: ["ride"],
        source: "import:bank_csv",
        overridden: false
      },
      %{
        date: "2026-02-28",
        description: "Salary payment",
        amount: 4_200.0,
        currency: "USD",
        category: "Income:Salary",
        tags: ["payroll"],
        source: "import:bank_csv",
        overridden: false
      },
      %{
        date: "2026-03-03",
        description: "Dividend: VT",
        amount: 38.20,
        currency: "USD",
        category: "Income:Dividend",
        tags: ["dividend"],
        source: "import:broker_statement",
        overridden: false
      }
    ]
  end
end
