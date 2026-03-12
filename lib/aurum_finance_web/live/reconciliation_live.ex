defmodule AurumFinanceWeb.ReconciliationLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.ReconciliationComponents

  alias AurumFinance.Entities
  alias AurumFinance.Helpers
  alias AurumFinance.Ledger
  alias AurumFinance.Reconciliation
  alias AurumFinance.Reconciliation.ReconciliationSession

  @zero Decimal.new("0")

  @impl true
  def mount(_params, _session, socket) do
    entities = Entities.list_entities()
    current_entity = List.first(entities)

    {:ok,
     socket
     |> assign(
       active_nav: :reconciliation,
       page_title: dgettext("reconciliation", "page_title"),
       entities: entities,
       current_entity: current_entity,
       institution_accounts: [],
       selected_account_id: nil,
       selected_session: nil,
       selected_posting_ids: MapSet.new(),
       sessions: [],
       postings: [],
       cleared_balance: @zero,
       difference: @zero,
       balanced?: true,
       form_open?: false,
       session_form_params: %{},
       session_count: 0,
       active_session_count: 0
     )
     |> assign_session_form(%{})}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> align_current_entity_for_session(params)
      |> load_entity_scope()
      |> load_selected_session(params)
      |> load_sessions()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_entity", %{"entity_id" => entity_id}, socket) do
    current_entity = find_entity(socket.assigns.entities, entity_id)

    socket =
      socket
      |> assign(:current_entity, current_entity)
      |> assign(:selected_account_id, nil)
      |> assign(:form_open?, false)
      |> assign(:selected_posting_ids, MapSet.new())
      |> assign_session_form(%{})

    {:noreply, maybe_reset_detail_route(socket)}
  end

  def handle_event("filter_sessions", %{"account_id" => account_id}, socket) do
    selected_account_id = Helpers.blank_to_nil(account_id)

    socket =
      socket
      |> assign(:selected_account_id, selected_account_id)
      |> assign(:selected_posting_ids, MapSet.new())
      |> assign_session_form(%{"account_id" => selected_account_id})

    {:noreply, maybe_reset_detail_route(socket)}
  end

  def handle_event("new_session", _params, socket) do
    {:noreply,
     socket
     |> assign(:form_open?, true)
     |> assign_session_form(%{})}
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, :form_open?, false)}
  end

  def handle_event("validate_session", %{"reconciliation_session" => params}, socket) do
    {:noreply, assign_session_form(socket, params, action: :validate)}
  end

  def handle_event("set_statement_date_preset", %{"preset" => preset}, socket) do
    params =
      socket
      |> current_session_form_params()
      |> Map.put("statement_date", preset_statement_date(preset))

    {:noreply, assign_session_form(socket, params, action: :validate)}
  end

  def handle_event("create_session", %{"reconciliation_session" => params}, socket) do
    case create_session(socket, params) do
      {:ok, session} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("reconciliation", "flash_session_created"))
         |> assign(:form_open?, false)
         |> assign(:selected_account_id, session.account_id)
         |> assign(:selected_posting_ids, MapSet.new())
         |> push_navigate(to: ~p"/reconciliation/#{session.id}")}

      {:error, {:audit_failed, _reason}} ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("reconciliation", "flash_audit_logging_failed"))
         |> assign(:form_open?, false)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form_open?, true)
         |> assign(:form, to_form(changeset, as: :reconciliation_session))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("reconciliation", "flash_session_create_failed"))
         |> assign(:form_open?, true)}
    end
  end

  def handle_event("toggle_select_all", _params, %{assigns: %{selected_session: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_select_all", _params, socket) do
    clearable_ids =
      socket.assigns
      |> clearable_postings()
      |> Enum.map(& &1.id)
      |> MapSet.new()

    selected_posting_ids =
      if MapSet.equal?(socket.assigns.selected_posting_ids, clearable_ids) do
        MapSet.new()
      else
        clearable_ids
      end

    {:noreply, assign(socket, :selected_posting_ids, selected_posting_ids)}
  end

  def handle_event("toggle_posting_selection", %{"id" => posting_id}, socket) do
    {:noreply, update(socket, :selected_posting_ids, &toggle_posting_id(&1, posting_id))}
  end

  def handle_event("mark_cleared", _params, %{assigns: %{selected_session: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("mark_cleared", _params, socket) do
    posting_ids = MapSet.to_list(socket.assigns.selected_posting_ids)

    case Reconciliation.mark_postings_cleared(posting_ids, socket.assigns.selected_session.id,
           entity_id: socket.assigns.current_entity.id,
           actor: "root",
           channel: :web
         ) do
      {:ok, _states} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("reconciliation", "flash_postings_cleared"))
         |> reload_selected_session()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, clear_error_message(reason))}
    end
  end

  def handle_event(
        "unclear_posting",
        %{"id" => _posting_id},
        %{assigns: %{selected_session: nil}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("unclear_posting", %{"id" => posting_id}, socket) do
    case Reconciliation.mark_postings_uncleared([posting_id], socket.assigns.selected_session.id,
           entity_id: socket.assigns.current_entity.id,
           actor: "root",
           channel: :web
         ) do
      {:ok, _posting_ids} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("reconciliation", "flash_posting_uncleared"))
         |> reload_selected_session()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, unclear_error_message(reason))}
    end
  end

  def handle_event("complete_session", _params, %{assigns: %{selected_session: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("complete_session", _params, socket) do
    case Reconciliation.complete_reconciliation_session(socket.assigns.selected_session,
           actor: "root",
           channel: :web
         ) do
      {:ok, session} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("reconciliation", "flash_session_completed"))
         |> assign(:selected_account_id, session.account_id)
         |> assign(:selected_posting_ids, MapSet.new())
         |> push_patch(to: ~p"/reconciliation/#{session.id}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, complete_error_message(reason))}
    end
  end

  defp load_entity_scope(%{assigns: %{current_entity: nil}} = socket) do
    socket
    |> assign(:institution_accounts, [])
    |> assign(:selected_account_id, nil)
    |> assign(:selected_session, nil)
    |> assign(:selected_posting_ids, MapSet.new())
    |> assign(:cleared_balance, @zero)
    |> assign(:difference, @zero)
    |> assign(:balanced?, true)
    |> assign(:session_count, 0)
    |> assign(:active_session_count, 0)
    |> assign(:sessions, [])
    |> assign(:postings, [])
    |> assign_session_form(%{})
  end

  defp load_entity_scope(socket) do
    institution_accounts =
      Ledger.list_institution_accounts(entity_id: socket.assigns.current_entity.id)

    selected_account_id =
      normalize_selected_account_id(institution_accounts, socket.assigns.selected_account_id)

    socket
    |> assign(:institution_accounts, institution_accounts)
    |> assign(:selected_account_id, selected_account_id)
    |> assign_session_form(%{"account_id" => selected_account_id})
  end

  defp align_current_entity_for_session(socket, %{"session_id" => session_id}) do
    case find_session_entity(socket.assigns.entities, session_id) do
      nil -> socket
      entity -> assign(socket, :current_entity, entity)
    end
  end

  defp align_current_entity_for_session(socket, _params), do: socket

  defp load_selected_session(%{assigns: %{current_entity: nil}} = socket, _params), do: socket

  defp load_selected_session(socket, %{"session_id" => session_id}) do
    entity_id = socket.assigns.current_entity.id

    session =
      try do
        Reconciliation.get_reconciliation_session!(entity_id, session_id)
      rescue
        Ecto.NoResultsError -> nil
      end

    case session do
      nil ->
        socket
        |> put_flash(:error, dgettext("reconciliation", "flash_session_not_found"))
        |> assign(:selected_session, nil)
        |> assign(:selected_posting_ids, MapSet.new())
        |> assign(:cleared_balance, @zero)
        |> assign(:difference, @zero)
        |> assign(:balanced?, true)
        |> assign(:postings, [])
        |> push_patch(to: ~p"/reconciliation")

      session ->
        socket
        |> assign(:selected_account_id, session.account_id)
        |> assign(:selected_session, session)
        |> assign(:selected_posting_ids, MapSet.new())
        |> assign_postings_and_summary(session)
        |> assign_session_form(%{"account_id" => session.account_id})
    end
  end

  defp load_selected_session(socket, _params) do
    socket
    |> assign(:selected_session, nil)
    |> assign(:selected_posting_ids, MapSet.new())
    |> assign(:cleared_balance, @zero)
    |> assign(:difference, @zero)
    |> assign(:balanced?, true)
    |> assign(:postings, [])
  end

  defp load_sessions(%{assigns: %{current_entity: nil}} = socket), do: socket

  defp load_sessions(socket) do
    sessions =
      Reconciliation.list_reconciliation_sessions(
        session_filters(socket.assigns.current_entity.id, socket.assigns.selected_account_id)
      )

    socket
    |> assign(:session_count, length(sessions))
    |> assign(:active_session_count, Enum.count(sessions, &active_session?/1))
    |> assign(:sessions, sessions)
  end

  defp assign_postings_and_summary(socket, session) do
    postings =
      Reconciliation.list_postings_for_reconciliation(session.account_id,
        entity_id: socket.assigns.current_entity.id
      )

    cleared_balance =
      Reconciliation.get_cleared_balance(session.account_id,
        entity_id: socket.assigns.current_entity.id
      )

    difference = Decimal.sub(session.statement_balance, cleared_balance)

    socket
    |> assign(:postings, postings)
    |> assign(:cleared_balance, cleared_balance)
    |> assign(:difference, difference)
    |> assign(:balanced?, Decimal.compare(difference, @zero) == :eq)
  end

  defp reload_selected_session(%{assigns: %{selected_session: nil}} = socket), do: socket

  defp reload_selected_session(socket) do
    session =
      Reconciliation.get_reconciliation_session!(
        socket.assigns.current_entity.id,
        socket.assigns.selected_session.id
      )

    socket
    |> assign(:selected_session, session)
    |> assign(:selected_posting_ids, MapSet.new())
    |> assign_postings_and_summary(session)
    |> load_sessions()
  end

  defp assign_session_form(socket, params, opts \\ []) do
    attrs = session_form_attrs(socket, params)

    changeset =
      %ReconciliationSession{}
      |> Reconciliation.change_reconciliation_session(attrs)
      |> maybe_put_action(opts[:action])

    socket
    |> assign(:session_form_params, stringify_session_form_attrs(attrs))
    |> assign(:form, to_form(changeset, as: :reconciliation_session))
  end

  defp create_session(%{assigns: %{current_entity: nil}}, _params), do: {:error, :missing_entity}

  defp create_session(socket, params) do
    attrs = session_form_attrs(socket, params)

    Reconciliation.create_reconciliation_session(attrs,
      entity_id: socket.assigns.current_entity.id,
      actor: "root",
      channel: :web
    )
  end

  defp session_form_attrs(socket, params) do
    entity_id = socket.assigns.current_entity && socket.assigns.current_entity.id

    %{
      "entity_id" => entity_id,
      "account_id" => default_account_id(socket, params),
      "statement_date" => Map.get(params, "statement_date", default_statement_date()),
      "statement_balance" => Map.get(params, "statement_balance", "")
    }
  end

  defp default_account_id(socket, params) do
    params["account_id"] ||
      socket.assigns.selected_account_id ||
      first_account_id(socket.assigns.institution_accounts)
  end

  defp first_account_id([account | _]), do: account.id
  defp first_account_id([]), do: nil

  defp current_session_form_params(%{assigns: %{session_form_params: params}}), do: params

  defp stringify_session_form_attrs(attrs) do
    Map.new(attrs, fn
      {key, %Date{} = value} -> {key, Date.to_iso8601(value)}
      {key, value} -> {key, value}
    end)
  end

  defp default_statement_date do
    Date.utc_today()
    |> Date.beginning_of_month()
    |> Date.add(-1)
    |> Date.to_iso8601()
  end

  defp preset_statement_date("last_month"), do: default_statement_date()

  defp preset_statement_date("last_year") do
    today = Date.utc_today()
    Date.new!(today.year - 1, 12, 31) |> Date.to_iso8601()
  end

  defp preset_statement_date(_preset), do: default_statement_date()

  defp maybe_put_action(changeset, nil), do: changeset
  defp maybe_put_action(changeset, action), do: Map.put(changeset, :action, action)

  defp find_entity(entities, entity_id), do: Enum.find(entities, &(&1.id == entity_id))

  defp find_session_entity(entities, session_id) do
    Enum.find(entities, fn entity ->
      session_belongs_to_entity?(entity.id, session_id)
    end)
  end

  defp session_belongs_to_entity?(entity_id, session_id) do
    try do
      _session = Reconciliation.get_reconciliation_session!(entity_id, session_id)
      true
    rescue
      Ecto.NoResultsError -> false
    end
  end

  defp normalize_selected_account_id(accounts, selected_account_id) do
    normalized_id = Helpers.blank_to_nil(selected_account_id)

    case Enum.any?(accounts, &(&1.id == normalized_id)) do
      true -> normalized_id
      false -> nil
    end
  end

  defp session_filters(entity_id, nil), do: [entity_id: entity_id]
  defp session_filters(entity_id, account_id), do: [entity_id: entity_id, account_id: account_id]

  defp maybe_reset_detail_route(%{assigns: %{live_action: :show}} = socket) do
    push_patch(socket, to: ~p"/reconciliation")
  end

  defp maybe_reset_detail_route(socket) do
    socket
    |> load_entity_scope()
    |> load_selected_session(%{})
    |> load_sessions()
  end

  defp toggle_posting_id(selected_posting_ids, posting_id) do
    if MapSet.member?(selected_posting_ids, posting_id) do
      MapSet.delete(selected_posting_ids, posting_id)
    else
      MapSet.put(selected_posting_ids, posting_id)
    end
  end

  defp clearable_postings(%{postings: postings}),
    do: Enum.filter(postings, &(&1.reconciliation_status == :unreconciled))

  defp active_session?(%ReconciliationSession{completed_at: nil}), do: true
  defp active_session?(%ReconciliationSession{}), do: false

  defp clear_error_message(:postings_not_clearable),
    do: dgettext("reconciliation", "flash_postings_not_clearable")

  defp clear_error_message(:session_already_completed),
    do: dgettext("reconciliation", "flash_session_already_completed")

  defp clear_error_message(_reason),
    do: dgettext("reconciliation", "flash_postings_clear_failed")

  defp unclear_error_message(:postings_not_unclearable),
    do: dgettext("reconciliation", "flash_postings_not_unclearable")

  defp unclear_error_message(:session_already_completed),
    do: dgettext("reconciliation", "flash_session_already_completed")

  defp unclear_error_message(_reason),
    do: dgettext("reconciliation", "flash_posting_unclear_failed")

  defp complete_error_message(:session_already_completed),
    do: dgettext("reconciliation", "flash_session_already_completed")

  defp complete_error_message(_reason),
    do: dgettext("reconciliation", "flash_session_complete_failed")
end
