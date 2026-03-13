defmodule AurumFinanceWeb.RulesLive do
  @moduledoc """
  LiveView workspace for scoped rule groups and ordered rules.
  """

  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.CoreComponents
  import AurumFinanceWeb.RulesComponents
  import AurumFinanceWeb.UiComponents

  alias AurumFinance.Classification
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleAction
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger
  alias Phoenix.LiveView.Socket

  @group_scope_types [:global, :entity, :account]
  @target_fields [:category, :tags, :investment_type, :notes]
  @string_operators [
    :equals,
    :contains,
    :starts_with,
    :ends_with,
    :matches_regex,
    :is_empty,
    :is_not_empty
  ]
  @numeric_operators [
    :equals,
    :greater_than,
    :less_than,
    :greater_than_or_equal,
    :less_than_or_equal
  ]
  @action_fields [:category, :tags, :investment_type, :notes]
  @action_operations %{
    category: [:set],
    tags: [:add, :remove],
    investment_type: [:set],
    notes: [:set, :append]
  }

  @impl true
  def mount(_params, _session, socket) do
    entities = Entities.list_entities()

    socket =
      socket
      |> stream_configure(:rule_groups, dom_id: &"rule-group-#{&1.id}")
      |> stream_configure(:rules, dom_id: &"rule-#{&1.id}")
      |> assign(
        active_nav: :rules,
        page_title: dgettext("rules", "page_title"),
        entities: entities,
        current_entity: List.first(entities),
        selected_account_id: nil,
        visible_groups: [],
        visible_group_lookup: %{},
        selected_group: nil,
        selected_group_card: nil,
        selected_rule_lookup: %{},
        entity_accounts: [],
        category_accounts: [],
        all_accounts: [],
        panel: nil,
        group_form_mode: :new,
        rule_form_mode: :new,
        editing_rule_group: nil,
        editing_rule: nil,
        rule_group_count: 0,
        rule_count: 0
      )
      |> stream(:rule_groups, [], reset: true)
      |> stream(:rules, [], reset: true)
      |> assign_group_form(%RuleGroup{}, %{})
      |> assign_rule_form(%Rule{}, %{}, :new)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    current_entity = resolve_current_entity(socket.assigns.entities, params["entity_id"])
    entity_accounts = load_entity_accounts(current_entity)
    selected_account_id = resolve_selected_account_id(entity_accounts, params["account_id"])
    category_accounts = load_category_accounts(current_entity)
    all_accounts = load_all_accounts(socket.assigns.entities)

    visible_groups =
      load_visible_groups(
        current_entity,
        selected_account_id,
        entity_accounts,
        all_accounts,
        category_accounts,
        socket.assigns.entities
      )

    visible_group_lookup = Map.new(visible_groups, &{&1.id, &1})
    selected_group_card = resolve_selected_group(visible_groups, params["group_id"])
    selected_group = load_selected_group(selected_group_card)
    rules = build_rule_cards(selected_group, category_accounts)

    selected_rule_lookup =
      Map.new(List.wrap(selected_group && selected_group.rules), &{&1.id, &1})

    panel = parse_panel(params["panel"])

    socket =
      socket
      |> assign(
        current_entity: current_entity,
        selected_account_id: selected_account_id,
        entity_accounts: entity_accounts,
        category_accounts: category_accounts,
        all_accounts: all_accounts,
        visible_groups: visible_groups,
        visible_group_lookup: visible_group_lookup,
        selected_group: selected_group,
        selected_group_card: selected_group_card,
        selected_rule_lookup: selected_rule_lookup,
        panel: panel,
        rule_creation_blocker: rule_creation_blocker(selected_group, category_accounts),
        max_group_priority: priority_upper_bound(visible_groups),
        rule_group_count: length(visible_groups),
        rule_count: length(rules)
      )
      |> stream(:rule_groups, visible_groups, reset: true)
      |> stream(:rules, rules, reset: true)
      |> assign_panel_state(panel, params)

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "change_scope_filters",
        %{"scope" => scope_params},
        socket
      ) do
    entity_id = Map.get(scope_params, "entity_id", "__all__")
    account_id = Map.get(scope_params, "account_id")

    {:noreply,
     push_patch(socket,
       to:
         rules_path(socket, %{
           "entity_id" => entity_id,
           "account_id" => normalize_account_filter_param(entity_id, account_id),
           "group_id" => nil,
           "panel" => nil,
           "rule_id" => nil
         })
     )}
  end

  def handle_event("select_group", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket,
       to: rules_path(socket, %{"group_id" => id, "panel" => nil, "rule_id" => nil})
     )}
  end

  def handle_event("new_group", _params, socket) do
    {:noreply,
     push_patch(socket, to: rules_path(socket, %{"panel" => "new-group", "rule_id" => nil}))}
  end

  def handle_event("edit_group", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket,
       to: rules_path(socket, %{"group_id" => id, "panel" => "edit-group", "rule_id" => nil})
     )}
  end

  def handle_event("delete_group", %{"id" => id}, socket) do
    case fetch_visible_rule_group(socket, id) do
      nil ->
        {:noreply, socket}

      rule_group ->
        case Classification.delete_rule_group(rule_group, actor: "root", channel: :web) do
          {:ok, _deleted_rule_group} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("rules", "flash_rule_group_deleted"))
             |> push_patch(
               to:
                 rules_path(socket, %{
                   "group_id" => nil,
                   "panel" => nil,
                   "rule_id" => nil
                 })
             )}

          {:error, {:audit_failed, _reason}} ->
            {:noreply, put_flash(socket, :error, dgettext("rules", "flash_audit_logging_failed"))}

          {:error, _reason} ->
            {:noreply,
             put_flash(socket, :error, dgettext("rules", "flash_rule_group_delete_failed"))}
        end
    end
  end

  def handle_event(
        "toggle_selected_group_active",
        _params,
        %{assigns: %{selected_group: nil}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("toggle_selected_group_active", _params, socket) do
    rule_group = socket.assigns.selected_group
    attrs = %{is_active: !rule_group.is_active}

    {:noreply,
     handle_group_write_result(
       socket,
       Classification.update_rule_group(rule_group, attrs, actor: "root", channel: :web),
       dgettext("rules", "flash_rule_group_updated")
     )}
  end

  def handle_event(
        "raise_selected_group_priority",
        _params,
        %{assigns: %{selected_group: nil}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("raise_selected_group_priority", _params, socket) do
    maybe_update_selected_group_priority(socket, -1)
  end

  def handle_event(
        "lower_selected_group_priority",
        _params,
        %{assigns: %{selected_group: nil}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("lower_selected_group_priority", _params, socket) do
    maybe_update_selected_group_priority(socket, 1)
  end

  def handle_event("close_panel", _params, socket) do
    {:noreply, push_patch(socket, to: rules_path(socket, %{"panel" => nil, "rule_id" => nil}))}
  end

  def handle_event("validate_group", %{"rule_group" => params}, socket) do
    target_group = socket.assigns.editing_rule_group || %RuleGroup{}
    attrs = normalize_rule_group_params(params, socket.assigns.current_entity)

    changeset =
      target_group
      |> Classification.change_rule_group(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :group_form, to_form(changeset, as: :rule_group))}
  end

  def handle_event("save_group", %{"rule_group" => params}, socket) do
    attrs = normalize_rule_group_params(params, socket.assigns.current_entity)

    result =
      case socket.assigns.editing_rule_group do
        nil ->
          Classification.create_rule_group(attrs, actor: "root", channel: :web)

        rule_group ->
          Classification.update_rule_group(rule_group, attrs, actor: "root", channel: :web)
      end

    success_message =
      if socket.assigns.editing_rule_group,
        do: dgettext("rules", "flash_rule_group_updated"),
        else: dgettext("rules", "flash_rule_group_created")

    {:noreply, handle_group_write_result(socket, result, success_message)}
  end

  def handle_event("new_rule", _params, %{assigns: %{selected_group: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("new_rule", _params, %{assigns: %{rule_creation_blocker: blocker}} = socket)
      when is_binary(blocker) do
    {:noreply, put_flash(socket, :error, blocker)}
  end

  def handle_event("new_rule", _params, socket) do
    {:noreply,
     push_patch(socket, to: rules_path(socket, %{"panel" => "new-rule", "rule_id" => nil}))}
  end

  def handle_event("edit_rule", %{"id" => id}, socket) do
    {:noreply,
     push_patch(socket,
       to: rules_path(socket, %{"panel" => "edit-rule", "rule_id" => id})
     )}
  end

  def handle_event("delete_rule", %{"id" => id}, socket) do
    case Map.get(socket.assigns.selected_rule_lookup, id) do
      nil ->
        {:noreply, socket}

      rule ->
        case Classification.delete_rule(rule, actor: "root", channel: :web) do
          {:ok, _deleted_rule} ->
            {:noreply,
             socket
             |> put_flash(:info, dgettext("rules", "flash_rule_deleted"))
             |> push_patch(to: rules_path(socket, %{"panel" => nil, "rule_id" => nil}))}

          {:error, {:audit_failed, _reason}} ->
            {:noreply, put_flash(socket, :error, dgettext("rules", "flash_audit_logging_failed"))}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, dgettext("rules", "flash_rule_delete_failed"))}
        end
    end
  end

  def handle_event("validate_rule", %{"rule" => params}, socket) do
    target_rule = socket.assigns.editing_rule || %Rule{}
    mode = socket.assigns.rule_form_mode

    {:noreply,
     socket
     |> assign_rule_form(target_rule, params, mode, action: :validate)}
  end

  def handle_event("save_rule", %{"rule" => params}, socket) do
    mode = socket.assigns.rule_form_mode
    attrs = normalize_rule_write_attrs(params, mode)

    result =
      case socket.assigns.editing_rule do
        nil -> Classification.create_rule(attrs, actor: "root", channel: :web)
        rule -> Classification.update_rule(rule, attrs, actor: "root", channel: :web)
      end

    success_message =
      if socket.assigns.editing_rule,
        do: dgettext("rules", "flash_rule_updated"),
        else: dgettext("rules", "flash_rule_created")

    case result do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> put_flash(:info, success_message)
         |> push_patch(to: rules_path(socket, %{"panel" => nil, "rule_id" => nil}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:rule_form, to_form(Map.put(changeset, :action, :validate), as: :rule))
         |> assign(:rule_params, normalize_rule_form_params(params, mode, socket))}
    end
  end

  def handle_event("add_condition_row", _params, socket) do
    params = add_condition_row(socket.assigns.rule_params)
    target_rule = socket.assigns.editing_rule || %Rule{}

    {:noreply, assign_rule_form(socket, target_rule, params, socket.assigns.rule_form_mode)}
  end

  def handle_event("remove_condition_row", %{"index" => index}, socket) do
    params = remove_condition_row(socket.assigns.rule_params, index)
    target_rule = socket.assigns.editing_rule || %Rule{}

    {:noreply, assign_rule_form(socket, target_rule, params, socket.assigns.rule_form_mode)}
  end

  def handle_event("add_action_row", _params, socket) do
    params = add_action_row(socket.assigns.rule_params)
    target_rule = socket.assigns.editing_rule || %Rule{}

    {:noreply, assign_rule_form(socket, target_rule, params, socket.assigns.rule_form_mode)}
  end

  def handle_event("remove_action_row", %{"index" => index}, socket) do
    params = remove_action_row(socket.assigns.rule_params, index)
    target_rule = socket.assigns.editing_rule || %Rule{}

    {:noreply, assign_rule_form(socket, target_rule, params, socket.assigns.rule_form_mode)}
  end

  attr :open, :boolean, required: true
  attr :group_form, :any, required: true
  attr :group_form_mode, :atom, required: true
  attr :current_entity, :any, required: true
  attr :entities, :list, required: true
  attr :accounts, :list, required: true

  defp group_form_panel(assigns) do
    ~H"""
    <AurumFinanceWeb.SlideoverComponents.right_sidebar_panel
      open={@open}
      panel_id="rule-group-panel"
      overlay_id="rule-group-panel-overlay"
      close_button_id="close-rule-group-panel"
      title={group_panel_title(@group_form_mode)}
      subtitle={dgettext("rules", "group_panel_subtitle")}
      close_event="close_panel"
    >
      <.form
        :if={@open}
        for={@group_form}
        id="rule-group-form"
        phx-change="validate_group"
        phx-submit="save_group"
        class="space-y-4"
      >
        <.input field={@group_form[:name]} type="text" label={dgettext("rules", "field_group_name")} />

        <.info_label
          for={@group_form[:scope_type].id}
          text={dgettext("rules", "field_scope_type")}
          tooltip={dgettext("rules", "tooltip_group_scope_type")}
        />
        <.input
          id="rule-group-scope-type"
          field={@group_form[:scope_type]}
          type="select"
          options={scope_type_options()}
        />

        <.info_label
          :if={group_scope_type(@group_form) == "entity"}
          for={@group_form[:entity_id].id}
          text={dgettext("rules", "field_scope_entity")}
          tooltip={dgettext("rules", "tooltip_group_scope_entity")}
        />
        <.input
          :if={group_scope_type(@group_form) == "entity"}
          id="rule-group-entity-id"
          field={@group_form[:entity_id]}
          type="select"
          options={entity_options(@entities)}
          prompt={dgettext("rules", "prompt_select_entity")}
        />

        <.info_label
          :if={group_scope_type(@group_form) == "account"}
          for={@group_form[:account_id].id}
          text={dgettext("rules", "field_scope_account")}
          tooltip={dgettext("rules", "tooltip_group_scope_account")}
        />
        <.input
          :if={group_scope_type(@group_form) == "account"}
          id="rule-group-account-id"
          field={@group_form[:account_id]}
          type="select"
          options={account_scope_options(@accounts, @entities)}
          prompt={dgettext("rules", "prompt_select_account")}
        />

        <.info_label
          for={@group_form[:priority].id}
          text={dgettext("rules", "field_priority")}
          tooltip={dgettext("rules", "tooltip_group_priority")}
        />
        <.input
          field={@group_form[:priority]}
          type="number"
          min="1"
        />

        <.info_label
          for={@group_form[:description].id}
          text={dgettext("rules", "field_description")}
          tooltip={dgettext("rules", "tooltip_group_description")}
        />
        <.input
          field={@group_form[:description]}
          type="textarea"
          rows="4"
        />

        <.info_label
          for="rule-group-target-fields"
          text={dgettext("rules", "field_target_fields")}
          tooltip={dgettext("rules", "tooltip_group_target_fields")}
        />
        <.input
          id="rule-group-target-fields"
          field={@group_form[:target_fields]}
          type="select"
          options={target_field_options()}
          multiple
          size="4"
          class="min-h-32 w-full rounded-[18px] border border-white/12 bg-slate-950/70 px-3 py-3 text-sm text-white outline-none transition focus:border-white/24"
        />

        <.info_callout title={dgettext("rules", "target_fields_help_title")} tone={:tip}>
          <ul class="list-disc space-y-1 pl-5 text-[12px] leading-relaxed text-white/74">
            <li>{dgettext("rules", "target_fields_help_category")}</li>
            <li>{dgettext("rules", "target_fields_help_tags")}</li>
            <li>{dgettext("rules", "target_fields_help_investment_type")}</li>
            <li>{dgettext("rules", "target_fields_help_notes")}</li>
          </ul>
        </.info_callout>

        <.info_label
          for={@group_form[:is_active].id}
          text={dgettext("rules", "field_is_active")}
          tooltip={dgettext("rules", "tooltip_group_is_active")}
        />
        <.input
          field={@group_form[:is_active]}
          type="checkbox"
          label=""
        />

        <div class="flex flex-wrap items-center justify-end gap-3 pt-3">
          <.button id="cancel-rule-group-button" type="button" phx-click="close_panel">
            {dgettext("rules", "btn_cancel")}
          </.button>
          <.button id="rule-group-save-button" type="submit" variant="primary">
            {dgettext("rules", "btn_save_group")}
          </.button>
        </div>
      </.form>
    </AurumFinanceWeb.SlideoverComponents.right_sidebar_panel>
    """
  end

  attr :open, :boolean, required: true
  attr :rule_form, :any, required: true
  attr :rule_form_mode, :atom, required: true
  attr :rule_params, :map, required: true
  attr :selected_group, :any, required: true
  attr :selected_group_card, :any, required: true
  attr :category_accounts, :list, required: true

  defp rule_form_panel(assigns) do
    ~H"""
    <AurumFinanceWeb.SlideoverComponents.right_sidebar_panel
      open={@open}
      panel_id="rule-panel"
      overlay_id="rule-panel-overlay"
      close_button_id="close-rule-panel"
      title={rule_panel_title(@rule_form_mode)}
      subtitle={dgettext("rules", "rule_panel_subtitle")}
      close_event="close_panel"
    >
      <.form
        :if={@open}
        for={@rule_form}
        id="rule-form"
        phx-change="validate_rule"
        phx-submit="save_rule"
        class="space-y-5"
      >
        <input
          type="hidden"
          name="rule[rule_group_id]"
          value={Map.get(@rule_params, "rule_group_id", "")}
        />

        <div
          :if={@selected_group_card}
          class="rounded-[22px] border border-white/10 bg-white/[0.03] p-4"
        >
          <p class="text-[10px] uppercase tracking-[0.18em] text-white/38">
            {dgettext("rules", "label_rule_group")}
          </p>
          <p class="mt-2 text-[13px] font-semibold text-white/90">{@selected_group_card.name}</p>
        </div>

        <.info_callout
          :if={restricted_target_fields?(@selected_group)}
          title={dgettext("rules", "rule_allowed_actions_title")}
          tone={:tip}
        >
          <p class="text-[12px] leading-relaxed text-white/74">
            {dgettext("rules", "rule_allowed_actions_body")}: {allowed_target_fields_summary(
              @selected_group
            )}
          </p>
        </.info_callout>

        <.input field={@rule_form[:name]} type="text" label={dgettext("rules", "field_rule_name")} />

        <div class="grid gap-4 sm:grid-cols-[minmax(0,1fr)_minmax(0,4fr)]">
          <.input
            field={@rule_form[:position]}
            type="number"
            label={dgettext("rules", "field_position")}
            min="1"
          />

          <.input
            field={@rule_form[:description]}
            type="text"
            label={dgettext("rules", "field_description")}
          />
        </div>

        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@rule_form[:is_active]}
            type="checkbox"
            label={dgettext("rules", "field_is_active")}
          />

          <.input
            id="rule-stop-processing"
            field={@rule_form[:stop_processing]}
            type="checkbox"
            label={dgettext("rules", "field_stop_processing")}
          />
        </div>

        <div
          :if={@rule_form_mode == :new}
          class="space-y-4 rounded-[26px] border border-white/10 bg-white/[0.03] p-5"
        >
          <div class="flex items-start justify-between gap-3">
            <div>
              <h4 class="text-[13px] font-semibold text-white/92">
                {dgettext("rules", "section_conditions")}
              </h4>
              <p class="mt-1 text-[12px] text-white/58">
                {dgettext("rules", "conditions_builder_subtitle")}
              </p>
            </div>

            <.button id="add-condition-row" type="button" phx-click="add_condition_row">
              {dgettext("rules", "btn_add_condition")}
            </.button>
          </div>

          <p
            :for={error <- expression_errors(@rule_form)}
            class="mt-1.5 flex items-center gap-2 text-sm text-error"
          >
            <.icon name="hero-exclamation-circle" class="size-5" />
            {error}
          </p>

          <div id="condition-rows" class="space-y-3">
            <div
              :for={{condition, index} <- indexed_condition_rows(@rule_params)}
              id={"condition-row-#{index}"}
              class="rounded-[22px] border border-white/8 bg-slate-950/35 p-4"
            >
              <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_auto]">
                <.input
                  name={"rule[conditions][#{index}][field]"}
                  id={"condition-field-#{index}"}
                  type="select"
                  label={dgettext("rules", "field_condition_field")}
                  value={Map.get(condition, "field", "")}
                  options={condition_field_options()}
                />

                <.input
                  name={"rule[conditions][#{index}][operator]"}
                  id={"condition-operator-#{index}"}
                  type="select"
                  label={dgettext("rules", "field_condition_operator")}
                  value={Map.get(condition, "operator", "")}
                  options={condition_operator_options(condition)}
                />

                <.input
                  name={"rule[conditions][#{index}][value]"}
                  id={"condition-value-#{index}"}
                  type={condition_value_input_type(condition)}
                  label={dgettext("rules", "field_condition_value")}
                  value={Map.get(condition, "value", "")}
                  disabled={condition_value_disabled?(condition)}
                />

                <div class="flex items-end gap-2">
                  <.input
                    name={"rule[conditions][#{index}][negate]"}
                    id={"condition-negate-#{index}"}
                    type="checkbox"
                    label={dgettext("rules", "field_negate")}
                    value={Map.get(condition, "negate", "false")}
                    checked={Map.get(condition, "negate", "false") in [true, "true"]}
                  />

                  <button
                    :if={condition_row_removable?(@rule_params)}
                    type="button"
                    class="au-btn mb-2"
                    phx-click="remove_condition_row"
                    phx-value-index={index}
                  >
                    {dgettext("rules", "btn_remove")}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div :if={@rule_form_mode == :edit} class="space-y-3">
          <.info_callout title={dgettext("rules", "advanced_mode_title")} tone={:warn}>
            <p class="text-[12px] leading-relaxed text-white/74">
              {dgettext("rules", "advanced_mode_body")}
            </p>
          </.info_callout>

          <details class="overflow-hidden rounded-[22px] border border-white/10 bg-white/[0.03]">
            <summary class="flex cursor-pointer list-none items-center justify-between gap-3 px-4 py-3 text-left">
              <span class="flex items-center gap-2 text-[13px] font-semibold text-white/92">
                <.icon name="hero-question-mark-circle-mini" class="size-4 text-cyan-300" />
                {dgettext("rules", "advanced_mode_help_title")}
              </span>
              <.icon name="hero-chevron-down-mini" class="size-4 text-white/45" />
            </summary>

            <div class="space-y-4 border-t border-white/8 px-4 py-4 text-[12px] leading-relaxed text-white/72">
              <p>{dgettext("rules", "advanced_mode_help_intro")}</p>

              <div>
                <p class="font-semibold text-white/90">
                  {dgettext("rules", "advanced_mode_help_fields_title")}
                </p>
                <ul class="mt-2 list-disc space-y-1 pl-5">
                  <li>{dgettext("rules", "advanced_mode_help_fields_strings")}</li>
                  <li>{dgettext("rules", "advanced_mode_help_fields_numbers")}</li>
                  <li>{dgettext("rules", "advanced_mode_help_fields_dates")}</li>
                </ul>
              </div>

              <div>
                <p class="font-semibold text-white/90">
                  {dgettext("rules", "advanced_mode_help_ops_title")}
                </p>
                <ul class="mt-2 list-disc space-y-1 pl-5">
                  <li>{dgettext("rules", "advanced_mode_help_ops_strings")}</li>
                  <li>{dgettext("rules", "advanced_mode_help_ops_numbers")}</li>
                  <li>{dgettext("rules", "advanced_mode_help_ops_logic")}</li>
                </ul>
              </div>

              <div>
                <p class="font-semibold text-white/90">
                  {dgettext("rules", "advanced_mode_help_examples_title")}
                </p>
                <ul class="mt-2 list-disc space-y-1 pl-5 font-mono text-[11px] text-white/68">
                  <li>description contains "Uber"</li>
                  <li>amount &lt; -10</li>
                  <li>(description contains "Uber") AND (amount &lt; -10)</li>
                </ul>
              </div>

              <a
                href="https://hexdocs.pm/excellerate/ExCellerate.html"
                target="_blank"
                rel="noreferrer"
                class="inline-flex items-center gap-2 text-cyan-300 transition hover:text-cyan-200"
              >
                <.icon name="hero-arrow-top-right-on-square-mini" class="size-4" />
                {dgettext("rules", "advanced_mode_help_docs_link")}
              </a>
            </div>
          </details>

          <.input
            id="rule-expression"
            field={@rule_form[:expression]}
            type="textarea"
            label={dgettext("rules", "field_expression")}
            rows="5"
          />
        </div>

        <div class="space-y-4 rounded-[26px] border border-white/10 bg-white/[0.03] p-5">
          <div class="flex items-start justify-between gap-3">
            <div>
              <h4 class="text-[13px] font-semibold text-white/92">
                {dgettext("rules", "section_actions")}
              </h4>
              <p class="mt-1 text-[12px] text-white/58">
                {dgettext("rules", "actions_builder_subtitle")}
              </p>
            </div>

            <.button id="add-action-row" type="button" phx-click="add_action_row">
              {dgettext("rules", "btn_add_action")}
            </.button>
          </div>

          <p
            :for={error <- actions_errors(@rule_form)}
            class="mt-1.5 flex items-center gap-2 text-sm text-error"
          >
            <.icon name="hero-exclamation-circle" class="size-5" />
            {error}
          </p>

          <div id="action-rows" class="space-y-3">
            <div
              :for={{action, index} <- indexed_action_rows(@rule_params)}
              id={"action-row-#{index}"}
              class="rounded-[22px] border border-white/8 bg-slate-950/35 p-4"
            >
              <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,1fr)_minmax(0,1fr)_auto]">
                <.input
                  name={"rule[actions][#{index}][field]"}
                  id={"action-field-#{index}"}
                  type="select"
                  label={dgettext("rules", "field_action_field")}
                  value={Map.get(action, "field", "")}
                  options={action_field_options(@selected_group)}
                />

                <.input
                  name={"rule[actions][#{index}][operation]"}
                  id={"action-operation-#{index}"}
                  type="select"
                  label={dgettext("rules", "field_action_operation")}
                  value={Map.get(action, "operation", "")}
                  options={action_operation_options(action)}
                />

                <.input
                  name={"rule[actions][#{index}][value]"}
                  id={"action-value-#{index}"}
                  type={action_value_input_type(action)}
                  label={dgettext("rules", "field_action_value")}
                  value={Map.get(action, "value", "")}
                  options={action_value_options(action, @category_accounts)}
                />

                <div class="flex items-end">
                  <button
                    :if={action_row_removable?(@rule_params)}
                    type="button"
                    class="au-btn mb-2"
                    phx-click="remove_action_row"
                    phx-value-index={index}
                  >
                    {dgettext("rules", "btn_remove")}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="flex flex-wrap items-center justify-end gap-3 pt-3">
          <.button id="cancel-rule-button" type="button" phx-click="close_panel">
            {dgettext("rules", "btn_cancel")}
          </.button>
          <.button id="rule-save-button" type="submit" variant="primary">
            {dgettext("rules", "btn_save_rule")}
          </.button>
        </div>
      </.form>
    </AurumFinanceWeb.SlideoverComponents.right_sidebar_panel>
    """
  end

  defp assign_panel_state(socket, nil, _params) do
    socket
    |> assign(:editing_rule_group, nil)
    |> assign(:editing_rule, nil)
    |> assign(:group_form_mode, :new)
    |> assign(:rule_form_mode, :new)
    |> assign_group_form(
      %RuleGroup{},
      default_group_params(socket.assigns.current_entity, socket.assigns.rule_group_count + 1)
    )
    |> assign_rule_form(%Rule{}, default_new_rule_params(socket.assigns.selected_group), :new)
  end

  defp assign_panel_state(socket, :new_group, _params) do
    socket
    |> assign(:group_form_mode, :new)
    |> assign(:editing_rule_group, nil)
    |> assign_group_form(
      %RuleGroup{},
      default_group_params(socket.assigns.current_entity, socket.assigns.rule_group_count + 1)
    )
  end

  defp assign_panel_state(socket, :edit_group, _params) do
    case socket.assigns.selected_group do
      nil ->
        assign_panel_state(socket, nil, %{})

      rule_group ->
        socket
        |> assign(:group_form_mode, :edit)
        |> assign(:editing_rule_group, rule_group)
        |> assign_group_form(rule_group, rule_group_params(rule_group))
    end
  end

  defp assign_panel_state(socket, :new_rule, _params) do
    case socket.assigns.selected_group do
      nil ->
        assign_panel_state(socket, nil, %{})

      rule_group ->
        socket
        |> assign(:rule_form_mode, :new)
        |> assign(:editing_rule, nil)
        |> assign_rule_form(%Rule{}, default_new_rule_params(rule_group), :new)
    end
  end

  defp assign_panel_state(socket, :edit_rule, %{"rule_id" => rule_id}) when is_binary(rule_id) do
    case Map.get(socket.assigns.selected_rule_lookup, rule_id) do
      nil ->
        assign_panel_state(socket, nil, %{})

      rule ->
        socket
        |> assign(:rule_form_mode, :edit)
        |> assign(:editing_rule, rule)
        |> assign_rule_form(rule, edit_rule_params(rule), :edit)
    end
  end

  defp assign_panel_state(socket, :edit_rule, _params), do: assign_panel_state(socket, nil, %{})

  defp assign_group_form(socket, %RuleGroup{} = rule_group, attrs) do
    changeset = Classification.change_rule_group(rule_group, attrs)
    assign(socket, :group_form, to_form(changeset, as: :rule_group))
  end

  defp assign_rule_form(socket, %Rule{} = rule, params, mode, opts \\ []) do
    params = normalize_rule_form_params(params, mode, socket)
    changeset = build_rule_form_changeset(rule, params, mode, opts)

    socket
    |> assign(:rule_params, params)
    |> assign(:rule_form, to_form(changeset, as: :rule))
  end

  defp build_rule_form_changeset(%Rule{} = rule, params, mode, opts) do
    case validate_rule_expression(params, mode) do
      {:ok, expression} ->
        params
        |> rule_changeset_attrs(mode)
        |> Map.put("expression", expression)
        |> then(&Classification.change_rule(rule, &1))
        |> maybe_put_changeset_action(opts[:action])

      {:error, reason} ->
        changeset =
          params
          |> rule_changeset_attrs(mode)
          |> then(&Classification.change_rule(rule, &1))
          |> maybe_put_changeset_action(opts[:action])

        if mode == :new and reason == :empty_conditions and opts[:action] == :validate do
          drop_field_errors(changeset, :expression)
        else
          changeset
          |> drop_field_errors(:expression)
          |> Ecto.Changeset.add_error(:expression, expression_error_message(reason))
        end
    end
  end

  defp maybe_put_changeset_action(changeset, nil), do: changeset
  defp maybe_put_changeset_action(changeset, action), do: Map.put(changeset, :action, action)

  defp drop_field_errors(changeset, field) do
    errors = Keyword.delete(changeset.errors, field)
    %{changeset | errors: errors, valid?: errors == []}
  end

  defp resolve_current_entity([], _entity_id), do: nil
  defp resolve_current_entity(_entities, "__all__"), do: nil

  defp resolve_current_entity(entities, entity_id) when is_binary(entity_id) do
    Enum.find(entities, List.first(entities), &(&1.id == entity_id))
  end

  defp resolve_current_entity(entities, _entity_id), do: List.first(entities)

  defp load_entity_accounts(nil), do: []
  defp load_entity_accounts(%Entity{} = entity), do: Ledger.list_accounts(entity_id: entity.id)

  defp load_all_accounts(entities) do
    entities
    |> Enum.map(& &1.id)
    |> Ledger.list_accounts_for_entities()
  end

  defp load_category_accounts(nil), do: []

  defp load_category_accounts(%Entity{} = entity),
    do: Ledger.list_category_accounts(entity_id: entity.id)

  defp resolve_selected_account_id(entity_accounts, account_id) when is_binary(account_id) do
    case Enum.find(entity_accounts, &(&1.id == account_id)) do
      nil -> nil
      account -> account.id
    end
  end

  defp resolve_selected_account_id(_entity_accounts, _account_id), do: nil

  defp load_visible_groups(
         nil,
         _selected_account_id,
         _entity_accounts,
         all_accounts,
         category_accounts,
         entities
       ) do
    entity_lookup = Map.new(entities, &{&1.id, &1.name})
    account_lookup = Map.new(all_accounts, &{&1.id, &1.name})
    category_lookup = Map.new(category_accounts, &{&1.id, &1.name})

    Classification.list_rule_groups()
    |> Enum.map(&build_rule_group_card(&1, entity_lookup, account_lookup, category_lookup))
  end

  defp load_visible_groups(
         %Entity{} = entity,
         selected_account_id,
         entity_accounts,
         _all_accounts,
         category_accounts,
         entities
       ) do
    account_ids = visible_account_ids(entity_accounts, selected_account_id)
    entity_lookup = Map.new(entities, &{&1.id, &1.name})
    account_lookup = Map.new(entity_accounts, &{&1.id, &1.name})
    category_lookup = Map.new(category_accounts, &{&1.id, &1.name})

    entity.id
    |> Classification.list_visible_rule_groups(account_ids)
    |> Enum.map(&build_rule_group_card(&1, entity_lookup, account_lookup, category_lookup))
  end

  defp visible_account_ids(entity_accounts, nil), do: Enum.map(entity_accounts, & &1.id)
  defp visible_account_ids(_entity_accounts, selected_account_id), do: [selected_account_id]

  defp resolve_selected_group([], _selected_group_id), do: nil

  defp resolve_selected_group(groups, selected_group_id) when is_binary(selected_group_id) do
    Enum.find(groups, List.first(groups), &(&1.id == selected_group_id))
  end

  defp resolve_selected_group(groups, _selected_group_id), do: List.first(groups)

  defp load_selected_group(nil), do: nil

  defp load_selected_group(group_card) do
    group_card.rule_group
  end

  defp build_rule_group_card(rule_group, entity_lookup, account_lookup, category_lookup) do
    rule_group = sort_rule_group_rules(rule_group)

    %{
      id: rule_group.id,
      name: rule_group.name,
      description: rule_group.description,
      scope_type: rule_group.scope_type,
      scope_label: scope_label(rule_group.scope_type),
      scope_target_label:
        scope_target_label(
          rule_group.scope_type,
          rule_group.entity_id,
          rule_group.account_id,
          entity_lookup,
          account_lookup
        ),
      priority: rule_group.priority,
      rule_count: length(rule_group.rules),
      is_active: rule_group.is_active,
      target_fields:
        rule_group.target_fields
        |> Enum.map(&target_field_label/1)
        |> Enum.reject(&is_nil/1),
      category_lookup: category_lookup,
      rule_group: rule_group
    }
  end

  defp build_rule_cards(nil, _category_accounts), do: []

  defp build_rule_cards(%RuleGroup{} = rule_group, category_accounts) do
    category_lookup = Map.new(category_accounts, &{&1.id, &1.name})

    Enum.map(rule_group.rules, fn rule ->
      %{
        id: rule.id,
        name: rule.name,
        description: rule.description,
        position: rule.position,
        is_active: rule.is_active,
        stop_processing: rule.stop_processing,
        condition_summary: rule.expression,
        action_summary: action_summary(rule.actions, category_lookup)
      }
    end)
  end

  defp maybe_update_selected_group_priority(socket, delta) do
    rule_group = socket.assigns.selected_group
    next_priority = rule_group.priority + delta

    cond do
      next_priority < 1 ->
        {:noreply, socket}

      next_priority > socket.assigns.max_group_priority ->
        {:noreply, socket}

      true ->
        attrs = %{priority: next_priority}

        {:noreply,
         handle_group_write_result(
           socket,
           Classification.update_rule_group(rule_group, attrs, actor: "root", channel: :web),
           dgettext("rules", "flash_rule_group_updated")
         )}
    end
  end

  defp fetch_visible_rule_group(socket, id) do
    case Map.get(socket.assigns.visible_group_lookup, id) do
      nil -> nil
      group_card -> group_card.rule_group
    end
  end

  defp max_visible_group_priority([]), do: 1

  defp max_visible_group_priority(groups) do
    groups
    |> Enum.map(&Map.get(&1, :priority, 1))
    |> Enum.max(fn -> 1 end)
  end

  defp sort_rule_group_rules(%RuleGroup{} = rule_group) do
    Map.update!(rule_group, :rules, &Enum.sort_by(&1, fn rule -> {rule.position, rule.name} end))
  end

  defp priority_upper_bound(groups) do
    max(length(groups), max_visible_group_priority(groups))
  end

  defp rule_creation_blocker(nil, _category_accounts), do: nil

  defp rule_creation_blocker(%RuleGroup{target_fields: []}, _category_accounts), do: nil

  defp rule_creation_blocker(%RuleGroup{target_fields: target_fields}, category_accounts) do
    normalized_fields =
      target_fields
      |> Enum.map(&normalize_target_field/1)
      |> Enum.reject(&is_nil/1)

    cond do
      normalized_fields == [] ->
        nil

      Enum.any?(normalized_fields, &(&1 != :category)) ->
        nil

      category_accounts != [] ->
        nil

      true ->
        dgettext("rules", "rule_creation_blocked_missing_categories")
    end
  end

  defp handle_group_write_result(socket, {:ok, %RuleGroup{} = rule_group}, success_message) do
    socket
    |> put_flash(:info, success_message)
    |> push_patch(
      to:
        rules_path(socket, %{
          "group_id" => rule_group.id,
          "panel" => nil,
          "rule_id" => nil
        })
    )
  end

  defp handle_group_write_result(socket, {:error, {:audit_failed, _reason}}, _success_message) do
    put_flash(socket, :error, dgettext("rules", "flash_audit_logging_failed"))
  end

  defp handle_group_write_result(
         socket,
         {:error, %Ecto.Changeset{} = changeset},
         _success_message
       ) do
    assign(socket, :group_form, to_form(Map.put(changeset, :action, :validate), as: :rule_group))
  end

  defp rules_path(socket, overrides) do
    params =
      socket
      |> current_route_params()
      |> Map.merge(overrides)
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    ~p"/rules?#{params}"
  end

  defp current_route_params(%Socket{} = socket) do
    %{}
    |> maybe_put_param("entity_id", current_entity_param(socket.assigns.current_entity))
    |> maybe_put_param("account_id", socket.assigns.selected_account_id)
    |> maybe_put_param(
      "group_id",
      socket.assigns.selected_group_card && socket.assigns.selected_group_card.id
    )
    |> maybe_put_param("panel", panel_param(socket.assigns.panel))
    |> maybe_put_param("rule_id", socket.assigns.editing_rule && socket.assigns.editing_rule.id)
  end

  defp maybe_put_param(params, _key, nil), do: params
  defp maybe_put_param(params, _key, ""), do: params
  defp maybe_put_param(params, key, value), do: Map.put(params, key, value)

  defp current_entity_param(nil), do: "__all__"
  defp current_entity_param(%Entity{} = entity), do: entity.id

  defp normalize_account_filter_param("__all__", _account_id), do: nil
  defp normalize_account_filter_param(_entity_id, account_id), do: blank_to_nil(account_id)

  defp parse_panel("new-group"), do: :new_group
  defp parse_panel("edit-group"), do: :edit_group
  defp parse_panel("new-rule"), do: :new_rule
  defp parse_panel("edit-rule"), do: :edit_rule
  defp parse_panel(_panel), do: nil

  defp panel_param(nil), do: nil
  defp panel_param(:new_group), do: "new-group"
  defp panel_param(:edit_group), do: "edit-group"
  defp panel_param(:new_rule), do: "new-rule"
  defp panel_param(:edit_rule), do: "edit-rule"

  defp default_group_params(nil, suggested_priority) do
    %{
      "scope_type" => "global",
      "priority" => Integer.to_string(suggested_priority),
      "is_active" => "true",
      "target_fields" => []
    }
  end

  defp default_group_params(%Entity{} = entity, suggested_priority) do
    %{
      "scope_type" => "entity",
      "entity_id" => entity.id,
      "account_id" => "",
      "priority" => Integer.to_string(suggested_priority),
      "is_active" => "true",
      "target_fields" => []
    }
  end

  defp rule_group_params(rule_group) do
    %{
      "scope_type" => to_string(rule_group.scope_type),
      "entity_id" => rule_group.entity_id || "",
      "account_id" => rule_group.account_id || "",
      "name" => rule_group.name || "",
      "priority" => Integer.to_string(rule_group.priority || 1),
      "description" => rule_group.description || "",
      "target_fields" => rule_group.target_fields || [],
      "is_active" => truthy_string(rule_group.is_active)
    }
  end

  defp normalize_rule_group_params(params, current_entity) do
    scope_type = Map.get(params, "scope_type", "global")
    target_fields = normalize_multi_select(Map.get(params, "target_fields", []))
    entity_id = Map.get(params, "entity_id", "")
    account_id = Map.get(params, "account_id", "")

    base =
      params
      |> Map.put("scope_type", scope_type)
      |> Map.put("target_fields", target_fields)
      |> Map.put("entity_id", entity_id)
      |> Map.put("account_id", account_id)

    case scope_type do
      "global" ->
        base
        |> Map.put("entity_id", nil)
        |> Map.put("account_id", nil)

      "entity" ->
        base
        |> Map.put("entity_id", blank_to_nil(entity_id) || (current_entity && current_entity.id))
        |> Map.put("account_id", nil)

      "account" ->
        base
        |> Map.put("entity_id", nil)
        |> Map.put("account_id", blank_to_nil(account_id))

      _ ->
        base
    end
  end

  defp default_new_rule_params(nil), do: blank_rule_params()

  defp default_new_rule_params(%RuleGroup{} = rule_group) do
    next_position =
      rule_group.rules
      |> Enum.map(& &1.position)
      |> Enum.max(fn -> 0 end)
      |> Kernel.+(1)

    %{
      "rule_group_id" => rule_group.id,
      "name" => "",
      "description" => "",
      "position" => Integer.to_string(next_position),
      "is_active" => "true",
      "stop_processing" => "true",
      "expression" => "",
      "conditions" => %{"0" => blank_condition_row()},
      "actions" => %{"0" => blank_action_row()}
    }
  end

  defp edit_rule_params(rule) do
    %{
      "rule_group_id" => rule.rule_group_id,
      "name" => rule.name || "",
      "description" => rule.description || "",
      "position" => Integer.to_string(rule.position || 1),
      "is_active" => truthy_string(rule.is_active),
      "stop_processing" => truthy_string(rule.stop_processing),
      "expression" => rule.expression || "",
      "conditions" => %{"0" => blank_condition_row()},
      "actions" =>
        rule.actions
        |> Enum.with_index()
        |> Map.new(fn {action, index} ->
          {Integer.to_string(index),
           %{
             "field" => action.field && to_string(action.field),
             "operation" => action.operation && to_string(action.operation),
             "value" => action.value || ""
           }}
        end)
    }
  end

  defp blank_rule_params do
    %{
      "rule_group_id" => "",
      "name" => "",
      "description" => "",
      "position" => "1",
      "is_active" => "true",
      "stop_processing" => "true",
      "expression" => "",
      "conditions" => %{"0" => blank_condition_row()},
      "actions" => %{"0" => blank_action_row()}
    }
  end

  defp blank_condition_row do
    %{"field" => "", "operator" => "", "value" => "", "negate" => "false"}
  end

  defp blank_action_row do
    %{"field" => "", "operation" => "", "value" => ""}
  end

  defp normalize_rule_form_params(params, mode, socket) do
    params
    |> stringify_keys()
    |> Map.merge(
      %{
        "rule_group_id" =>
          (socket.assigns.selected_group && socket.assigns.selected_group.id) || ""
      },
      fn _key, left, right ->
        if blank?(left), do: right, else: left
      end
    )
    |> ensure_condition_rows(mode)
    |> ensure_action_rows()
    |> ensure_boolean_defaults()
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {to_string(key), stringify_value(value)}
    end)
  end

  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value), do: value

  defp ensure_condition_rows(params, :edit),
    do: Map.put_new(params, "conditions", %{"0" => blank_condition_row()})

  defp ensure_condition_rows(params, :new) do
    params
    |> Map.put_new("conditions", %{"0" => blank_condition_row()})
    |> update_in(["conditions"], fn conditions ->
      case normalize_row_map(conditions) do
        [] -> %{"0" => blank_condition_row()}
        rows -> rows_to_map(rows)
      end
    end)
  end

  defp ensure_action_rows(params) do
    params
    |> Map.put_new("actions", %{"0" => blank_action_row()})
    |> update_in(["actions"], fn actions ->
      case normalize_row_map(actions) do
        [] -> %{"0" => blank_action_row()}
        rows -> rows_to_map(rows)
      end
    end)
  end

  defp ensure_boolean_defaults(params) do
    params
    |> Map.put_new("is_active", "true")
    |> Map.put_new("stop_processing", "true")
  end

  defp rule_changeset_attrs(params, _mode) do
    %{
      "rule_group_id" => Map.get(params, "rule_group_id"),
      "name" => Map.get(params, "name"),
      "description" => Map.get(params, "description"),
      "position" => Map.get(params, "position"),
      "is_active" => Map.get(params, "is_active"),
      "stop_processing" => Map.get(params, "stop_processing"),
      "expression" => Map.get(params, "expression"),
      "actions" => Map.get(params, "actions", %{})
    }
  end

  defp normalize_rule_write_attrs(params, :new) do
    params = stringify_keys(params)

    %{
      "rule_group_id" => Map.get(params, "rule_group_id"),
      "name" => Map.get(params, "name"),
      "description" => Map.get(params, "description"),
      "position" => Map.get(params, "position"),
      "is_active" => Map.get(params, "is_active"),
      "stop_processing" => Map.get(params, "stop_processing"),
      "conditions" => write_condition_rows(params),
      "actions" => write_action_rows(params)
    }
  end

  defp normalize_rule_write_attrs(params, :edit) do
    params = stringify_keys(params)

    %{
      "rule_group_id" => Map.get(params, "rule_group_id"),
      "name" => Map.get(params, "name"),
      "description" => Map.get(params, "description"),
      "position" => Map.get(params, "position"),
      "is_active" => Map.get(params, "is_active"),
      "stop_processing" => Map.get(params, "stop_processing"),
      "expression" => Map.get(params, "expression"),
      "actions" => write_action_rows(params)
    }
  end

  defp validate_rule_expression(params, :new) do
    params
    |> write_condition_rows()
    |> Classification.compile_conditions()
  end

  defp validate_rule_expression(params, :edit) do
    params
    |> Map.get("expression")
    |> Classification.validate_expression()
  end

  defp expression_error_message(:empty_conditions),
    do: dgettext("errors", "error_rule_expression_required")

  defp expression_error_message(:empty_expression),
    do: dgettext("errors", "error_rule_expression_required")

  defp expression_error_message(:invalid_regex),
    do: dgettext("errors", "error_rule_expression_invalid_regex")

  defp expression_error_message(_reason),
    do: dgettext("errors", "error_rule_expression_invalid")

  defp write_condition_rows(params) do
    params
    |> Map.get("conditions", %{})
    |> normalize_row_map()
    |> Enum.reject(&blank_condition_row?/1)
    |> Enum.map(fn row ->
      %{
        "field" => Map.get(row, "field"),
        "operator" => Map.get(row, "operator"),
        "value" => Map.get(row, "value"),
        "negate" => Map.get(row, "negate", "false")
      }
    end)
  end

  defp write_action_rows(params) do
    params
    |> Map.get("actions", %{})
    |> normalize_row_map()
    |> Enum.reject(&blank_action_row?/1)
    |> Enum.map(fn row ->
      %{
        "field" => Map.get(row, "field"),
        "operation" => Map.get(row, "operation"),
        "value" => Map.get(row, "value")
      }
    end)
  end

  defp normalize_row_map(rows) when is_map(rows) do
    rows
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map(fn {_key, value} -> stringify_keys(value) end)
  end

  defp normalize_row_map(rows) when is_list(rows), do: Enum.map(rows, &stringify_keys/1)
  defp normalize_row_map(_rows), do: []

  defp rows_to_map(rows) do
    rows
    |> Enum.with_index()
    |> Map.new(fn {row, index} -> {Integer.to_string(index), row} end)
  end

  defp blank_condition_row?(row) do
    blank?(Map.get(row, "field")) and blank?(Map.get(row, "operator")) and
      blank?(Map.get(row, "value"))
  end

  defp blank_action_row?(row) do
    blank?(Map.get(row, "field")) and blank?(Map.get(row, "operation")) and
      blank?(Map.get(row, "value"))
  end

  defp add_condition_row(params) do
    rows =
      params
      |> Map.get("conditions", %{})
      |> normalize_row_map()
      |> Kernel.++([blank_condition_row()])

    Map.put(params, "conditions", rows_to_map(rows))
  end

  defp remove_condition_row(params, index) do
    rows =
      params
      |> Map.get("conditions", %{})
      |> normalize_row_map()
      |> List.delete_at(String.to_integer(index))

    params
    |> Map.put("conditions", rows_to_map(if(rows == [], do: [blank_condition_row()], else: rows)))
  end

  defp add_action_row(params) do
    rows =
      params
      |> Map.get("actions", %{})
      |> normalize_row_map()
      |> Kernel.++([blank_action_row()])

    Map.put(params, "actions", rows_to_map(rows))
  end

  defp remove_action_row(params, index) do
    rows =
      params
      |> Map.get("actions", %{})
      |> normalize_row_map()
      |> List.delete_at(String.to_integer(index))

    params
    |> Map.put("actions", rows_to_map(if(rows == [], do: [blank_action_row()], else: rows)))
  end

  defp indexed_condition_rows(params) do
    params
    |> Map.get("conditions", %{})
    |> normalize_row_map()
    |> Enum.with_index()
  end

  defp indexed_action_rows(params) do
    params
    |> Map.get("actions", %{})
    |> normalize_row_map()
    |> Enum.with_index()
  end

  defp condition_row_removable?(params) do
    params
    |> indexed_condition_rows()
    |> length()
    |> Kernel.>(1)
  end

  defp action_row_removable?(params) do
    params
    |> indexed_action_rows()
    |> length()
    |> Kernel.>(1)
  end

  defp context_entity_options(entities) do
    [
      {dgettext("rules", "option_all_entities"), "__all__"}
      | Enum.map(entities, &{&1.name, &1.id})
    ]
  end

  defp entity_options(entities), do: Enum.map(entities, &{&1.name, &1.id})
  defp account_options(accounts), do: Enum.map(accounts, &{&1.name, &1.id})

  defp account_scope_options(accounts, entities) do
    entity_lookup = Map.new(entities, &{&1.id, &1.name})

    accounts
    |> Enum.map(fn account ->
      entity_name =
        Map.get(
          entity_lookup,
          account.entity_id,
          dgettext("rules", "scope_target_unknown_entity")
        )

      {"#{entity_name} - #{account.name}", account.id}
    end)
    |> Enum.sort_by(fn {label, _id} -> String.downcase(label) end)
  end

  defp current_entity_option_value(nil), do: "__all__"
  defp current_entity_option_value(%Entity{} = entity), do: entity.id

  defp scope_type_options do
    Enum.map(@group_scope_types, fn scope_type ->
      {scope_label(scope_type), Atom.to_string(scope_type)}
    end)
  end

  defp target_field_options do
    Enum.map(@target_fields, fn field ->
      {target_field_label(field), Atom.to_string(field)}
    end)
  end

  defp condition_field_options do
    [
      {dgettext("rules", "field_description"), "description"},
      {dgettext("rules", "field_currency_code"), "currency_code"},
      {dgettext("rules", "field_source_type"), "source_type"},
      {dgettext("rules", "field_account_name"), "account_name"},
      {dgettext("rules", "field_account_type"), "account_type"},
      {dgettext("rules", "field_institution_name"), "institution_name"},
      {dgettext("rules", "field_amount"), "amount"},
      {dgettext("rules", "field_abs_amount"), "abs_amount"},
      {dgettext("rules", "field_date"), "date"}
    ]
  end

  defp condition_operator_options(condition) do
    field = Map.get(condition, "field")

    operators =
      case field_type_for_condition(field) do
        :string -> @string_operators
        :number -> @numeric_operators
        :date -> @numeric_operators
      end

    Enum.map(operators, fn operator ->
      {operator_label(operator), Atom.to_string(operator)}
    end)
  end

  defp condition_value_input_type(condition) do
    case field_type_for_condition(Map.get(condition, "field")) do
      :date -> "date"
      _ -> "text"
    end
  end

  defp condition_value_disabled?(condition) do
    Map.get(condition, "operator") in ["is_empty", "is_not_empty"]
  end

  defp field_type_for_condition(field) when field in ["amount", "abs_amount"], do: :number
  defp field_type_for_condition("date"), do: :date
  defp field_type_for_condition(field) when is_binary(field) and field != "", do: :string
  defp field_type_for_condition(_field), do: :string

  defp action_field_options(%RuleGroup{target_fields: []}), do: action_field_options(nil)

  defp action_field_options(%RuleGroup{target_fields: target_fields}) do
    target_fields
    |> Enum.map(&normalize_target_field/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(fn field ->
      {target_field_label(field), Atom.to_string(field)}
    end)
  end

  defp action_field_options(_selected_group) do
    Enum.map(@action_fields, fn field ->
      {target_field_label(field), Atom.to_string(field)}
    end)
  end

  defp restricted_target_fields?(%RuleGroup{target_fields: target_fields}),
    do: target_fields != []

  defp restricted_target_fields?(_group), do: false

  defp allowed_target_fields_summary(%RuleGroup{target_fields: target_fields}) do
    target_fields
    |> Enum.map(&normalize_target_field/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map_join(", ", &target_field_label/1)
  end

  defp allowed_target_fields_summary(_group), do: dgettext("rules", "target_fields_any")

  defp action_operation_options(action) do
    action
    |> Map.get("field")
    |> case do
      nil -> @action_operations[:tags]
      "" -> @action_operations[:tags]
      "category" -> @action_operations[:category]
      "tags" -> @action_operations[:tags]
      "investment_type" -> @action_operations[:investment_type]
      "notes" -> @action_operations[:notes]
      _field -> @action_operations[:tags]
    end
    |> Enum.map(fn operation ->
      {action_operation_label(operation), Atom.to_string(operation)}
    end)
  end

  defp action_value_input_type(action) do
    if Map.get(action, "field") == "category", do: "select", else: "text"
  end

  defp action_value_options(action, category_accounts) do
    if Map.get(action, "field") == "category" do
      case account_options(category_accounts) do
        [] -> [{dgettext("rules", "option_no_categories_available"), ""}]
        options -> options
      end
    else
      []
    end
  end

  defp expression_errors(rule_form),
    do: Enum.map(rule_form[:expression].errors, &translate_error/1)

  defp actions_errors(rule_form) do
    top_level_errors = Enum.map(rule_form[:actions].errors, &translate_error/1)

    nested_errors =
      case rule_form.source do
        %Ecto.Changeset{changes: %{actions: action_changesets}} when is_list(action_changesets) ->
          action_changesets
          |> Enum.with_index(1)
          |> Enum.flat_map(&action_changeset_errors/1)

        _source ->
          []
      end

    top_level_errors ++ nested_errors
  end

  defp action_changeset_errors({changeset, index}) do
    Enum.map(changeset.errors, fn {field, error} ->
      "#{dgettext("rules", "section_actions")} #{index} #{action_error_field_label(field)}: #{translate_error(error)}"
    end)
  end

  defp scope_label(:global), do: dgettext("rules", "scope_global")
  defp scope_label(:entity), do: dgettext("rules", "scope_entity")
  defp scope_label(:account), do: dgettext("rules", "scope_account")

  defp scope_target_label(:global, _entity_id, _account_id, _entity_lookup, _account_lookup),
    do: dgettext("rules", "scope_target_global")

  defp scope_target_label(:entity, entity_id, _account_id, entity_lookup, _account_lookup),
    do: Map.get(entity_lookup, entity_id, dgettext("rules", "scope_target_unknown_entity"))

  defp scope_target_label(:account, _entity_id, account_id, _entity_lookup, account_lookup),
    do: Map.get(account_lookup, account_id, dgettext("rules", "scope_target_unknown_account"))

  defp target_field_label(:category), do: dgettext("rules", "target_field_category")
  defp target_field_label(:tags), do: dgettext("rules", "target_field_tags")
  defp target_field_label(:investment_type), do: dgettext("rules", "target_field_investment_type")
  defp target_field_label(:notes), do: dgettext("rules", "target_field_notes")
  defp target_field_label("category"), do: dgettext("rules", "target_field_category")
  defp target_field_label("tags"), do: dgettext("rules", "target_field_tags")

  defp target_field_label("investment_type"),
    do: dgettext("rules", "target_field_investment_type")

  defp target_field_label("notes"), do: dgettext("rules", "target_field_notes")
  defp target_field_label(_field), do: nil

  defp normalize_target_field(:category), do: :category
  defp normalize_target_field(:tags), do: :tags
  defp normalize_target_field(:investment_type), do: :investment_type
  defp normalize_target_field(:notes), do: :notes
  defp normalize_target_field("category"), do: :category
  defp normalize_target_field("tags"), do: :tags
  defp normalize_target_field("investment_type"), do: :investment_type
  defp normalize_target_field("notes"), do: :notes
  defp normalize_target_field(_field), do: nil

  defp action_summary(actions, category_lookup) do
    actions
    |> Enum.map_join(" · ", fn %RuleAction{} = action ->
      field = target_field_label(action.field)
      operation = action_operation_label(action.operation)

      value =
        if action.field == :category do
          Map.get(category_lookup, action.value, action.value)
        else
          action.value
        end

      "#{field} #{operation} #{value}"
    end)
  end

  defp action_operation_label(:set), do: dgettext("rules", "operation_set")
  defp action_operation_label(:add), do: dgettext("rules", "operation_add")
  defp action_operation_label(:remove), do: dgettext("rules", "operation_remove")
  defp action_operation_label(:append), do: dgettext("rules", "operation_append")

  defp action_error_field_label(:field), do: dgettext("rules", "field_action_field")
  defp action_error_field_label(:operation), do: dgettext("rules", "field_action_operation")
  defp action_error_field_label(:value), do: dgettext("rules", "field_action_value")

  defp operator_label(:equals), do: dgettext("rules", "operator_equals")
  defp operator_label(:contains), do: dgettext("rules", "operator_contains")
  defp operator_label(:starts_with), do: dgettext("rules", "operator_starts_with")
  defp operator_label(:ends_with), do: dgettext("rules", "operator_ends_with")
  defp operator_label(:matches_regex), do: dgettext("rules", "operator_matches_regex")
  defp operator_label(:greater_than), do: dgettext("rules", "operator_greater_than")
  defp operator_label(:less_than), do: dgettext("rules", "operator_less_than")

  defp operator_label(:greater_than_or_equal),
    do: dgettext("rules", "operator_greater_than_or_equal")

  defp operator_label(:less_than_or_equal), do: dgettext("rules", "operator_less_than_or_equal")
  defp operator_label(:is_empty), do: dgettext("rules", "operator_is_empty")
  defp operator_label(:is_not_empty), do: dgettext("rules", "operator_is_not_empty")

  defp selected_group_title(nil), do: dgettext("rules", "section_group_detail_empty")
  defp selected_group_title(_group), do: dgettext("rules", "section_group_detail")

  defp selected_group_badge(nil, _rule_count), do: nil
  defp selected_group_badge(_group, rule_count), do: Integer.to_string(rule_count)

  defp selected_scope_badge_variant(:account), do: :good
  defp selected_scope_badge_variant(:entity), do: :purple
  defp selected_scope_badge_variant(:global), do: :default

  defp target_fields_summary([]), do: dgettext("rules", "target_fields_any")
  defp target_fields_summary(fields), do: Enum.join(fields, ", ")

  defp group_panel_title(:edit), do: dgettext("rules", "panel_title_edit_group")
  defp group_panel_title(_mode), do: dgettext("rules", "panel_title_new_group")

  defp rule_panel_title(:edit), do: dgettext("rules", "panel_title_edit_rule")
  defp rule_panel_title(_mode), do: dgettext("rules", "panel_title_new_rule")

  defp group_scope_type(group_form) do
    case group_form[:scope_type].value do
      value when is_atom(value) -> Atom.to_string(value)
      value when is_binary(value) and value != "" -> value
      _value -> "global"
    end
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp normalize_multi_select(values) when is_list(values) do
    Enum.reject(values, &blank?/1)
  end

  defp normalize_multi_select(value) when is_binary(value) and value != "", do: [value]
  defp normalize_multi_select(_value), do: []

  defp truthy_string(value) when value in [true, "true"], do: "true"
  defp truthy_string(_value), do: "false"

  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(nil), do: true
  defp blank?(_value), do: false

  defp present_text?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_text?(_value), do: false
end
