defmodule AurumFinanceWeb.AuditLogLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Audit
  alias AurumFinance.Ledger

  describe "mount" do
    test "renders the empty operational audit state", %{conn: conn} do
      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      assert has_element?(view, "#audit-log-page")
      assert render(view) =~ "This view records operational, administrative, and manual changes."
      assert render(view) =~ "No audit events recorded yet."
    end
  end

  describe "events" do
    test "filters by entity type from the form and expands event details", %{conn: conn} do
      entity = entity_fixture(name: "Audit UI Entity")
      _account = account_fixture(entity, %{name: "Audit UI Account"})

      [account_event] = Audit.list_audit_events(entity_type: "account")

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> form("#audit-log-filter-form", filters: %{"entity_type" => "account"})
      |> render_change()

      assert_patch(view, "/audit-log?q=type:account")
      assert has_element?(view, "#audit-log-event-#{account_event.id}")

      view
      |> element("#audit-log-event-toggle-#{account_event.id}")
      |> render_click()

      assert has_element?(view, "#audit-log-event-detail-#{account_event.id}")
    end

    test "filters by owning entity while keeping entity id in the URL", %{conn: conn} do
      entity = entity_fixture(name: "Visible Audit Entity")

      [entity_event] = Audit.list_audit_events(entity_type: "entity")

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      assert render(view) =~ "Visible Audit Entity"

      view
      |> form("#audit-log-filter-form", filters: %{"owner_entity_id" => entity.id})
      |> render_change()

      assert_patch(view, "/audit-log?q=entity:#{entity.id}")
      assert has_element?(view, "#audit-log-event-#{entity_event.id}")
    end

    test "shows filtered empty state and clear filters link when no rows match", %{conn: conn} do
      entity = entity_fixture(name: "Audit Empty Filter Entity")
      _account = account_fixture(entity, %{name: "Audit Empty Filter Account"})

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> form("#audit-log-filter-form", filters: %{"action" => "voided"})
      |> render_change()

      assert render(view) =~ "No events match the selected filters."
      assert has_element?(view, ~s(a[href="/audit-log"]))
    end

    test "shows void events and remains read-only", %{conn: conn} do
      entity = entity_fixture(name: "Audit UI Voided Entity")
      checking = account_fixture(entity, %{name: "Audit UI Checking"})

      groceries =
        account_fixture(entity, %{
          name: "Audit UI Groceries",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      {:ok, transaction} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-07],
          description: "Audit UI void",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-15.00")},
            %{account_id: groceries.id, amount: Decimal.new("15.00")}
          ]
        })

      assert {:ok, %{voided: voided}} = Ledger.void_transaction(transaction)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log?q=type:transaction")

      assert has_element?(
               view,
               "#audit-log-event-#{List.first(Audit.list_audit_events(entity_id: voided.id)).id}"
             )

      html = render(view)
      refute html =~ "Replay"
      refute html =~ "Delete"
      refute html =~ "Undo"
    end
  end
end
