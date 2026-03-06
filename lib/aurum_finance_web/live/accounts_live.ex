defmodule AurumFinanceWeb.AccountsLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.AccountsComponents

  def mount(_params, _session, socket) do
    data = mock_data()

    {:ok,
     socket
     |> assign(:active_nav, :accounts)
     |> assign(:page_title, dgettext("accounts", "page_title"))
     |> assign(data)}
  end

  def render(assigns) do
    ~H"""
    <div id="accounts-page">
      <.page_header title={dgettext("accounts", "page_title")}>
        <:subtitle>{dgettext("accounts", "page_subtitle")}</:subtitle>
      </.page_header>

      <div class="grid grid-cols-2 gap-[14px]">
        <%!-- Account tree --%>
        <.au_card>
          <:header>
            <span>{dgettext("accounts", "section_accounts")}</span>
            <.badge variant={:purple}>{length(@accounts)}</.badge>
          </:header>

          <div class="au-list">
            <%= for {group, group_accounts} <- @grouped_accounts do %>
              <.account_group label={group} count={length(group_accounts)} />
              <.account_row
                :for={account <- group_accounts}
                account={account}
                display_currency={@display_currency}
              />
            <% end %>
          </div>
        </.au_card>

        <%!-- Account detail panel --%>
        <.au_card>
          <:header>
            <span>{@selected.name}</span>
            <.badge variant={:purple}>{@selected.subtype}</.badge>
          </:header>

          <div class="mt-[10px] text-[20px] au-mono text-white/92">
            {format_money(@selected.balance, @display_currency)}
          </div>
          <p class="text-[12px] text-white/68 mt-[4px]">
            {dgettext("accounts", "label_balance_note")}
          </p>

          <div class="au-hr"></div>

          <div class="flex items-center justify-between text-[13px]">
            <span class="text-white/68">{dgettext("accounts", "label_currencies")}</span>
            <div class="flex gap-[6px] flex-wrap">
              <.badge :for={cur <- @selected.currencies}>{cur}</.badge>
            </div>
          </div>

          <div class="au-hr"></div>

          <p class="text-[12px] text-white/68 mb-[8px]">
            {dgettext("accounts", "label_recent_activity")}
          </p>
          <div class="au-list">
            <.mini_tx_row :for={tx <- @recent_transactions} tx={tx} />
          </div>
        </.au_card>
      </div>
    </div>
    """
  end

  # ── Mock data ──────────────────────────────────────────────────────────────────

  defp mock_data do
    accounts = [
      %{
        id: "a_cash_br",
        name: "Banco Inter • Checking",
        type: "asset",
        subtype: "checking",
        currencies: ["BRL"],
        group: "Assets",
        balance: 8_420.0
      },
      %{
        id: "a_broker_us",
        name: "US Broker • Taxable",
        type: "asset",
        subtype: "brokerage",
        currencies: ["USD"],
        group: "Assets",
        balance: 85_234.0
      },
      %{
        id: "a_cc_br",
        name: "Nubank • Credit Card",
        type: "liability",
        subtype: "credit_card",
        currencies: ["BRL"],
        group: "Liabilities",
        balance: -4_640.0
      },
      %{
        id: "a_income",
        name: "Salary",
        type: "income",
        subtype: "salary",
        currencies: ["USD"],
        group: "Income",
        balance: 4_200.0
      },
      %{
        id: "a_expenses",
        name: "Living Expenses",
        type: "expense",
        subtype: "general",
        currencies: ["BRL", "USD"],
        group: "Expenses",
        balance: -4_640.0
      }
    ]

    group_order = ["Assets", "Liabilities", "Income", "Expenses"]
    grouped = Enum.group_by(accounts, & &1.group)

    grouped_accounts =
      group_order
      |> Enum.filter(&Map.has_key?(grouped, &1))
      |> Enum.map(&{&1, grouped[&1]})

    recent_transactions = [
      %{
        description: "Broker Buy: QQQD (83 shares)",
        date: "2026-03-02",
        amount: -2_640.0,
        currency: "USD"
      },
      %{
        description: "Uber trip",
        date: "2026-03-01",
        amount: -47.90,
        currency: "BRL"
      },
      %{
        description: "Salary payment",
        date: "2026-02-28",
        amount: 4_200.0,
        currency: "USD"
      }
    ]

    %{
      accounts: accounts,
      grouped_accounts: grouped_accounts,
      selected: List.first(accounts),
      display_currency: "USD",
      recent_transactions: recent_transactions
    }
  end
end
