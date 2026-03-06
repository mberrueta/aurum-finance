defmodule AurumFinanceWeb.AccountsComponents do
  @moduledoc """
  Components for the Accounts page.

  Components:
    - account_group/1  — group header row in the account tree
    - account_row/1    — individual account row with subtype badge and balance
    - mini_tx_row/1    — compact transaction row in the account detail panel
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.UiComponents

  @doc """
  Purpose: renders a grouped header row in the accounts tree.

  Use: pass group label and account count.

  Example:

      <.account_group label="Assets" count={3} />
  """
  attr :label, :string, required: true
  attr :count, :integer, required: true

  def account_group(assigns) do
    ~H"""
    <div class="au-item au-tree-group">
      <div class="flex items-center gap-[8px]">
        <.badge variant={:purple}>{@label}</.badge>
        <span class="text-[12px] text-white/50">
          {@count} {dgettext("accounts", "label_accounts")}
        </span>
      </div>
      <span class="text-[13px] text-white/50">—</span>
    </div>
    """
  end

  @doc """
  Purpose: renders one account entry row with balance and metadata.

  Use: pass an `account` map and selected `display_currency`.

  Example:

      <.account_row
        account=%{name: "Broker", subtype: "brokerage", type: "asset", currencies: ["USD"], balance: 85_234.0}
        display_currency="USD"
      />
  """
  attr :account, :map, required: true
  attr :display_currency, :string, required: true

  def account_row(assigns) do
    ~H"""
    <div class="au-item cursor-pointer">
      <div class="flex items-center gap-[8px] min-w-0">
        <.badge>{@account.subtype}</.badge>
        <div class="min-w-0">
          <div class="text-[13px] text-white/92 truncate">{@account.name}</div>
          <div class="text-[12px] text-white/50 mt-[2px]">
            {@account.type} • {Enum.join(@account.currencies, ", ")}
          </div>
        </div>
      </div>
      <div class="au-mono text-[12px] text-white/68 shrink-0">
        {format_money(@account.balance, @display_currency)}
      </div>
    </div>
    """
  end

  @doc """
  Purpose: renders a compact transaction row for account detail panels.

  Use: pass a transaction map with description/date/amount/currency.

  Example:

      <.mini_tx_row tx=%{description: "Salary", date: "2026-02-28", amount: 4200.0, currency: "USD"} />
  """
  attr :tx, :map, required: true

  def mini_tx_row(assigns) do
    ~H"""
    <div class="au-item">
      <div class="min-w-0">
        <div class="text-[13px] text-white/92 truncate">{@tx.description}</div>
        <div class="text-[12px] text-white/50 mt-[2px]">{@tx.date}</div>
      </div>
      <div class="au-mono text-[13px] shrink-0">{format_money(@tx.amount, @tx.currency)}</div>
    </div>
    """
  end
end
