defmodule AurumFinanceWeb.EntitiesLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Entities

  test "lists active entities by default and can include archived", %{conn: conn} do
    active = insert_entity(name: "Active visible")
    archived = insert_entity(name: "Archived hidden")
    {:ok, _archived} = Entities.archive_entity(archived)

    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    assert has_element?(view, "#entities-list")
    assert has_element?(view, "#entities-ownership-boundary")
    assert has_element?(view, "#entities-guidance")
    refute has_element?(view, "#entity-form")
    assert has_element?(view, "#entity-#{active.id}")
    refute has_element?(view, "#entity-#{archived.id}")

    view
    |> element("#toggle-archived-btn")
    |> render_click()

    assert has_element?(view, "#entity-#{archived.id}")
  end

  test "opens and closes the right sidebar for entity forms", %{conn: conn} do
    entity = insert_entity(name: "Sidebar entity")

    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    refute has_element?(view, "#right-sidebar-panel")
    refute has_element?(view, "#entity-form")

    view
    |> element("#new-entity-btn")
    |> render_click()

    assert has_element?(view, "#right-sidebar-panel")
    assert has_element?(view, "#right-sidebar-overlay")
    assert has_element?(view, "#close-sidebar-btn")
    assert has_element?(view, "#entity-form")

    view
    |> element("#cancel-entity-btn")
    |> render_click()

    refute has_element?(view, "#right-sidebar-panel")
    refute has_element?(view, "#entity-form")

    view
    |> element("#edit-entity-#{entity.id}")
    |> render_click()

    assert has_element?(view, "#right-sidebar-panel")
    assert has_element?(view, "#entity-form")
  end

  test "creates and edits an entity from the sidebar form", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    view
    |> element("#new-entity-btn")
    |> render_click()

    params = %{
      "name" => "LiveView entity",
      "type" => "individual",
      "country_code" => "UY",
      "tax_identifier" => "LV-001",
      "notes" => "created from live view"
    }

    view
    |> form("#entity-form", entity: params)
    |> render_submit()

    created = Entities.list_entities(search: "LiveView entity") |> List.first()
    assert created
    assert created.fiscal_residency_country_code == "UY"
    assert has_element?(view, "#entity-#{created.id}")
    refute has_element?(view, "#entity-form")

    view
    |> element("#edit-entity-#{created.id}")
    |> render_click()

    view
    |> form("#entity-form", entity: %{"name" => "LiveView entity updated"})
    |> render_submit()

    updated = Entities.get_entity!(created.id)
    assert updated.name == "LiveView entity updated"
    assert has_element?(view, "#entity-#{created.id}")
    refute has_element?(view, "#entity-form")
  end

  test "archives an entity from the list", %{conn: conn} do
    entity = insert_entity(name: "Archive from UI")
    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    assert has_element?(view, "#archive-entity-#{entity.id}")

    view
    |> element("#archive-entity-#{entity.id}")
    |> render_click()

    archived = Entities.get_entity!(entity.id)
    assert %DateTime{} = archived.archived_at
    refute has_element?(view, "#entity-#{entity.id}")
  end

  test "unarchives an entity from the archived list", %{conn: conn} do
    entity = insert_entity(name: "Unarchive from UI")
    {:ok, _archived} = Entities.archive_entity(entity)

    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    view
    |> element("#toggle-archived-btn")
    |> render_click()

    assert has_element?(view, "#unarchive-entity-#{entity.id}")

    view
    |> element("#unarchive-entity-#{entity.id}")
    |> render_click()

    unarchived = Entities.get_entity!(entity.id)
    assert is_nil(unarchived.archived_at)
    assert has_element?(view, "#entity-#{entity.id}")
    refute has_element?(view, "#unarchive-entity-#{entity.id}")
  end
end
