defmodule AurumFinanceWeb.AccountsLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Entities
  alias AurumFinance.Ledger

  test "renders management tabs and entity-scoped accounts", %{conn: conn} do
    visible_entity = entity_fixture(name: "Accounts Alpha")
    hidden_entity = entity_fixture(name: "Accounts Zeta")

    visible_account =
      account_fixture(visible_entity, %{
        name: "Visible checking",
        account_type: :asset,
        operational_subtype: :bank_checking,
        management_group: :institution,
        currency_code: "USD"
      })

    _hidden_account =
      account_fixture(hidden_entity, %{
        name: "Hidden salary",
        account_type: :income,
        operational_subtype: nil,
        management_group: :category,
        currency_code: "USD"
      })

    {:ok, view, _html} = conn |> log_in_root() |> live("/accounts")

    assert has_element?(view, "#accounts-page")
    assert has_element?(view, "#accounts-tab-institution")
    assert has_element?(view, "#accounts-tab-category")
    assert has_element?(view, "#accounts-tab-system_managed")
    assert has_element?(view, "#account-#{visible_account.id}")
    refute render(view) =~ "Hidden salary"
  end

  test "creates an institution account in the selected entity", %{conn: conn} do
    entity = entity_fixture(name: "Create institution entity")

    {:ok, view, _html} = conn |> log_in_root() |> live("/accounts")

    view
    |> form("#accounts-entity-selector", entity_id: entity.id)
    |> render_change()

    params = %{
      "name" => "Primary checking",
      "management_group" => "institution",
      "operational_subtype" => "bank_checking",
      "currency_code" => "USD",
      "institution_name" => "Mercury",
      "institution_account_ref" => "1234",
      "notes" => "daily use"
    }

    view
    |> form("#account-form", account: params)
    |> render_submit()

    account =
      Ledger.list_institution_accounts(entity_id: entity.id)
      |> Enum.find(&(&1.name == "Primary checking"))

    assert account
    assert account.account_type == :asset
    assert account.management_group == :institution
    assert has_element?(view, "#account-#{account.id}")
  end

  test "defaults currency select from selected entity country", %{conn: conn} do
    entity = entity_fixture(name: "Chile entity", country_code: "CL")

    {:ok, view, _html} = conn |> log_in_root() |> live("/accounts")

    view
    |> form("#accounts-entity-selector", entity_id: entity.id)
    |> render_change()

    assert has_element?(view, "#account_currency_code option[selected][value='CLP']")
  end

  test "creates a category account from the category tab", %{conn: conn} do
    entity = entity_fixture(name: "Create category entity")

    {:ok, view, _html} = conn |> log_in_root() |> live("/accounts")

    view
    |> form("#accounts-entity-selector", entity_id: entity.id)
    |> render_change()

    view
    |> element("#accounts-tab-category")
    |> render_click()

    params = %{
      "name" => "Salary",
      "management_group" => "category",
      "account_type" => "income",
      "currency_code" => "USD",
      "institution_name" => "",
      "institution_account_ref" => "",
      "notes" => "auto imported later"
    }

    view
    |> form("#account-form", account: params)
    |> render_submit()

    account =
      Ledger.list_category_accounts(entity_id: entity.id)
      |> Enum.find(&(&1.name == "Salary"))

    assert account
    assert account.account_type == :income
    assert account.management_group == :category
    assert has_element?(view, "#account-#{account.id}")
  end

  test "edits, archives, and unarchives accounts from the list", %{conn: conn} do
    entity = entity_fixture(name: "Lifecycle entity")

    account =
      account_fixture(entity, %{
        name: "Lifecycle checking",
        account_type: :asset,
        operational_subtype: :bank_checking,
        management_group: :institution,
        currency_code: "USD"
      })

    {:ok, view, _html} = conn |> log_in_root() |> live("/accounts")

    view
    |> form("#accounts-entity-selector", entity_id: entity.id)
    |> render_change()

    view
    |> element("#edit-account-#{account.id}")
    |> render_click()

    view
    |> form("#account-form",
      account: %{
        "name" => "Lifecycle checking updated",
        "institution_name" => "Bank",
        "institution_account_ref" => "9999",
        "notes" => "edited"
      }
    )
    |> render_submit()

    updated = Ledger.get_account!(account.id)
    assert updated.name == "Lifecycle checking updated"
    assert updated.notes == "edited"

    view
    |> element("#archive-account-#{account.id}")
    |> render_click()

    archived = Ledger.get_account!(account.id)
    assert %DateTime{} = archived.archived_at
    refute has_element?(view, "#account-#{account.id}")

    view
    |> element("#toggle-archived-btn")
    |> render_click()

    assert has_element?(view, "#unarchive-account-#{account.id}")

    view
    |> element("#unarchive-account-#{account.id}")
    |> render_click()

    unarchived = Ledger.get_account!(account.id)
    assert is_nil(unarchived.archived_at)
    assert has_element?(view, "#account-#{account.id}")
  end

  defp entity_fixture(attrs) do
    attrs = if Keyword.keyword?(attrs), do: Map.new(attrs), else: attrs

    base = %{
      name: "Entity #{System.unique_integer([:positive])}",
      type: :individual,
      country_code: "US"
    }

    {:ok, entity} = base |> Map.merge(attrs) |> Entities.create_entity()
    entity
  end

  defp account_fixture(entity, attrs) do
    attrs = if Keyword.keyword?(attrs), do: Map.new(attrs), else: attrs

    base = %{
      entity_id: entity.id,
      name: "Account #{System.unique_integer([:positive])}",
      account_type: :asset,
      operational_subtype: :bank_checking,
      management_group: :institution,
      currency_code: "USD"
    }

    {:ok, account} = base |> Map.merge(attrs) |> Ledger.create_account()
    account
  end
end
