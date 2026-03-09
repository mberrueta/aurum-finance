defmodule AurumFinanceWeb.AuditLogLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Audit
  alias AurumFinance.Entities
  alias AurumFinance.Ledger

  describe "mount" do
    test "S35: authenticated user can access /audit-log and sees the default page state", %{
      conn: conn
    } do
      entity = entity_fixture(name: unique_name("Mount Entity"))

      {:ok, view, html} = conn |> log_in_root() |> live("/audit-log")

      assert has_element?(view, "#audit-log-page")
      assert has_element?(view, "#audit-log-filter-form")
      assert has_element?(view, "#audit-log-event-#{audit_event_for!(entity_id: entity.id).id}")
      assert html =~ "Audit Log"
      assert has_element?(view, "#audit-log-prev-page[disabled]")
    end

    test "S36: unauthenticated users are redirected away from /audit-log", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, "/audit-log")
    end
  end

  describe "filtering" do
    test "S37: selecting an entity filter patches the URL and restricts events to that owner entity",
         %{
           conn: conn
         } do
      entity_a = entity_fixture(name: unique_name("Owner A"))
      entity_b = entity_fixture(name: unique_name("Owner B"))
      account_a = account_fixture(entity_a, %{name: unique_name("Checking A")})
      account_b = account_fixture(entity_b, %{name: unique_name("Checking B")})

      entity_a_event = audit_event_for!(entity_id: entity_a.id)
      account_a_event = audit_event_for!(entity_id: account_a.id)
      entity_b_event = audit_event_for!(entity_id: entity_b.id)
      account_b_event = audit_event_for!(entity_id: account_b.id)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> form("#audit-log-filter-form", filters: %{"owner_entity_id" => entity_a.id})
      |> render_change()

      assert_patch(view, "/audit-log?q=entity:#{entity_a.id}")
      assert has_element?(view, "#audit-log-event-#{entity_a_event.id}")
      assert has_element?(view, "#audit-log-event-#{account_a_event.id}")
      refute has_element?(view, "#audit-log-event-#{entity_b_event.id}")
      refute has_element?(view, "#audit-log-event-#{account_b_event.id}")
    end

    test "S38: selecting an entity type filter patches the URL and restricts visible events", %{
      conn: conn
    } do
      entity = entity_fixture(name: unique_name("Type Entity"))
      account = account_fixture(entity, %{name: unique_name("Type Account")})

      entity_event = audit_event_for!(entity_id: entity.id)
      account_event = audit_event_for!(entity_id: account.id)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> form("#audit-log-filter-form", filters: %{"entity_type" => "account"})
      |> render_change()

      assert_patch(view, "/audit-log?q=type:account")
      assert has_element?(view, "#audit-log-event-#{account_event.id}")
      refute has_element?(view, "#audit-log-event-#{entity_event.id}")
    end

    test "S39: selecting an action filter patches the URL and restricts visible events", %{
      conn: conn
    } do
      entity = entity_fixture(name: unique_name("Action Entity"))
      {:ok, updated_entity} = Entities.update_entity(entity, %{notes: "updated note"})

      created_event = audit_event_for!(entity_id: entity.id, action: "created")
      updated_event = audit_event_for!(entity_id: updated_entity.id, action: "updated")

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> form("#audit-log-filter-form", filters: %{"action" => "updated"})
      |> render_change()

      assert_patch(view, "/audit-log?q=action:updated")
      assert has_element?(view, "#audit-log-event-#{updated_event.id}")
      refute has_element?(view, "#audit-log-event-#{created_event.id}")
    end

    test "S40: selecting a channel filter patches the URL and combines correctly with action", %{
      conn: conn
    } do
      entity = entity_fixture(name: unique_name("Channel Entity"))

      {:ok, _web_update} =
        Entities.update_entity(entity, %{notes: "web"}, actor: "person", channel: :web)

      {:ok, _system_update} =
        Entities.update_entity(entity, %{notes: "system"}, actor: "scheduler", channel: :system)

      web_updated_event = audit_event_for!(entity_id: entity.id, action: "updated", channel: :web)

      system_updated_event =
        audit_event_for!(entity_id: entity.id, action: "updated", channel: :system)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> form("#audit-log-filter-form", filters: %{"action" => "updated", "channel" => "system"})
      |> render_change()

      assert_patch(view, "/audit-log?q=action:updated&channel:system")
      assert has_element?(view, "#audit-log-event-#{system_updated_event.id}")
      refute has_element?(view, "#audit-log-event-#{web_updated_event.id}")
    end

    test "S41: date preset buttons patch the URL and clearing unmatched filters resets the view",
         %{
           conn: conn
         } do
      entity = entity_fixture(name: unique_name("Date Entity"))
      visible_event = audit_event_for!(entity_id: entity.id)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> element("#audit-log-date-preset-this_month")
      |> render_click()

      assert_patch(view, "/audit-log?q=date:this_month")
      assert has_element?(view, "#audit-log-event-#{visible_event.id}")

      view
      |> form("#audit-log-filter-form", filters: %{"channel" => "ai_assistant"})
      |> render_change()

      assert_patch(view, "/audit-log?q=channel:ai_assistant&date:this_month")
      assert render(view) =~ "No events match the selected filters."

      view
      |> element("a[data-phx-link='patch'][href='/audit-log']")
      |> render_click()

      assert_patch(view, "/audit-log")
      assert has_element?(view, "#audit-log-event-#{visible_event.id}")
    end
  end

  describe "url hydration" do
    test "S42: direct navigation hydrates filters from the compact query string", %{conn: conn} do
      entity = entity_fixture(name: unique_name("Hydrate Entity"))
      account = account_fixture(entity, %{name: unique_name("Hydrate Account")})
      account_event = audit_event_for!(entity_id: account.id, action: "created")

      path =
        "/audit-log?q=entity:#{entity.id}&type:account&action:created&channel:system&date:this_month"

      {:ok, view, _html} = conn |> log_in_root() |> live(path)

      assert has_element?(view, "#audit-log-event-#{account_event.id}")
      assert has_element?(view, "#filters_owner_entity_id option[selected][value='#{entity.id}']")
      assert has_element?(view, "#filters_entity_type option[selected][value='account']")
      assert has_element?(view, "#filters_action option[selected][value='created']")
      assert has_element?(view, "#filters_channel option[selected][value='system']")

      assert has_element?(
               view,
               "#audit-log-filter-form input[name='filters[date_preset]'][value='this_month']"
             )
    end

    test "S43: invalid URL values are ignored or defaulted without breaking the page", %{
      conn: conn
    } do
      entity = entity_fixture(name: unique_name("Fallback Entity"))
      visible_event = audit_event_for!(entity_id: entity.id)

      path =
        "/audit-log?q=entity:not-a-uuid&type:entity&action:created&channel:nope&date:bad&page:0"

      {:ok, view, _html} = conn |> log_in_root() |> live(path)

      assert has_element?(view, "#audit-log-page")
      assert has_element?(view, "#audit-log-event-#{visible_event.id}")
      assert has_element?(view, "#filters_owner_entity_id option[selected][value='']")
      assert has_element?(view, "#filters_entity_type option[selected][value='entity']")
      assert has_element?(view, "#filters_action option[selected][value='created']")
      assert has_element?(view, "#filters_channel option[selected][value='']")

      assert has_element?(
               view,
               "#audit-log-filter-form input[name='filters[date_preset]'][value='all']"
             )

      assert has_element?(view, "#audit-log-prev-page[disabled]")
    end
  end

  describe "pagination" do
    test "S44: first page shows up to 50 events and next navigates to page 2", %{conn: conn} do
      first_inserted =
        Enum.reduce(1..51, nil, fn index, first_event ->
          entity = entity_fixture(name: unique_name("Page Entity #{index}"))
          audit_event = audit_event_for!(entity_id: entity.id)
          first_event || audit_event
        end)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      assert event_card_count(render(view)) == 50
      refute has_element?(view, "#audit-log-event-#{first_inserted.id}")
      refute has_element?(view, "#audit-log-next-page[disabled]")

      view
      |> element("#audit-log-next-page")
      |> render_click()

      assert_patch(view, "/audit-log?q=page:2")
      assert event_card_count(render(view)) == 1
      assert has_element?(view, "#audit-log-event-#{first_inserted.id}")
    end

    test "S45: previous is disabled on page 1 and next is disabled on the last page", %{
      conn: conn
    } do
      Enum.each(1..51, fn index ->
        entity_fixture(name: unique_name("Boundary Entity #{index}"))
      end)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      assert has_element?(view, "#audit-log-prev-page[disabled]")
      refute has_element?(view, "#audit-log-next-page[disabled]")

      view
      |> element("#audit-log-next-page")
      |> render_click()

      assert_patch(view, "/audit-log?q=page:2")
      assert has_element?(view, "#audit-log-next-page[disabled]")
      refute has_element?(view, "#audit-log-prev-page[disabled]")
    end
  end

  describe "expandable rows" do
    test "S46: clicking an event expands and collapses the before/after snapshots", %{conn: conn} do
      entity = entity_fixture(name: unique_name("Expand Entity"))
      {:ok, entity} = Entities.update_entity(entity, %{notes: "expanded detail"})
      updated_event = audit_event_for!(entity_id: entity.id, action: "updated")

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      refute has_element?(view, "#audit-log-event-detail-#{updated_event.id}")

      view
      |> element("#audit-log-event-toggle-#{updated_event.id}")
      |> render_click()

      assert has_element?(view, "#audit-log-event-detail-#{updated_event.id}")
      assert render(view) =~ "expanded detail"

      view
      |> element("#audit-log-event-toggle-#{updated_event.id}")
      |> render_click()

      refute has_element?(view, "#audit-log-event-detail-#{updated_event.id}")
    end

    test "S47: created events show a placeholder when the before snapshot is nil", %{conn: conn} do
      entity = entity_fixture(name: unique_name("Placeholder Entity"))
      created_event = audit_event_for!(entity_id: entity.id, action: "created")

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")

      view
      |> element("#audit-log-event-toggle-#{created_event.id}")
      |> render_click()

      assert has_element?(view, "#audit-log-event-detail-#{created_event.id}")
      assert render(view) =~ "<code>—</code>"
    end
  end

  describe "empty states" do
    test "S48: empty states cover both no events and filter-miss cases", %{conn: conn} do
      {:ok, empty_view, _html} = conn |> log_in_root() |> live("/audit-log")

      assert render(empty_view) =~ "No audit events recorded yet."

      entity = entity_fixture(name: unique_name("Filtered Empty Entity"))
      matching_event = audit_event_for!(entity_id: entity.id)

      {:ok, filtered_view, _html} = conn |> log_in_root() |> live("/audit-log")

      filtered_view
      |> form("#audit-log-filter-form", filters: %{"channel" => "ai_assistant"})
      |> render_change()

      assert render(filtered_view) =~ "No events match the selected filters."

      filtered_view
      |> element("a[data-phx-link='patch'][href='/audit-log']")
      |> render_click()

      assert_patch(filtered_view, "/audit-log")
      assert has_element?(filtered_view, "#audit-log-event-#{matching_event.id}")
    end
  end

  describe "read-only invariant" do
    test "S49: the audit log renders no mutation actions or write handlers", %{conn: conn} do
      entity = entity_fixture(name: unique_name("Read Only Entity"))
      account = transaction_account_fixture(entity)
      transaction = create_transaction_fixture(entity, account)
      assert {:ok, %{voided: _voided, reversal: _reversal}} = Ledger.void_transaction(transaction)

      {:ok, view, _html} = conn |> log_in_root() |> live("/audit-log")
      html = render(view)

      refute html =~ ">Edit<"
      refute html =~ ">Delete<"
      refute html =~ ">Replay<"
      refute html =~ ">Undo<"
      refute html =~ ~s(phx-submit="delete")
      refute html =~ ~s(phx-submit="void")
      refute html =~ ~s(phx-click="delete")
      refute html =~ ~s(phx-click="void")
      refute html =~ ~s(phx-click="replay")
    end
  end

  defp transaction_account_fixture(entity) do
    checking = account_fixture(entity, %{name: unique_name("Read Only Checking")})

    category =
      account_fixture(entity, %{
        name: unique_name("Read Only Category"),
        account_type: :expense,
        operational_subtype: nil,
        management_group: :category
      })

    %{checking: checking, category: category}
  end

  defp create_transaction_fixture(entity, %{checking: checking, category: category}) do
    {:ok, transaction} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: ~D[2026-03-07],
        description: unique_name("Read Only Transaction"),
        source_type: :manual,
        postings: [
          %{account_id: checking.id, amount: Decimal.new("-25.00")},
          %{account_id: category.id, amount: Decimal.new("25.00")}
        ]
      })

    transaction
  end

  defp audit_event_for!(filters) do
    case Audit.list_audit_events(filters) do
      [event | _rest] -> event
      [] -> flunk("expected an audit event for #{inspect(filters)}")
    end
  end

  defp event_card_count(html) do
    Regex.scan(~r/id="audit-log-event-[^"]+" class="overflow-hidden rounded-2xl border/, html)
    |> length()
  end

  defp unique_name(prefix) do
    "#{prefix} #{System.unique_integer([:positive])}"
  end
end
