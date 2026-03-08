defmodule AurumFinanceWeb.TransactionsComponentsTest do
  use AurumFinanceWeb.ConnCase, async: true
  use AurumFinanceWeb, :html

  import Phoenix.LiveViewTest
  import AurumFinanceWeb.TransactionsComponents

  test "tx_row renders transaction summary" do
    transaction =
      struct(AurumFinance.Ledger.Transaction,
        id: Ecto.UUID.generate(),
        date: ~D[2026-01-01],
        description: "Coffee",
        source_type: :manual,
        correlation_id: nil,
        voided_at: nil,
        postings: [
          struct(AurumFinance.Ledger.Posting,
            id: Ecto.UUID.generate(),
            amount: Decimal.new("-5.00"),
            account:
              struct(AurumFinance.Ledger.Account,
                name: "Cash",
                account_type: :asset,
                currency_code: "USD"
              )
          )
        ]
      )

    assigns = %{transaction: transaction}

    html =
      rendered_to_string(~H"""
      <table>
        <.tx_row
          id={"transaction-#{@transaction.id}"}
          transaction={@transaction}
          expanded_transaction_id={nil}
        />
      </table>
      """)

    assert html =~ "Coffee"
    assert html =~ "Manual"
    assert html =~ "1"
  end

  test "tx_posting_detail renders posting data" do
    transaction =
      struct(AurumFinance.Ledger.Transaction,
        id: Ecto.UUID.generate(),
        date: ~D[2026-01-01],
        description: "Coffee",
        source_type: :manual,
        correlation_id: Ecto.UUID.generate(),
        voided_at: ~U[2026-01-02 10:00:00Z],
        postings: [
          struct(AurumFinance.Ledger.Posting,
            id: Ecto.UUID.generate(),
            amount: Decimal.new("-5.00"),
            account:
              struct(AurumFinance.Ledger.Account,
                name: "Cash",
                account_type: :asset,
                currency_code: "USD"
              )
          )
        ]
      )

    assigns = %{transaction: transaction}

    html =
      rendered_to_string(~H"""
      <.tx_posting_detail transaction={@transaction} />
      """)

    assert html =~ "Postings"
    assert html =~ "Cash"
    assert html =~ "USD"
    assert html =~ "-5.00"
    assert html =~ "Voided"
  end
end
