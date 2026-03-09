defmodule AurumFinanceWeb.AccountsLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.AccountsComponents

  alias AurumFinance.Currency
  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Helpers
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account

  @tabs [:institution, :category, :system_managed]
  @archived_toggle_key %{
    institution: :institution,
    category: :category,
    system_managed: :system_managed
  }

  @impl true
  def mount(_params, _session, socket) do
    entities = Entities.list_entities()
    current_entity = List.first(entities)

    socket =
      socket
      |> stream_configure(:accounts, dom_id: &"account-#{&1.id}")
      |> assign(
        active_nav: :accounts,
        page_title: dgettext("accounts", "page_title"),
        entities: entities,
        current_entity: current_entity,
        active_tab: :institution,
        show_archived_by_tab: default_show_archived_by_tab(),
        editing_account: nil,
        form_open?: false,
        selected_management_group: :institution,
        account_count: 0,
        tab_counts: %{institution: 0, category: 0, system_managed: 0}
      )
      |> stream(:accounts, [], reset: true)
      |> assign_form(%Account{})
      |> load_accounts()

    {:ok, socket}
  end

  @impl true
  def handle_event("select_entity", %{"entity_id" => entity_id}, socket) do
    current_entity = find_entity(socket.assigns.entities, entity_id)

    {:noreply,
     socket
     |> assign(:current_entity, current_entity)
     |> reset_form_state()
     |> load_accounts()}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    active_tab = parse_tab(tab)

    {:noreply,
     socket
     |> assign(:active_tab, active_tab)
     |> reset_form_state()
     |> load_accounts()}
  end

  def handle_event("toggle_archived", _params, socket) do
    key = Map.fetch!(@archived_toggle_key, socket.assigns.active_tab)

    {:noreply,
     socket
     |> update(:show_archived_by_tab, &Map.update!(&1, key, fn visible -> not visible end))
     |> load_accounts()}
  end

  def handle_event("new_account", _params, socket) do
    {:noreply,
     socket
     |> reset_form_state()
     |> assign(:form_open?, true)}
  end

  def handle_event("edit_account", %{"id" => id}, socket) do
    case get_account_in_scope(socket, id) do
      nil ->
        {:noreply, socket}

      account ->
        {:noreply,
         socket
         |> assign(:editing_account, account)
         |> assign(:form_open?, true)
         |> assign(:selected_management_group, account.management_group)
         |> assign_form(account)}
    end
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, reset_form_state(socket)}
  end

  def handle_event("archive_account", %{"id" => id}, socket) do
    case get_account_in_scope(socket, id) do
      nil ->
        {:noreply, socket}

      account ->
        result = Ledger.archive_account(account, actor: "root", channel: :web)

        {:noreply,
         handle_persist_result(socket, result, dgettext("accounts", "flash_account_archived"))}
    end
  end

  def handle_event("unarchive_account", %{"id" => id}, socket) do
    case get_account_in_scope(socket, id) do
      nil ->
        {:noreply, socket}

      account ->
        result = Ledger.unarchive_account(account, actor: "root", channel: :web)

        {:noreply,
         handle_persist_result(socket, result, dgettext("accounts", "flash_account_unarchived"))}
    end
  end

  def handle_event("validate", %{"account" => params}, socket) do
    target_account = socket.assigns.editing_account || %Account{}
    attrs = normalize_account_params(socket, params)

    changeset =
      target_account
      |> Ledger.change_account(attrs)
      |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:selected_management_group, params_management_group(socket, params))
     |> assign(:form, to_form(changeset, as: :account))}
  end

  def handle_event("save", %{"account" => params}, socket) do
    attrs = normalize_account_params(socket, params)

    result =
      case socket.assigns.editing_account do
        nil ->
          Ledger.create_account(attrs, actor: "root", channel: :web)

        account ->
          Ledger.update_account(account, attrs, actor: "root", channel: :web)
      end

    message =
      if socket.assigns.editing_account,
        do: dgettext("accounts", "flash_account_updated"),
        else: dgettext("accounts", "flash_account_created")

    {:noreply, handle_persist_result(socket, result, message)}
  end

  defp handle_persist_result(socket, {:ok, _account}, success_message) do
    socket
    |> put_flash(:info, success_message)
    |> reset_form_state()
    |> load_accounts()
  end

  defp handle_persist_result(socket, {:error, {:audit_failed, _reason}}, _success_message) do
    socket
    |> put_flash(:error, dgettext("accounts", "flash_audit_logging_failed"))
    |> reset_form_state()
    |> load_accounts()
  end

  defp handle_persist_result(socket, {:error, %Ecto.Changeset{} = changeset}, _success_message) do
    socket
    |> assign(:form_open?, true)
    |> assign(:selected_management_group, changeset_selected_management_group(socket, changeset))
    |> assign(:form, to_form(changeset, as: :account))
  end

  defp load_accounts(%{assigns: %{current_entity: nil}} = socket) do
    socket
    |> assign(:account_count, 0)
    |> assign(:tab_counts, %{institution: 0, category: 0, system_managed: 0})
    |> stream(:accounts, [], reset: true)
  end

  defp load_accounts(socket) do
    tab_counts =
      load_tab_counts(socket.assigns.current_entity, socket.assigns.show_archived_by_tab)

    accounts =
      Ledger.list_accounts_by_management_group(socket.assigns.active_tab,
        entity_id: socket.assigns.current_entity.id,
        include_archived:
          archived_visible?(socket.assigns.active_tab, socket.assigns.show_archived_by_tab)
      )

    socket
    |> assign(:account_count, length(accounts))
    |> assign(:tab_counts, tab_counts)
    |> stream(:accounts, accounts, reset: true)
  end

  defp assign_form(socket, %Account{} = account) do
    attrs = default_form_attrs(socket, account)
    changeset = Ledger.change_account(account, attrs)

    socket
    |> assign(:selected_management_group, account.management_group || socket.assigns.active_tab)
    |> assign(:form, to_form(changeset, as: :account))
  end

  defp reset_form_state(socket) do
    socket
    |> assign(:editing_account, nil)
    |> assign(:form_open?, false)
    |> assign(:selected_management_group, socket.assigns.active_tab)
    |> assign_form(%Account{})
  end

  defp default_form_attrs(
         %{assigns: %{current_entity: current_entity, active_tab: active_tab}},
         %Account{id: nil}
       ) do
    management_group = active_tab
    account_type = default_account_type_for_management_group(management_group)

    %{
      entity_id: current_entity && current_entity.id,
      management_group: management_group,
      account_type: account_type,
      currency_code: default_currency_code(current_entity),
      operational_subtype: default_operational_subtype(management_group)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp default_form_attrs(_socket, %Account{} = account) do
    %{
      entity_id: account.entity_id,
      management_group: account.management_group,
      account_type: account.account_type,
      currency_code: account.currency_code,
      operational_subtype: account.operational_subtype,
      institution_name: account.institution_name,
      institution_account_ref: account.institution_account_ref,
      notes: account.notes,
      name: account.name
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp normalize_account_params(socket, params) do
    management_group = params_management_group(socket, params)
    current_entity = socket.assigns.current_entity

    params
    |> Map.put("entity_id", current_entity && current_entity.id)
    |> Map.put("management_group", management_group)
    |> put_account_type_for_management_group(management_group)
    |> normalize_blank_operational_subtype(management_group)
  end

  defp put_account_type_for_management_group(params, :institution) do
    subtype = Helpers.blank_to_nil(params["operational_subtype"])
    mapped_type = subtype && Account.account_type_for_operational_subtype(parse_subtype(subtype))

    case mapped_type do
      nil -> Map.put(params, "account_type", nil)
      type -> Map.put(params, "account_type", Atom.to_string(type))
    end
  end

  defp put_account_type_for_management_group(params, :category) do
    Map.put(params, "account_type", Helpers.blank_to_nil(params["account_type"]))
  end

  defp put_account_type_for_management_group(params, :system_managed) do
    Map.put(params, "account_type", "equity")
  end

  defp normalize_blank_operational_subtype(params, :institution), do: params

  defp normalize_blank_operational_subtype(params, _),
    do: Map.put(params, "operational_subtype", nil)

  defp params_management_group(socket, params) do
    case Helpers.blank_to_nil(params["management_group"]) do
      "institution" -> :institution
      "category" -> :category
      "system_managed" -> :system_managed
      _ -> socket.assigns.selected_management_group || socket.assigns.active_tab
    end
  end

  defp changeset_selected_management_group(socket, changeset) do
    case Ecto.Changeset.get_field(changeset, :management_group) do
      nil -> socket.assigns.selected_management_group
      value -> value
    end
  end

  defp default_show_archived_by_tab do
    %{institution: false, category: false, system_managed: false}
  end

  defp archived_visible?(tab, show_archived_by_tab), do: Map.get(show_archived_by_tab, tab, false)

  defp toggle_archived_label(tab, show_archived_by_tab) do
    if archived_visible?(tab, show_archived_by_tab) do
      dgettext("accounts", "btn_hide_archived")
    else
      dgettext("accounts", "btn_show_archived")
    end
  end

  defp load_tab_counts(nil, _show_archived_by_tab) do
    %{institution: 0, category: 0, system_managed: 0}
  end

  defp load_tab_counts(current_entity, show_archived_by_tab) do
    Enum.into(@tabs, %{}, fn tab ->
      accounts =
        Ledger.list_accounts_by_management_group(tab,
          entity_id: current_entity.id,
          include_archived: archived_visible?(tab, show_archived_by_tab)
        )

      {tab, length(accounts)}
    end)
  end

  defp form_panel_title(nil, management_group),
    do: dgettext("accounts", "panel_new_account", group: management_group_label(management_group))

  defp form_panel_title(_account, _management_group),
    do: dgettext("accounts", "panel_edit_account")

  defp empty_state_text(:institution, false),
    do: dgettext("accounts", "empty_institution_accounts")

  defp empty_state_text(:institution, true),
    do: dgettext("accounts", "empty_institution_accounts_archived")

  defp empty_state_text(:category, false), do: dgettext("accounts", "empty_category_accounts")

  defp empty_state_text(:category, true),
    do: dgettext("accounts", "empty_category_accounts_archived")

  defp empty_state_text(:system_managed, false),
    do: dgettext("accounts", "empty_system_managed_accounts")

  defp empty_state_text(:system_managed, true),
    do: dgettext("accounts", "empty_system_managed_accounts_archived")

  defp default_account_type_for_management_group(:institution), do: :asset
  defp default_account_type_for_management_group(:category), do: :expense
  defp default_account_type_for_management_group(:system_managed), do: :equity
  defp default_account_type_for_management_group(_), do: nil

  defp default_operational_subtype(:institution), do: :bank_checking
  defp default_operational_subtype(_), do: nil

  defp default_currency_code(nil), do: Currency.default_code_for_country(nil)

  defp default_currency_code(%Entity{country_code: country_code}),
    do: Currency.default_code_for_country(country_code)

  defp parse_tab("institution"), do: :institution
  defp parse_tab("category"), do: :category
  defp parse_tab("system_managed"), do: :system_managed
  defp parse_tab(_), do: :institution

  defp parse_subtype(nil), do: nil
  defp parse_subtype(value) when is_atom(value), do: value

  defp parse_subtype(value) when is_binary(value) do
    Enum.find(Account.institution_operational_subtypes(), fn subtype ->
      Atom.to_string(subtype) == value
    end)
  end

  defp get_account_in_scope(%{assigns: %{current_entity: %Entity{id: entity_id}}}, account_id) do
    Ledger.get_account(entity_id, account_id)
  end

  defp get_account_in_scope(%{assigns: %{current_entity: nil}}, _account_id), do: nil

  defp find_entity(entities, entity_id), do: Enum.find(entities, &(&1.id == entity_id))

  defp editing_account_id(nil), do: nil
  defp editing_account_id(%Account{id: id}), do: id
end
