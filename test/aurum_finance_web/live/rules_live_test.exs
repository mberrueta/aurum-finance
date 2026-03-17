defmodule AurumFinanceWeb.RulesLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Classification
  alias AurumFinance.Ledger

  defp create_preview_transaction(entity, account, opts) do
    date = Keyword.get(opts, :date, ~D[2026-03-14])
    description = Keyword.get(opts, :description, "Uber trip")
    amount = Keyword.get(opts, :amount, "-10.00")

    contra_account =
      case Keyword.get(opts, :contra_account) do
        nil ->
          insert_account(entity, %{
            name: "Contra Expense",
            account_type: :expense,
            management_group: :category,
            operational_subtype: nil,
            institution_name: nil,
            institution_account_ref: nil
          })

        account ->
          account
      end

    {:ok, transaction} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: date,
        description: description,
        source_type: :manual,
        postings: [
          %{account_id: account.id, amount: amount},
          %{account_id: contra_account.id, amount: negate_amount(amount)}
        ]
      })

    transaction
  end

  defp negate_amount(amount) when is_binary(amount) do
    amount
    |> Decimal.new()
    |> Decimal.negate()
    |> Decimal.to_string()
  end

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

  test "handles scope specific form inputs and edits group scope", %{conn: conn} do
    entity = insert_entity(name: "Scope Form Entity")
    account = insert_account(entity, %{name: "Scope Checking"})

    {:ok, view, _html} = conn |> log_in_root() |> live(~p"/rules?#{%{"entity_id" => entity.id}}")

    view
    |> element("#new-rule-group-button")
    |> render_click()

    assert has_element?(view, "#rule-group-form")
    assert has_element?(view, "#rule-group-scope-type")
    assert has_element?(view, "#rule-group-entity-id")
    refute has_element?(view, "#rule-group-account-id")

    view
    |> form("#rule-group-form", rule_group: %{"scope_type" => "account"})
    |> render_change()

    assert has_element?(view, "#rule-group-account-id")
    refute has_element?(view, "#rule-group-entity-id")

    create_params = %{
      "scope_type" => "account",
      "account_id" => account.id,
      "name" => "Account Scoped Group",
      "priority" => "1",
      "description" => "Account specific scope",
      "target_fields" => ["tags"],
      "is_active" => "true"
    }

    view
    |> form("#rule-group-form", rule_group: create_params)
    |> render_submit()

    created_group =
      Classification.list_visible_rule_groups(entity.id, [account.id])
      |> Enum.find(&(&1.name == "Account Scoped Group"))

    assert created_group
    assert created_group.scope_type == :account
    assert created_group.account_id == account.id
    assert is_nil(created_group.entity_id)

    view
    |> element("#edit-rule-group-#{created_group.id}")
    |> render_click()

    edit_params = %{
      "scope_type" => "global",
      "name" => "Global Scope Group",
      "priority" => "2",
      "description" => "Promoted to global",
      "target_fields" => ["tags"],
      "is_active" => "true"
    }

    view
    |> form("#rule-group-form", rule_group: edit_params)
    |> render_submit()

    updated_group = Classification.get_rule_group!(created_group.id)
    assert updated_group.name == "Global Scope Group"
    assert updated_group.scope_type == :global
    assert is_nil(updated_group.entity_id)
    assert is_nil(updated_group.account_id)
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

  test "preview resolves category ids to names and groups duplicate field changes", %{conn: conn} do
    entity = insert_entity(name: "Preview Rules Entity")
    checking = insert_account(entity, %{name: "Checking"})

    transport =
      insert_account(entity, %{
        name: "Transport",
        account_type: :expense,
        management_group: :category,
        operational_subtype: nil,
        institution_name: nil,
        institution_account_ref: nil
      })

    travel =
      insert_account(entity, %{
        name: "Travel",
        account_type: :expense,
        management_group: :category,
        operational_subtype: nil,
        institution_name: nil,
        institution_account_ref: nil
      })

    primary_group = insert_global_rule_group(%{name: "Primary Category", priority: 1})
    secondary_group = insert_global_rule_group(%{name: "Secondary Category", priority: 2})

    insert_rule(primary_group, %{
      name: "Primary Uber",
      expression: ~s|description contains "uber"|,
      actions: [%{field: :category, operation: :set, value: transport.id}]
    })

    insert_rule(secondary_group, %{
      name: "Backup Uber",
      expression: ~s|description contains "uber"|,
      actions: [%{field: :category, operation: :set, value: travel.id}]
    })

    create_preview_transaction(entity, checking, description: "Uber trip")

    {:ok, view, _html} = conn |> log_in_root() |> live(~p"/rules?#{%{"entity_id" => entity.id}}")

    view
    |> form("#preview-form",
      preview: %{"date_from" => "2026-03-01", "date_to" => "2026-03-31"}
    )
    |> render_submit()

    assert has_element?(view, "#preview-results")
    assert has_element?(view, "#preview-change-0-category", "Transport")
    assert has_element?(view, "#preview-change-0-category", "Primary Category / Primary Uber")

    assert has_element?(
             view,
             "#preview-change-0-category",
             "Skipped: Secondary Category / Backup Uber"
           )

    refute has_element?(view, "#preview-change-0-category", transport.id)
    refute has_element?(view, "#preview-change-0-category", travel.id)
  end

  test "preview shows no-match transactions without proposed field cells", %{conn: conn} do
    entity = insert_entity(name: "Preview No Match Entity")
    checking = insert_account(entity, %{name: "Checking"})
    group = insert_global_rule_group(%{name: "Uber Only"})

    insert_rule(group, %{
      name: "Uber Rule",
      expression: ~s|description contains "uber"|,
      actions: [%{field: :tags, operation: :add, value: "ride"}]
    })

    create_preview_transaction(entity, checking, description: "Grocery store")

    {:ok, view, _html} = conn |> log_in_root() |> live(~p"/rules?#{%{"entity_id" => entity.id}}")

    view
    |> form("#preview-form",
      preview: %{"date_from" => "2026-03-01", "date_to" => "2026-03-31"}
    )
    |> render_submit()

    assert has_element?(view, "#preview-row-0", "No match")
    refute has_element?(view, "#preview-change-0-tags")
  end

  test "preview marks protected fields when manual overrides already exist", %{conn: conn} do
    entity = insert_entity(name: "Preview Protected Entity")
    checking = insert_account(entity, %{name: "Preview Checking"})
    group = insert_rule_group(entity, %{name: "Protected Tags Group", priority: 1})

    insert_rule(group, %{
      name: "Set Ride Tag",
      expression: ~s|description contains "uber"|,
      actions: [%{field: :tags, operation: :add, value: "ride"}]
    })

    transaction = create_preview_transaction(entity, checking, description: "Uber station")

    insert_classification_record(transaction, %{
      tags: ["manual-tag"],
      tags_manually_overridden: true,
      tags_classified_by: %{
        "source" => "user",
        "classified_at" => "2026-03-15T12:00:00Z"
      }
    })

    {:ok, view, _html} = conn |> log_in_root() |> live(~p"/rules?#{%{"entity_id" => entity.id}}")

    assert has_element?(view, "#run-preview-button[phx-disable-with]")

    view
    |> form("#preview-form",
      preview: %{"date_from" => "2026-03-01", "date_to" => "2026-03-31"}
    )
    |> render_submit()

    assert has_element?(view, "#preview-results")
    assert has_element?(view, "#preview-change-0-tags .au-badge-warn")
    assert has_element?(view, "#preview-change-0-tags", "Protected")
  end
end
