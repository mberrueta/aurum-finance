defmodule AurumFinanceWeb.TransactionsLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.TransactionsComponents

  alias AurumFinance.Entities
  alias AurumFinanceWeb.FilterQuery
  alias AurumFinance.Ledger
  alias AurumFinance.Helpers

  @impl true
  def mount(_params, _session, socket) do
    entities = Entities.list_entities()

    {:ok,
     socket
     |> assign(
       active_nav: :transactions,
       page_title: dgettext("transactions", "page_title"),
       entities: entities,
       current_entity: nil,
       filters_expanded: false,
       accounts: [],
       expanded_transaction_id: nil,
       transactions: []
     )
     |> assign_filters(default_filters())}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {entity_id, filters} = parse_state_from_uri(uri)
    current_entity = resolve_current_entity(socket.assigns.entities, entity_id)

    {:noreply,
     socket
     |> assign(
       current_entity: current_entity,
       filters_expanded: filters_expanded?(filters),
       expanded_transaction_id: nil
     )
     |> assign_filters(filters)
     |> load_transactions()}
  end

  @impl true
  def handle_event("select_entity", %{"entity_id" => entity_id}, socket) do
    current_entity = find_entity(socket.assigns.entities, entity_id)

    {:noreply, push_patch(socket, to: transactions_path(current_entity, default_filters()))}
  end

  def handle_event("filter", %{"filters" => params}, socket) do
    {:noreply,
     push_patch(socket,
       to: transactions_path(socket.assigns.current_entity, parse_filters(params))
     )}
  end

  def handle_event("toggle_filters", _params, socket) do
    {:noreply, update(socket, :filters_expanded, &(!&1))}
  end

  def handle_event("set_date_preset", %{"preset" => preset}, socket) do
    filters =
      socket.assigns.filters
      |> Map.put(:date_preset, preset)
      |> normalize_date_filters()

    {:noreply, push_patch(socket, to: transactions_path(socket.assigns.current_entity, filters))}
  end

  def handle_event("toggle_transaction", %{"id" => id}, socket) do
    expanded =
      if socket.assigns.expanded_transaction_id == id do
        nil
      else
        id
      end

    {:noreply, assign(socket, :expanded_transaction_id, expanded)}
  end

  defp load_transactions(%{assigns: %{current_entity: nil}} = socket) do
    assign(socket, transactions: [], accounts: [])
  end

  defp load_transactions(socket) do
    entity = socket.assigns.current_entity
    accounts = Ledger.list_accounts(entity_id: entity.id)
    transactions = Ledger.list_transactions(filter_opts(entity.id, socket.assigns.filters))

    assign(socket, transactions: transactions, accounts: accounts)
  end

  defp default_filters do
    %{
      account_id: "",
      date_preset: "all",
      date_from: "",
      date_to: "",
      source_type: "",
      include_voided: false
    }
  end

  defp parse_filters(params) do
    %{
      account_id: Helpers.blank_to_nil(params["account_id"]),
      date_preset: params["date_preset"] || "all",
      source_type: params["source_type"] || "",
      include_voided: truthy_param?(params["include_voided"])
    }
    |> normalize_date_filters()
  end

  defp parse_state_from_uri(uri) do
    clauses =
      uri
      |> URI.parse()
      |> Map.get(:query)
      |> FilterQuery.decode()

    entity_id =
      clauses
      |> Map.get("entity")
      |> Helpers.blank_to_nil()

    filters =
      %{
        account_id: clauses["account"] |> Helpers.blank_to_nil(),
        date_preset: clauses["date"] || "all",
        source_type: clauses["source"] || "",
        include_voided: truthy_param?(clauses["voided"])
      }
      |> normalize_date_filters()

    {entity_id, filters}
  end

  defp filter_opts(entity_id, filters) do
    [entity_id: entity_id, include_voided: filters.include_voided]
    |> maybe_put_opt(:account_id, filters.account_id)
    |> maybe_put_opt(:source_type, parse_source_type(filters.source_type))
    |> maybe_put_opt(:date_from, parse_date(filters.date_from))
    |> maybe_put_opt(:date_to, parse_date(filters.date_to))
  end

  defp account_filter_options(accounts) do
    [{dgettext("transactions", "filter_account_all"), ""} | Enum.map(accounts, &{&1.name, &1.id})]
  end

  defp source_type_filter_options do
    [
      {dgettext("transactions", "filter_source_all"), ""},
      {dgettext("transactions", "badge_manual"), "manual"},
      {dgettext("transactions", "badge_import"), "import"},
      {dgettext("transactions", "badge_system"), "system"}
    ]
  end

  defp date_preset_options do
    [
      {dgettext("transactions", "filter_date_this_week"), "this_week"},
      {dgettext("transactions", "filter_date_this_month"), "this_month"},
      {dgettext("transactions", "filter_date_this_year"), "this_year"},
      {dgettext("transactions", "filter_date_all"), "all"}
    ]
  end

  defp maybe_put_opt(opts, _key, nil), do: opts
  defp maybe_put_opt(opts, _key, ""), do: opts
  defp maybe_put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_source_type(nil), do: nil
  defp parse_source_type(""), do: nil

  defp parse_source_type(value) do
    case value do
      "manual" -> :manual
      "import" -> :import
      "system" -> :system
      _ -> nil
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp truthy_param?(value) when value in ["true", true, "on", "1", 1], do: true
  defp truthy_param?(_value), do: false

  defp find_entity(entities, entity_id), do: Enum.find(entities, &(&1.id == entity_id))

  defp resolve_current_entity(entities, nil), do: List.first(entities)

  defp resolve_current_entity(entities, entity_id) do
    find_entity(entities, entity_id) || List.first(entities)
  end

  defp normalize_date_filters(filters) do
    {date_from, date_to} = preset_date_range(filters.date_preset)

    filters
    |> Map.put(:date_preset, normalize_date_preset(filters.date_preset))
    |> Map.put(:date_from, date_to_string(date_from))
    |> Map.put(:date_to, date_to_string(date_to))
  end

  defp normalize_date_preset(preset)
       when preset in ["this_week", "this_month", "this_year", "all"],
       do: preset

  defp normalize_date_preset(_preset), do: "all"

  defp preset_date_range(preset) do
    today = Date.utc_today()

    case normalize_date_preset(preset) do
      "this_week" ->
        beginning_of_week = Date.add(today, 1 - Date.day_of_week(today, :monday))
        {beginning_of_week, today}

      "this_month" ->
        {%Date{year: today.year, month: today.month, day: 1}, today}

      "this_year" ->
        {%Date{year: today.year, month: 1, day: 1}, today}

      "all" ->
        {nil, nil}
    end
  end

  defp date_to_string(nil), do: ""
  defp date_to_string(%Date{} = date), do: Date.to_iso8601(date)

  defp assign_filters(socket, filters) do
    assign(socket,
      filters: filters,
      filters_form: to_form(stringify_filter_keys(filters), as: :filters)
    )
  end

  defp stringify_filter_keys(filters) do
    Map.new(filters, fn {key, value} -> {Atom.to_string(key), value} end)
  end

  defp date_preset_button_class(true) do
    "rounded-xl border border-emerald-400/40 bg-emerald-400/15 px-3 py-2 text-sm font-medium text-emerald-100 transition"
  end

  defp date_preset_button_class(false) do
    "rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-sm font-medium text-white/72 transition hover:border-white/20 hover:bg-white/[0.06]"
  end

  defp filters_toggle_label(true), do: dgettext("transactions", "filters_hide")
  defp filters_toggle_label(false), do: dgettext("transactions", "filters_show")

  defp filters_expanded?(filters) do
    not is_nil(filters.account_id) or filters.source_type != "" or filters.include_voided
  end

  defp transactions_path(current_entity, filters) do
    FilterQuery.build_path("/transactions",
      entity: current_entity && current_entity.id,
      account: filters.account_id,
      date: FilterQuery.skip_default(filters.date_preset, "all"),
      source: FilterQuery.skip_default(filters.source_type, ""),
      voided: filters.include_voided && "true"
    )
  end
end
