defmodule AurumFinanceWeb.TransactionsLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.TransactionsComponents

  alias Ecto.Changeset
  alias AurumFinance.Classification
  alias AurumFinance.Entities
  alias AurumFinance.Helpers
  alias AurumFinance.Ledger
  alias AurumFinanceWeb.FilterQuery

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
       category_accounts: [],
       classification_records: %{},
       classification_forms: %{},
       provenance_lookup: %{rule_groups: %{}, rules: %{}},
       bulk_apply_running?: false,
       bulk_apply_summary: nil,
       applying_transaction_ids: MapSet.new(),
       editing_classification_transaction_id: nil,
       transaction_apply_feedback: %{},
       expanded_transaction_id: nil,
       transactions: []
     )
     |> assign_filters(default_filters())}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {entity_id, expanded_transaction_id, filters} = parse_state_from_uri(uri)
    current_entity = resolve_current_entity(socket.assigns.entities, entity_id)

    {:noreply,
     socket
     |> assign(
       current_entity: current_entity,
       filters_expanded: filters_expanded?(filters),
       expanded_transaction_id: expanded_transaction_id,
       editing_classification_transaction_id: nil,
       bulk_apply_summary: nil,
       transaction_apply_feedback: %{}
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

    editing_transaction_id =
      if expanded == socket.assigns.editing_classification_transaction_id do
        socket.assigns.editing_classification_transaction_id
      else
        nil
      end

    {:noreply,
     socket
     |> assign(:expanded_transaction_id, expanded)
     |> assign(:editing_classification_transaction_id, editing_transaction_id)}
  end

  def handle_event("toggle_classification_editor", %{"id" => transaction_id}, socket) do
    editing_transaction_id =
      if socket.assigns.editing_classification_transaction_id == transaction_id do
        nil
      else
        transaction_id
      end

    {:noreply, assign(socket, :editing_classification_transaction_id, editing_transaction_id)}
  end

  def handle_event("bulk_apply", _params, socket) do
    case bulk_apply_attrs(socket.assigns.current_entity, socket.assigns.filters) do
      {:ok, attrs} ->
        send(self(), {:bulk_apply_rules, attrs})

        {:noreply,
         socket
         |> assign(:bulk_apply_running?, true)
         |> assign(:bulk_apply_summary, nil)}

      {:error, :missing_date_range} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           dgettext("transactions", "classification_bulk_apply_requires_range")
         )}
    end
  end

  def handle_event("apply_transaction_rules", %{"id" => transaction_id}, socket) do
    send(self(), {:apply_transaction_rules, transaction_id})

    {:noreply, update(socket, :applying_transaction_ids, &MapSet.put(&1, transaction_id))}
  end

  def handle_event(
        "set_manual_field",
        %{
          "transaction_id" => transaction_id,
          "field" => field,
          "manual_override" => %{"value" => value}
        },
        socket
      ) do
    case Classification.set_manual_field(
           transaction_id,
           field,
           value,
           entity_id: socket.assigns.current_entity.id,
           actor: "web",
           channel: :web
         ) do
      {:ok, _record} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("transactions", "classification_manual_saved"))
         |> clear_transaction_feedback(transaction_id)
         |> load_transactions()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, manual_error_message(reason))}
    end
  end

  def handle_event(
        "clear_manual_override",
        %{"transaction_id" => transaction_id, "field" => field},
        socket
      ) do
    case Classification.clear_manual_override(
           transaction_id,
           field,
           entity_id: socket.assigns.current_entity.id,
           actor: "web",
           channel: :web
         ) do
      {:ok, _record} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("transactions", "classification_override_cleared"))
         |> clear_transaction_feedback(transaction_id)
         |> load_transactions()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, manual_error_message(reason))}
    end
  end

  @impl true
  def handle_info({:bulk_apply_rules, attrs}, socket) do
    {:ok, summary} = Classification.classify_transactions(attrs)

    socket =
      socket
      |> assign(:bulk_apply_running?, false)
      |> assign(:bulk_apply_summary, summary)
      |> load_transactions()

    {:noreply, socket}
  end

  def handle_info({:apply_transaction_rules, transaction_id}, socket) do
    socket =
      case Classification.classify_transaction(
             transaction_id,
             entity_id: socket.assigns.current_entity.id,
             actor: "web",
             channel: :web
           ) do
        {:ok, result} ->
          socket
          |> update(:applying_transaction_ids, &MapSet.delete(&1, transaction_id))
          |> put_transaction_feedback(transaction_id, result)
          |> load_transactions()

        {:error, reason} ->
          socket
          |> update(:applying_transaction_ids, &MapSet.delete(&1, transaction_id))
          |> put_flash(:error, apply_error_message(reason))
      end

    {:noreply, socket}
  end

  defp load_transactions(%{assigns: %{current_entity: nil}} = socket) do
    assign(socket,
      transactions: [],
      accounts: [],
      category_accounts: [],
      classification_records: %{},
      classification_forms: %{},
      provenance_lookup: %{rule_groups: %{}, rules: %{}}
    )
  end

  defp load_transactions(socket) do
    entity = socket.assigns.current_entity
    accounts = Ledger.list_accounts(entity_id: entity.id)
    transactions = Ledger.list_transactions(filter_opts(entity.id, socket.assigns.filters))
    category_accounts = Enum.filter(accounts, &(&1.management_group == :category))
    classification_records = load_classification_records(transactions)
    provenance_lookup = load_provenance_lookup(entity.id, accounts)
    classification_forms = build_classification_forms(transactions, classification_records)

    assign(socket,
      transactions: transactions,
      accounts: accounts,
      category_accounts: category_accounts,
      classification_records: classification_records,
      classification_forms: classification_forms,
      provenance_lookup: provenance_lookup
    )
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

    expanded_transaction_id =
      clauses
      |> Map.get("tx")
      |> Helpers.blank_to_nil()

    filters =
      %{
        account_id: clauses["account"] |> Helpers.blank_to_nil(),
        date_preset: clauses["date"] || "all",
        source_type: clauses["source"] || "",
        include_voided: truthy_param?(clauses["voided"])
      }
      |> normalize_date_filters()

    {entity_id, expanded_transaction_id, filters}
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

  defp bulk_apply_attrs(nil, _filters), do: {:error, :missing_date_range}

  defp bulk_apply_attrs(current_entity, filters) do
    with {:ok, date_from} <- require_date(filters.date_from),
         {:ok, date_to} <- require_date(filters.date_to) do
      {:ok,
       %{
         entity_id: current_entity.id,
         date_from: date_from,
         date_to: date_to,
         actor: "web",
         channel: :web
       }}
    end
  end

  defp require_date(value) do
    case parse_date(value) do
      %Date{} = date -> {:ok, date}
      _date -> {:error, :missing_date_range}
    end
  end

  defp load_classification_records(transactions) do
    transactions
    |> Enum.map(& &1.id)
    |> Classification.list_classification_records()
    |> Map.new(&{&1.transaction_id, &1})
  end

  defp load_provenance_lookup(entity_id, accounts) do
    rule_groups =
      Classification.list_visible_rule_groups(entity_id, Enum.map(accounts, & &1.id))

    %{
      rule_groups: Map.new(rule_groups, &{&1.id, &1}),
      rules:
        rule_groups
        |> Enum.flat_map(& &1.rules)
        |> Map.new(&{&1.id, &1})
    }
  end

  defp build_classification_forms(transactions, classification_records) do
    Map.new(transactions, fn transaction ->
      record = Map.get(classification_records, transaction.id)

      {transaction.id,
       %{
         category:
           to_form(%{"value" => manual_field_value(record, :category)}, as: :manual_override),
         tags: to_form(%{"value" => manual_field_value(record, :tags)}, as: :manual_override),
         investment_type:
           to_form(%{"value" => manual_field_value(record, :investment_type)},
             as: :manual_override
           ),
         notes: to_form(%{"value" => manual_field_value(record, :notes)}, as: :manual_override)
       }}
    end)
  end

  defp manual_field_value(nil, _field), do: ""
  defp manual_field_value(record, :category), do: record.category_account_id || ""
  defp manual_field_value(record, :tags), do: Enum.join(record.tags || [], ", ")
  defp manual_field_value(record, :investment_type), do: record.investment_type || ""
  defp manual_field_value(record, :notes), do: record.notes || ""

  defp put_transaction_feedback(socket, transaction_id, result) do
    feedback =
      cond do
        result.no_match? ->
          %{tone: :warn, kind: :no_match, fields_applied: 0, fields_skipped_manual: 0}

        result.fields_applied > 0 ->
          %{
            tone: :good,
            kind: :applied,
            fields_applied: result.fields_applied,
            fields_skipped_manual: result.fields_skipped_manual
          }

        result.fields_skipped_manual > 0 ->
          %{
            tone: :warn,
            kind: :protected,
            fields_applied: 0,
            fields_skipped_manual: result.fields_skipped_manual
          }

        true ->
          %{tone: :warn, kind: :no_change, fields_applied: 0, fields_skipped_manual: 0}
      end

    update(socket, :transaction_apply_feedback, &Map.put(&1, transaction_id, feedback))
  end

  defp clear_transaction_feedback(socket, transaction_id) do
    update(socket, :transaction_apply_feedback, &Map.delete(&1, transaction_id))
  end

  defp manual_error_message(:invalid_category_account) do
    dgettext("transactions", "classification_error_invalid_category")
  end

  defp manual_error_message(:not_found),
    do: dgettext("transactions", "classification_error_not_found")

  defp manual_error_message(%Changeset{} = changeset) do
    changeset
    |> first_changeset_error()
    |> case do
      nil -> dgettext("transactions", "classification_error_generic")
      message -> message
    end
  end

  defp manual_error_message(_reason), do: dgettext("transactions", "classification_error_generic")

  defp apply_error_message(:not_found),
    do: dgettext("transactions", "classification_error_not_found")

  defp apply_error_message(_reason), do: dgettext("transactions", "classification_error_generic")

  defp first_changeset_error(%Changeset{errors: []}), do: nil

  defp first_changeset_error(%Changeset{errors: [{_field, {message, _opts}} | _rest]}) do
    message
  end
end
