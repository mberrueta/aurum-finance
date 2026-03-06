defmodule AurumFinanceWeb.EntitiesLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Entities

  test "lists active entities by default and can include archived", %{conn: conn} do
    active = entity_fixture(name: "Active visible")
    archived = entity_fixture(name: "Archived hidden")
    {:ok, _archived} = Entities.archive_entity(archived)

    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    assert has_element?(view, "#entities-list")
    assert has_element?(view, "#entity-#{active.id}")
    refute has_element?(view, "#entity-#{archived.id}")

    view
    |> element("#toggle-archived-btn")
    |> render_click()

    assert has_element?(view, "#entity-#{archived.id}")
  end

  test "creates and edits an entity from the form", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    params = %{
      "name" => "LiveView entity",
      "type" => "individual",
      "country_code" => "uy",
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

    view
    |> element("#edit-entity-#{created.id}")
    |> render_click()

    view
    |> form("#entity-form", entity: %{"name" => "LiveView entity updated"})
    |> render_submit()

    updated = Entities.get_entity!(created.id)
    assert updated.name == "LiveView entity updated"
    assert has_element?(view, "#entity-#{created.id}")
  end

  test "archives an entity from the list", %{conn: conn} do
    entity = entity_fixture(name: "Archive from UI")
    {:ok, view, _html} = conn |> log_in_root() |> live("/entities")

    assert has_element?(view, "#archive-entity-#{entity.id}")

    view
    |> element("#archive-entity-#{entity.id}")
    |> render_click()

    archived = Entities.get_entity!(entity.id)
    assert %DateTime{} = archived.archived_at
    refute has_element?(view, "#entity-#{entity.id}")
  end

  defp entity_fixture(attrs) do
    attrs = if Keyword.keyword?(attrs), do: Map.new(attrs), else: attrs

    base = %{
      name: "Entity #{System.unique_integer([:positive])}",
      type: :individual,
      country_code: "BR"
    }

    {:ok, entity} = base |> Map.merge(attrs) |> Entities.create_entity()
    entity
  end
end
