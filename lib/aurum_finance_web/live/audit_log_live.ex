defmodule AurumFinanceWeb.AuditLogLive do
  @moduledoc """
  Read-only audit log viewer for operationally meaningful events.
  """

  use AurumFinanceWeb, :live_view

  alias AurumFinance.Audit
  alias AurumFinance.Entities
  alias AurumFinance.Helpers
  alias AurumFinanceWeb.FilterQuery

  @page_size 50
  @actions ["created", "updated", "archived", "unarchived", "voided"]
  @channels ["web", "system", "mcp", "ai_assistant"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       active_nav: :audit_log,
       page_title: dgettext("audit_log", "page_title"),
       entities: [],
       entity_type_options: [],
       expanded_event_id: nil,
       events: [],
       has_next_page: false,
       page: 1
     )
     |> assign_filters(default_filters())}
  end

  @impl true
  def handle_params(_params, uri, socket) do
    {filters, page} = parse_state_from_uri(uri)
    entities = Entities.list_entities()
    entity_type_options = Audit.distinct_entity_types()
    {events, has_next_page} = load_events(filters, page)

    {:noreply,
     socket
     |> assign(
       entities: entities,
       entity_type_options: entity_type_options,
       events: events,
       has_next_page: has_next_page,
       expanded_event_id: nil,
       page: page
     )
     |> assign_filters(filters)}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    {:noreply, push_patch(socket, to: audit_log_path(parse_filters(params), 1))}
  end

  def handle_event("set_date_preset", %{"preset" => preset}, socket) do
    filters =
      socket.assigns.filters
      |> Map.put(:date_preset, preset)
      |> normalize_date_filters()

    {:noreply, push_patch(socket, to: audit_log_path(filters, 1))}
  end

  def handle_event("toggle_event", %{"id" => id}, socket) do
    expanded_event_id =
      if socket.assigns.expanded_event_id == id do
        nil
      else
        id
      end

    {:noreply, assign(socket, :expanded_event_id, expanded_event_id)}
  end

  def handle_event("go_page", %{"page" => page}, socket) do
    {:noreply, push_patch(socket, to: audit_log_path(socket.assigns.filters, parse_page(page)))}
  end

  defp default_filters do
    %{
      owner_entity_id: "",
      entity_type: "",
      action: "",
      channel: "",
      date_preset: "all",
      occurred_after: nil,
      occurred_before: nil
    }
  end

  defp parse_state_from_uri(uri) do
    clauses =
      uri
      |> URI.parse()
      |> Map.get(:query)
      |> FilterQuery.decode()

    filters =
      %{
        owner_entity_id: clauses["entity"] || "",
        entity_type: clauses["type"] || "",
        action: clauses["action"] || "",
        channel: clauses["channel"] || "",
        date_preset: clauses["date"] || "all"
      }
      |> normalize_date_filters()
      |> normalize_owner_entity_filter()
      |> normalize_channel_filter()

    {filters, parse_page(clauses["page"])}
  end

  defp parse_filters(params) do
    %{
      owner_entity_id: params["owner_entity_id"] |> Helpers.blank_to_nil() || "",
      entity_type: params["entity_type"] || "",
      action: params["action"] || "",
      channel: params["channel"] || "",
      date_preset: params["date_preset"] || "all"
    }
    |> normalize_date_filters()
    |> normalize_owner_entity_filter()
    |> normalize_channel_filter()
  end

  defp normalize_owner_entity_filter(filters) do
    case Helpers.blank_to_nil(filters.owner_entity_id) do
      nil ->
        Map.put(filters, :owner_entity_id, "")

      entity_id ->
        if Ecto.UUID.cast(entity_id) == {:ok, entity_id} do
          Map.put(filters, :owner_entity_id, entity_id)
        else
          Map.put(filters, :owner_entity_id, "")
        end
    end
  end

  defp normalize_channel_filter(filters) do
    if filters.channel in @channels do
      filters
    else
      Map.put(filters, :channel, "")
    end
  end

  defp normalize_date_filters(filters) do
    {occurred_after, occurred_before} = preset_datetime_range(filters.date_preset)

    filters
    |> Map.put(:date_preset, normalize_date_preset(filters.date_preset))
    |> Map.put(:occurred_after, occurred_after)
    |> Map.put(:occurred_before, occurred_before)
  end

  defp normalize_date_preset(preset) when preset in ["today", "this_week", "this_month", "all"],
    do: preset

  defp normalize_date_preset(_preset), do: "all"

  defp preset_datetime_range(preset) do
    today = Date.utc_today()

    case normalize_date_preset(preset) do
      "today" ->
        {start_of_day(today), end_of_day(today)}

      "this_week" ->
        start_date = Date.add(today, 1 - Date.day_of_week(today, :monday))
        {start_of_day(start_date), end_of_day(today)}

      "this_month" ->
        start_date = %Date{year: today.year, month: today.month, day: 1}
        {start_of_day(start_date), end_of_day(today)}

      "all" ->
        {nil, nil}
    end
  end

  defp start_of_day(%Date{} = date), do: DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
  defp end_of_day(%Date{} = date), do: DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")

  defp load_events(filters, page) do
    offset = (page - 1) * @page_size

    events =
      filters
      |> audit_filter_opts()
      |> Keyword.merge(limit: @page_size + 1, offset: offset)
      |> Audit.list_audit_events()

    {visible_events, extra_events} = Enum.split(events, @page_size)
    {visible_events, extra_events != []}
  end

  defp audit_filter_opts(filters) do
    []
    |> maybe_put_filter(:owner_entity_id, Helpers.blank_to_nil(filters.owner_entity_id))
    |> maybe_put_filter(:entity_type, Helpers.blank_to_nil(filters.entity_type))
    |> maybe_put_filter(:action, Helpers.blank_to_nil(filters.action))
    |> maybe_put_filter(:channel, parse_channel(filters.channel))
    |> maybe_put_filter(:occurred_after, filters.occurred_after)
    |> maybe_put_filter(:occurred_before, filters.occurred_before)
  end

  defp maybe_put_filter(opts, _key, nil), do: opts
  defp maybe_put_filter(opts, _key, ""), do: opts
  defp maybe_put_filter(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_channel("web"), do: :web
  defp parse_channel("system"), do: :system
  defp parse_channel("mcp"), do: :mcp
  defp parse_channel("ai_assistant"), do: :ai_assistant
  defp parse_channel(_value), do: nil

  defp assign_filters(socket, filters) do
    assign(socket,
      filters: filters,
      filters_form: to_form(stringify_filter_keys(filters), as: :filters)
    )
  end

  defp stringify_filter_keys(filters) do
    Map.new(filters, fn {key, value} ->
      normalized_value =
        case value do
          %DateTime{} -> DateTime.to_iso8601(value)
          nil -> ""
          other -> other
        end

      {Atom.to_string(key), normalized_value}
    end)
  end

  defp date_preset_options do
    [
      {dgettext("audit_log", "filter_date_today"), "today"},
      {dgettext("audit_log", "filter_date_this_week"), "this_week"},
      {dgettext("audit_log", "filter_date_this_month"), "this_month"},
      {dgettext("audit_log", "filter_date_all"), "all"}
    ]
  end

  defp action_filter_options do
    [{dgettext("audit_log", "filter_action_all"), ""}] ++
      Enum.map(@actions, fn action ->
        {action_label(action), action}
      end)
  end

  defp channel_filter_options do
    [{dgettext("audit_log", "filter_channel_all"), ""}] ++
      Enum.map(@channels, fn channel ->
        {channel_label(channel), channel}
      end)
  end

  defp entity_type_filter_options(entity_types) do
    [{dgettext("audit_log", "filter_entity_type_all"), ""}] ++
      Enum.map(entity_types, &{&1, &1})
  end

  defp owner_entity_filter_options(entities) do
    [{dgettext("audit_log", "filter_entity_id_all"), ""}] ++ Enum.map(entities, &{&1.name, &1.id})
  end

  defp pagination_button_class(enabled?) do
    base =
      "rounded-xl border px-3 py-2 text-sm font-medium transition"

    if enabled? do
      base <>
        " border-white/10 bg-white/[0.03] text-white/85 hover:border-white/20 hover:bg-white/[0.06]"
    else
      base <> " cursor-not-allowed border-white/5 bg-white/[0.02] text-white/35"
    end
  end

  defp date_preset_button_class(true) do
    "rounded-xl border border-emerald-400/40 bg-emerald-400/15 px-3 py-2 text-sm font-medium text-emerald-100 transition"
  end

  defp date_preset_button_class(false) do
    "rounded-xl border border-white/10 bg-white/[0.03] px-3 py-2 text-sm font-medium text-white/72 transition hover:border-white/20 hover:bg-white/[0.06]"
  end

  defp formatted_occurred_at(%DateTime{} = occurred_at) do
    Calendar.strftime(occurred_at, "%Y-%m-%d %H:%M:%S UTC")
  end

  defp action_label("created"), do: dgettext("audit_log", "action_created")
  defp action_label("updated"), do: dgettext("audit_log", "action_updated")
  defp action_label("archived"), do: dgettext("audit_log", "action_archived")
  defp action_label("unarchived"), do: dgettext("audit_log", "action_unarchived")
  defp action_label("voided"), do: dgettext("audit_log", "action_voided")
  defp action_label(action), do: action

  defp channel_label("web"), do: dgettext("audit_log", "channel_web")
  defp channel_label("system"), do: dgettext("audit_log", "channel_system")
  defp channel_label("mcp"), do: dgettext("audit_log", "channel_mcp")
  defp channel_label("ai_assistant"), do: dgettext("audit_log", "channel_ai_assistant")
  defp channel_label(channel), do: channel

  defp pretty_snapshot(nil), do: nil
  defp pretty_snapshot(snapshot), do: Jason.encode!(snapshot, pretty: true)

  defp audit_log_path(filters, page) do
    FilterQuery.build_path("/audit-log",
      entity: FilterQuery.skip_default(filters.owner_entity_id, ""),
      type: FilterQuery.skip_default(filters.entity_type, ""),
      action: FilterQuery.skip_default(filters.action, ""),
      channel: FilterQuery.skip_default(filters.channel, ""),
      date: FilterQuery.skip_default(filters.date_preset, "all"),
      page: FilterQuery.skip_default(page, 1)
    )
  end

  defp active_filters?(filters) do
    filters.owner_entity_id != "" or filters.entity_type != "" or filters.action != "" or
      filters.channel != "" or filters.date_preset != "all"
  end

  defp parse_page(page) when is_integer(page) and page > 0, do: page

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {parsed, ""} when parsed > 0 -> parsed
      _ -> 1
    end
  end

  defp parse_page(_page), do: 1
end
