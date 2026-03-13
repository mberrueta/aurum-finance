defmodule AurumFinanceWeb.RulesLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Classification

  test "renders only groups visible to the selected entity", %{conn: conn} do
    visible_entity = insert_entity(name: "Alpha Rules Entity")
    hidden_entity = insert_entity(name: "Zulu Rules Entity")
    visible_account = insert_account(visible_entity, %{name: "Visible checking"})

    global_group = insert_global_rule_group(%{name: "Global Rules"})
    entity_group = insert_rule_group(visible_entity, %{name: "Entity Rules"})
    account_group = insert_account_rule_group(visible_account, %{name: "Account Rules"})
    _hidden_group = insert_rule_group(hidden_entity, %{name: "Hidden Rules"})

    path = ~p"/rules?#{%{"entity_id" => visible_entity.id, "group_id" => account_group.id}}"
    {:ok, view, _html} = conn |> log_in_root() |> live(path)

    assert has_element?(view, "#rules-page")
    assert has_element?(view, "#rule-group-#{global_group.id}")
    assert has_element?(view, "#rule-group-#{entity_group.id}")
    assert has_element?(view, "#rule-group-#{account_group.id}")
    refute render(view) =~ "Hidden Rules"
  end

  test "creates a rule group from the slideover", %{conn: conn} do
    entity = insert_entity(name: "Create Group Entity")
    insert_rule_group(entity, %{name: "Existing One", priority: 1})
    insert_rule_group(entity, %{name: "Existing Two", priority: 1})

    {:ok, view, _html} = conn |> log_in_root() |> live(~p"/rules?#{%{"entity_id" => entity.id}}")

    view
    |> element("#new-rule-group-button")
    |> render_click()

    assert has_element?(view, "#rule-group-form")
    assert has_element?(view, "#rule_group_priority[value='3']")

    params = %{
      "scope_type" => "entity",
      "entity_id" => entity.id,
      "name" => "Expense Classification",
      "priority" => "2",
      "description" => "Entity scoped classification rules",
      "target_fields" => ["category", "tags"],
      "is_active" => "true"
    }

    view
    |> form("#rule-group-form", rule_group: params)
    |> render_submit()

    [created_group] =
      Classification.list_visible_rule_groups(entity.id, [])
      |> Enum.filter(&(&1.name == "Expense Classification"))

    assert has_element?(view, "#rule-group-#{created_group.id}")
    refute has_element?(view, "#rule-group-form")
  end

  test "deletes a visible rule group", %{conn: conn} do
    entity = insert_entity(name: "Delete Group Entity")
    group = insert_rule_group(entity, %{name: "Delete Me"})

    path = ~p"/rules?#{%{"entity_id" => entity.id, "group_id" => group.id}}"
    {:ok, view, _html} = conn |> log_in_root() |> live(path)

    assert has_element?(view, "#rule-group-#{group.id}")

    view
    |> element("#delete-rule-group-#{group.id}")
    |> render_click()

    refute has_element?(view, "#rule-group-#{group.id}")
    assert_raise Ecto.NoResultsError, fn -> Classification.get_rule_group!(group.id) end
  end

  test "updates selected group active state and priority from detail actions", %{conn: conn} do
    entity = insert_entity(name: "Selected Group Actions Entity")
    first_group = insert_rule_group(entity, %{name: "First", priority: 1})
    second_group = insert_rule_group(entity, %{name: "Second", priority: 2, is_active: true})
    third_group = insert_rule_group(entity, %{name: "Third", priority: 3})

    path = ~p"/rules?#{%{"entity_id" => entity.id, "group_id" => second_group.id}}"
    {:ok, view, _html} = conn |> log_in_root() |> live(path)

    assert has_element?(view, "#toggle-selected-rule-group-active")
    assert has_element?(view, "#raise-selected-rule-group-priority")
    assert has_element?(view, "#lower-selected-rule-group-priority")

    view
    |> element("#toggle-selected-rule-group-active")
    |> render_click()

    refute Classification.get_rule_group!(second_group.id).is_active

    view
    |> element("#raise-selected-rule-group-priority")
    |> render_click()

    assert Classification.get_rule_group!(second_group.id).priority == 1
    assert has_element?(view, "#lower-selected-rule-group-priority")
    refute has_element?(view, "#raise-selected-rule-group-priority")

    assert Classification.get_rule_group!(first_group.id).priority == 1
    assert Classification.get_rule_group!(third_group.id).priority == 3
  end

  test "selected group can move to a larger priority number when duplicates exist", %{conn: conn} do
    entity = insert_entity(name: "Duplicate Priority Entity")
    first_group = insert_rule_group(entity, %{name: "First", priority: 1})
    second_group = insert_rule_group(entity, %{name: "Second", priority: 1})

    path = ~p"/rules?#{%{"entity_id" => entity.id, "group_id" => first_group.id}}"
    {:ok, view, _html} = conn |> log_in_root() |> live(path)

    assert has_element?(view, "#lower-selected-rule-group-priority")
    refute has_element?(view, "#raise-selected-rule-group-priority")

    view
    |> element("#lower-selected-rule-group-priority")
    |> render_click()

    assert Classification.get_rule_group!(first_group.id).priority == 2
    assert Classification.get_rule_group!(second_group.id).priority == 1
  end

  test "creates and edits rules through builder and advanced mode flows", %{conn: conn} do
    entity = insert_entity(name: "Rules Flow Entity")
    group = insert_rule_group(entity, %{name: "Merchant Rules"})

    path = ~p"/rules?#{%{"entity_id" => entity.id, "group_id" => group.id}}"
    {:ok, view, _html} = conn |> log_in_root() |> live(path)

    view
    |> element("#new-rule-button")
    |> render_click()

    assert has_element?(view, "#rule-form")
    assert has_element?(view, "#condition-row-0")
    assert has_element?(view, "#action-row-0")

    create_params = %{
      "rule_group_id" => group.id,
      "name" => "Uber Rule",
      "description" => "Marks rides",
      "position" => "1",
      "is_active" => "true",
      "stop_processing" => "true",
      "conditions" => %{
        "0" => %{
          "field" => "description",
          "operator" => "contains",
          "value" => "Uber",
          "negate" => "false"
        }
      },
      "actions" => %{
        "0" => %{
          "field" => "tags",
          "operation" => "add",
          "value" => "ride"
        }
      }
    }

    view
    |> form("#rule-form", rule: create_params)
    |> render_submit()

    created_rule =
      Classification.list_rules(rule_group_id: group.id)
      |> Enum.find(&(&1.name == "Uber Rule"))

    assert created_rule
    assert created_rule.expression == ~s|(description contains "Uber")|
    assert has_element?(view, "#rule-#{created_rule.id}")

    view
    |> element("#edit-rule-#{created_rule.id}")
    |> render_click()

    assert has_element?(view, "#rule-expression")

    edit_params = %{
      "rule_group_id" => group.id,
      "name" => "Uber Rule Updated",
      "description" => "Advanced mode update",
      "position" => "1",
      "is_active" => "true",
      "stop_processing" => "false",
      "expression" => ~s|description starts_with "Uber"|,
      "actions" => %{
        "0" => %{
          "field" => "tags",
          "operation" => "add",
          "value" => "priority-vendor"
        }
      }
    }

    view
    |> form("#rule-form", rule: edit_params)
    |> render_submit()

    updated_rule = Classification.get_rule!(created_rule.id)
    assert updated_rule.name == "Uber Rule Updated"
    assert updated_rule.expression == ~s|description starts_with "Uber"|
    assert updated_rule.stop_processing == false
  end
end
