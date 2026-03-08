defmodule AurumFinanceWeb.ComponentsSmokeTest do
  use AurumFinanceWeb.ConnCase, async: true
  use AurumFinanceWeb, :html

  import Phoenix.LiveViewTest
  import AurumFinanceWeb.AccountsComponents
  import AurumFinanceWeb.DashboardComponents
  import AurumFinanceWeb.ImportComponents
  import AurumFinanceWeb.ReconciliationComponents
  import AurumFinanceWeb.RulesComponents

  test "ui components render" do
    assigns = %{}

    header_html =
      rendered_to_string(~H"""
      <.page_header title="Demo">
        <:subtitle>subtitle</:subtitle>
        <:actions><button class="au-btn">Go</button></:actions>
      </.page_header>
      """)

    badge_html =
      rendered_to_string(~H"""
      <.badge variant={:good}>ok</.badge>
      """)

    spark_html =
      rendered_to_string(~H"""
      <.sparkline series={[1, 2, 3, 2]} />
      """)

    empty_html =
      rendered_to_string(~H"""
      <.empty_state text="nothing" />
      """)

    card_html =
      rendered_to_string(~H"""
      <.au_card>
        <:header><span>Title</span></:header>
        Body
      </.au_card>
      """)

    panel_html =
      rendered_to_string(~H"""
      <.section_panel title="Section" badge="1" badge_variant={:purple}>
        <:actions><button class="au-btn">Act</button></:actions>
        Body
      </.section_panel>
      """)

    assert header_html =~ "au-page-title"
    assert badge_html =~ "au-badge-good"
    assert spark_html =~ "<svg"
    assert empty_html =~ "au-empty"
    assert card_html =~ "au-card"
    assert panel_html =~ "Section"
  end

  test "dashboard components render" do
    assigns = %{}

    kpi_html =
      rendered_to_string(~H"""
      <.kpi_card title="NW" value={1000.0} currency="USD" delta={10.0} series={[1, 2, 3]} />
      """)

    change_html =
      rendered_to_string(~H"""
      <.change_item
        label="Move"
        sub="detail"
        value={-20.0}
        currency="USD"
        sentiment={:warn}
      />
      """)

    alert_html =
      rendered_to_string(~H"""
      <.alert_item title="Missing FX" sub="detail" severity={:warn} />
      """)

    assert kpi_html =~ "au-card"
    assert change_html =~ "au-item"
    assert alert_html =~ "au-item"
  end

  test "accounts components render" do
    account =
      struct(AurumFinance.Ledger.Account,
        id: Ecto.UUID.generate(),
        name: "Broker",
        management_group: :institution,
        account_type: :asset,
        operational_subtype: :brokerage_cash,
        currency_code: "USD",
        institution_name: "Broker LLC",
        notes: "Long-term portfolio"
      )

    entity =
      struct(AurumFinance.Entities.Entity,
        id: Ecto.UUID.generate(),
        name: "Personal",
        type: :individual,
        country_code: "US"
      )

    form =
      AurumFinance.Ledger.change_account(%AurumFinance.Ledger.Account{}, %{
        entity_id: entity.id,
        management_group: :institution,
        account_type: :asset,
        operational_subtype: :bank_checking,
        currency_code: "USD"
      })
      |> to_form(as: :account)

    assigns = %{account: account, entity: entity, form: form}

    tabs_html =
      rendered_to_string(~H"""
      <.management_tabs
        active_tab={:institution}
        counts={%{institution: 2, category: 1, system_managed: 0}}
      />
      """)

    row_html =
      rendered_to_string(~H"""
      <.account_row
        id={"account-#{@account.id}"}
        account={@account}
        editing_account_id={nil}
      />
      """)

    form_html =
      rendered_to_string(~H"""
      <.account_form
        form={@form}
        current_entity={@entity}
        entities={[@entity]}
        editing_account={nil}
        selected_management_group={:institution}
      />
      """)

    assert tabs_html =~ "Institution"
    assert row_html =~ "Broker"
    assert form_html =~ "Create account"
  end

  test "import components render" do
    assigns = %{}

    step_html =
      rendered_to_string(~H"""
      <.import_step label="Preview" index={4} active_step={4} />
      """)

    row_html =
      rendered_to_string(~H"""
      <table>
        <tbody>
          <.preview_row row={
            %{
              date: "2026-01-01",
              description: "UBER",
              amount: -10.0,
              currency: "USD",
              status: :ready,
              hint: "ok"
            }
          } />
        </tbody>
      </table>
      """)

    assert step_html =~ "au-step"
    assert row_html =~ "UBER"
  end

  test "rules components render" do
    assigns = %{}

    group_html =
      rendered_to_string(~H"""
      <.rule_group_item group={%{name: "Expense", description: "desc", rules: [%{id: "r1"}]}} />
      """)

    row_html =
      rendered_to_string(~H"""
      <table>
        <tbody>
          <.rule_row rule={%{order: 1, when: "a", then: "b", stop: true}} />
        </tbody>
      </table>
      """)

    assert group_html =~ "Expense"
    assert row_html =~ "au-mono"
  end

  test "reconciliation components render" do
    assigns = %{}

    session_html =
      rendered_to_string(~H"""
      <.session_item session={%{account: "a_cash_br", period: "2026-03", status: "in_progress"}} />
      """)

    line_html =
      rendered_to_string(~H"""
      <table>
        <tbody>
          <.statement_line_row
            line={%{date: "2026-01-01", desc: "Line", amount: -1.0, currency: "USD"}}
            match={%{state: "reconciled", tx: "tx_1", confidence: 0.9}}
          />
        </tbody>
      </table>
      """)

    discrepancy_html =
      rendered_to_string(~H"""
      <.discrepancy_item discrepancy={%{msg: "missing", type: "missing_tx", severity: "warn"}} />
      """)

    assert session_html =~ "a_cash_br"
    assert line_html =~ "Line"
    assert discrepancy_html =~ "missing"
  end
end
