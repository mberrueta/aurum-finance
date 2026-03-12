defmodule AurumFinanceWeb.ReconciliationLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Ledger
  alias AurumFinance.Reconciliation

  setup %{conn: conn} do
    {:ok, conn: log_in_root(conn)}
  end

  describe ":index" do
    test "renders the page and empty entity state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      assert has_element?(view, "#reconciliation-page")
      assert has_element?(view, "#app-shell-search")
      assert render(view) =~ rt("empty_no_entities")
    end

    test "shows create-account empty state when the current entity has no institution accounts",
         %{
           conn: conn
         } do
      _entity = insert_entity(name: "Reconciliation Empty Accounts")

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      assert has_element?(view, "#reconciliation-empty-accounts")
      assert render(view) =~ rt("empty_no_institution_accounts")
    end

    test "shows empty sessions state when an institution account exists but no sessions exist", %{
      conn: conn
    } do
      entity = insert_entity(name: "Reconciliation Empty Sessions")
      _account = insert_account(entity, %{name: "Primary Checking"})

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      assert has_element?(view, "#reconciliation-empty-sessions")
      assert render(view) =~ rt("empty_no_sessions")
      assert has_element?(view, "#new-reconciliation-session-btn")
    end

    test "session form shows institution accounts only and creates a session", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Session Create")

      institution_account =
        insert_account(entity, %{
          name: "Checking Create",
          account_type: :asset,
          operational_subtype: :bank_checking,
          management_group: :institution
        })

      _category_account =
        insert_account(entity, %{
          name: "Groceries Category",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      view
      |> element("#new-reconciliation-session-btn")
      |> render_click()

      assert has_element?(view, "#reconciliation-session-panel")
      assert render(view) =~ institution_account.name
      refute render(view) =~ "Groceries Category"

      params = %{
        "account_id" => institution_account.id,
        "statement_date" => "2026-03-11",
        "statement_balance" => "125.50"
      }

      view
      |> form("#reconciliation-create-form", reconciliation_session: params)
      |> render_submit()

      session =
        Reconciliation.list_reconciliation_sessions(
          entity_id: entity.id,
          account_id: institution_account.id
        )
        |> List.first()

      assert session
      assert_redirect(view, ~p"/reconciliation/#{session.id}")

      {:ok, detail_view, _html} = live(conn, ~p"/reconciliation/#{session.id}")

      assert has_element?(detail_view, "#reconciliation-back-link")
      assert render(detail_view) =~ institution_account.name
    end

    test "creates a session for a non-default entity without showing a not-found flash", %{
      conn: conn
    } do
      _default_entity = insert_entity(name: "Reconciliation Default Entity")
      selected_entity = insert_entity(name: "Reconciliation Selected Entity")

      selected_account =
        insert_account(selected_entity, %{
          name: "Checking Selected Entity",
          account_type: :asset,
          operational_subtype: :bank_checking,
          management_group: :institution
        })

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      view
      |> form("#reconciliation-entity-selector", %{entity_id: selected_entity.id})
      |> render_change()

      view
      |> element("#new-reconciliation-session-btn")
      |> render_click()

      params = %{
        "account_id" => selected_account.id,
        "statement_date" => "2026-03-11",
        "statement_balance" => "99.00"
      }

      view
      |> form("#reconciliation-create-form", reconciliation_session: params)
      |> render_submit()

      session =
        Reconciliation.list_reconciliation_sessions(
          entity_id: selected_entity.id,
          account_id: selected_account.id
        )
        |> List.first()

      assert session
      assert_redirect(view, ~p"/reconciliation/#{session.id}")

      {:ok, detail_view, _html} = live(conn, ~p"/reconciliation/#{session.id}")

      assert render(detail_view) =~ selected_account.name
      refute render(detail_view) =~ rt("flash_session_not_found")
    end

    test "shows inline errors for invalid session data", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Invalid Session")
      account = insert_account(entity, %{name: "Checking Invalid"})

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      view
      |> element("#new-reconciliation-session-btn")
      |> render_click()

      params = %{
        "account_id" => account.id,
        "statement_date" => "",
        "statement_balance" => "invalid"
      }

      view
      |> form("#reconciliation-create-form", reconciliation_session: params)
      |> render_submit()

      assert has_element?(view, "#reconciliation-create-form")
      assert render(view) =~ "This field is required."
    end

    test "prefills the statement closing date and supports quick presets", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Date Presets")
      _account = insert_account(entity, %{name: "Checking Presets"})

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      view
      |> element("#new-reconciliation-session-btn")
      |> render_click()

      assert has_element?(
               view,
               "#reconciliation_session_statement_date[value='#{default_statement_date()}']"
             )

      view
      |> element("#statement-date-last-year-btn")
      |> render_click()

      assert has_element?(
               view,
               "#reconciliation_session_statement_date[value='#{last_year_statement_date()}']"
             )

      view
      |> element("#statement-date-last-month-btn")
      |> render_click()

      assert has_element?(
               view,
               "#reconciliation_session_statement_date[value='#{default_statement_date()}']"
             )
    end

    test "shows an error when an active session already exists for the account", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Duplicate Session")
      account = insert_account(entity, %{name: "Checking Duplicate"})
      _session = insert_reconciliation_session(entity, account: account)

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      view
      |> element("#new-reconciliation-session-btn")
      |> render_click()

      params = %{
        "account_id" => account.id,
        "statement_date" => "2026-03-12",
        "statement_balance" => "10.00"
      }

      view
      |> form("#reconciliation-create-form", reconciliation_session: params)
      |> render_submit()

      assert has_element?(view, "#reconciliation-create-form")
      assert render(view) =~ "An active reconciliation session already exists for this account."
    end

    test "lists active sessions ahead of completed history with completion details", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Session History")
      account = insert_account(entity, %{name: "Checking History"})

      completed_session =
        insert_reconciliation_session(entity,
          account: account,
          statement_date: ~D[2026-02-28],
          statement_balance: Decimal.new("50.00")
        )

      assert {:ok, completed_session} =
               Reconciliation.complete_reconciliation_session(completed_session)

      active_session =
        insert_reconciliation_session(entity,
          account: account,
          statement_date: ~D[2026-03-11],
          statement_balance: Decimal.new("75.00")
        )

      {:ok, view, _html} = live(conn, ~p"/reconciliation")

      assert has_element?(view, "#reconciliation-session-#{active_session.id}")
      assert has_element?(view, "#reconciliation-session-#{completed_session.id}")
      assert render(view) =~ rt("status_in_progress")
      assert render(view) =~ rt("status_completed")

      html = render(view)
      active_pos = session_position(html, active_session.id)
      completed_pos = session_position(html, completed_session.id)

      assert active_pos < completed_pos
      assert html =~ Calendar.strftime(completed_session.completed_at, "%b %d, %Y %H:%M")
    end
  end

  describe ":show" do
    test "renders postings, summary balances, and status badges", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Detail View")
      account = insert_account(entity, %{name: "Checking Detail"})

      {posting_a, _tx_a} =
        create_reconciliation_posting(entity, account,
          amount: "10.00",
          description: "Salary payment",
          date: ~D[2026-03-01]
        )

      {posting_b, _tx_b} =
        create_reconciliation_posting(entity, account,
          amount: "15.00",
          description: "Cashback reward",
          date: ~D[2026-03-02]
        )

      session =
        insert_reconciliation_session(entity,
          account: account,
          statement_date: ~D[2026-03-11],
          statement_balance: Decimal.new("25.00")
        )

      {:ok, view, _html} = live(conn, ~p"/reconciliation/#{session.id}")

      assert has_element?(view, "#reconciliation-posting-#{posting_a.id}")
      assert has_element?(view, "#reconciliation-posting-#{posting_b.id}")
      assert render(view) =~ "Salary payment"
      assert render(view) =~ "Cashback reward"
      assert render(view) =~ rt("status_unreconciled")
      assert render(view) =~ "25.00 USD"
      assert render(view) =~ "0.00 USD"
    end

    test "marks selected postings as cleared and updates cleared balance", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Clear Flow")
      account = insert_account(entity, %{name: "Checking Clear"})

      {posting, _transaction} =
        create_reconciliation_posting(entity, account,
          amount: "10.00",
          description: "Interest payment",
          date: ~D[2026-03-03]
        )

      session =
        insert_reconciliation_session(entity,
          account: account,
          statement_date: ~D[2026-03-11],
          statement_balance: Decimal.new("10.00")
        )

      {:ok, view, _html} = live(conn, ~p"/reconciliation/#{session.id}")

      view
      |> element("#toggle-posting-#{posting.id}")
      |> render_click()

      view
      |> element("#mark-cleared-btn")
      |> render_click()

      assert Reconciliation.get_posting_reconciliation_status(posting.id) == :cleared

      assert Reconciliation.get_cleared_balance(account.id, entity_id: entity.id) ==
               Decimal.new("10.00")

      assert render(view) =~ rt("flash_postings_cleared")
      assert render(view) =~ rt("status_cleared")
      assert has_element?(view, "#unclear-posting-#{posting.id}")
      assert render(view) =~ "10.00 USD"
    end

    test "un-clears a cleared posting and updates the balances", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Unclear Flow")
      account = insert_account(entity, %{name: "Checking Unclear"})

      {posting, _transaction} =
        create_reconciliation_posting(entity, account,
          amount: "12.50",
          description: "Refund received",
          date: ~D[2026-03-04]
        )

      session =
        insert_reconciliation_session(entity,
          account: account,
          statement_date: ~D[2026-03-11],
          statement_balance: Decimal.new("12.50")
        )

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared([posting.id], session.id,
                 entity_id: entity.id
               )

      {:ok, view, _html} = live(conn, ~p"/reconciliation/#{session.id}")

      assert has_element?(view, "#unclear-posting-#{posting.id}")

      view
      |> element("#unclear-posting-#{posting.id}")
      |> render_click()

      assert Reconciliation.get_posting_reconciliation_status(posting.id) == :unreconciled

      assert Reconciliation.get_cleared_balance(account.id, entity_id: entity.id) ==
               Decimal.new("0")

      assert render(view) =~ rt("flash_posting_uncleared")
      assert render(view) =~ rt("status_unreconciled")
      refute has_element?(view, "#unclear-posting-#{posting.id}")
    end

    test "completes the session and turns the view read-only", %{conn: conn} do
      entity = insert_entity(name: "Reconciliation Complete Flow")
      account = insert_account(entity, %{name: "Checking Complete"})

      {posting, _transaction} =
        create_reconciliation_posting(entity, account,
          amount: "30.00",
          description: "Broker cash sweep",
          date: ~D[2026-03-05]
        )

      session =
        insert_reconciliation_session(entity,
          account: account,
          statement_date: ~D[2026-03-11],
          statement_balance: Decimal.new("30.00")
        )

      assert {:ok, _states} =
               Reconciliation.mark_postings_cleared([posting.id], session.id,
                 entity_id: entity.id
               )

      {:ok, view, _html} = live(conn, ~p"/reconciliation/#{session.id}")

      assert has_element?(view, "#complete-reconciliation-btn")

      view
      |> element("#complete-reconciliation-btn")
      |> render_click()

      completed_session = Reconciliation.get_reconciliation_session!(entity.id, session.id)
      assert %DateTime{} = completed_session.completed_at
      assert Reconciliation.get_posting_reconciliation_status(posting.id) == :reconciled

      assert render(view) =~ rt("flash_session_completed")
      assert render(view) =~ rt("status_completed")
      refute has_element?(view, "#mark-cleared-btn")
      refute has_element?(view, "#complete-reconciliation-btn")
      refute has_element?(view, "#toggle-posting-#{posting.id}")
      refute has_element?(view, "#unclear-posting-#{posting.id}")
    end
  end

  defp create_reconciliation_posting(entity, account, attrs) do
    counterparty =
      insert_account(entity, %{
        name: attrs[:counterparty_name] || "Counterparty #{System.unique_integer([:positive])}",
        account_type: :income,
        operational_subtype: nil,
        management_group: :category
      })

    assert {:ok, transaction} =
             Ledger.create_transaction(%{
               entity_id: entity.id,
               date: Keyword.fetch!(attrs, :date),
               description: Keyword.fetch!(attrs, :description),
               source_type: :manual,
               postings: [
                 %{account_id: account.id, amount: Decimal.new(Keyword.fetch!(attrs, :amount))},
                 %{
                   account_id: counterparty.id,
                   amount: Decimal.negate(Decimal.new(Keyword.fetch!(attrs, :amount)))
                 }
               ]
             })

    posting =
      Enum.find(transaction.postings, fn posting ->
        posting.account_id == account.id
      end)

    {posting, transaction}
  end

  defp session_position(html, session_id) do
    {position, _length} = :binary.match(html, "id=\"reconciliation-session-#{session_id}\"")
    position
  end

  defp default_statement_date do
    Date.utc_today()
    |> Date.beginning_of_month()
    |> Date.add(-1)
    |> Date.to_iso8601()
  end

  defp last_year_statement_date do
    today = Date.utc_today()
    Date.new!(today.year - 1, 12, 31) |> Date.to_iso8601()
  end

  defp rt(key, bindings \\ []) do
    Gettext.dgettext(AurumFinanceWeb.Gettext, "reconciliation", key, bindings)
  end
end
