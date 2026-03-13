defmodule AurumFinanceWeb.RulesComponents do
  @moduledoc """
  Shared UI pieces for the rules management workspace.

  These components keep the LiveView focused on state transitions while the
  markup for rule groups and rule rows stays reusable and testable.
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.CoreComponents
  import AurumFinanceWeb.UiComponents

  @doc """
  Renders one visible rule group row in the sidebar/list pane.

  The group map is expected to include display-ready metadata such as:
  `name`, `description`, `scope_label`, `scope_target_label`, `priority`,
  `rule_count`, and `is_active`.
  """
  attr :group, :map, required: true
  attr :selected, :boolean, default: false

  def rule_group_item(assigns) do
    group = assigns.group

    assigns =
      assigns
      |> assign(:group_id, group_value(group, :id, nil))
      |> assign(:group_active?, group_value(group, :is_active, true))
      |> assign(:group_scope_type, group_value(group, :scope_type, :global))
      |> assign(
        :group_scope_label,
        group_value(group, :scope_label, scope_label(group_value(group, :scope_type, :global)))
      )
      |> assign(
        :group_scope_target_label,
        group_value(group, :scope_target_label, scope_target_label())
      )
      |> assign(:group_priority, group_value(group, :priority, 1))
      |> assign(
        :group_rule_count,
        group_value(group, :rule_count, length(Map.get(group, :rules, [])))
      )

    ~H"""
    <article class={[
      "au-item w-full border transition duration-150",
      @selected &&
        "border-cyan-300/45 bg-cyan-400/[0.08] shadow-[inset_0_0_0_1px_rgba(125,211,252,0.22)]",
      !@selected && "border-transparent hover:border-white/12 hover:bg-white/[0.03]",
      !@group_active? && "opacity-65"
    ]}>
      <button
        :if={@group_id}
        id={"select-rule-group-#{@group_id}"}
        type="button"
        class="flex w-full cursor-pointer items-start justify-between gap-3 text-left"
        phx-click="select_group"
        phx-value-id={@group_id}
      >
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <h3 class="text-[13px] font-semibold text-white/92">{@group.name}</h3>
            <.badge variant={scope_badge_variant(@group_scope_type)}>{@group_scope_label}</.badge>
            <.badge :if={!@group_active?} variant={:warn}>
              {dgettext("rules", "badge_inactive")}
            </.badge>
          </div>

          <p :if={present?(@group.description)} class="mt-2 text-[12px] leading-relaxed text-white/68">
            {@group.description}
          </p>

          <div class="mt-3 flex flex-wrap items-center gap-2 text-[11px] text-white/52">
            <span>{dgettext("rules", "label_scope_target")}: {@group_scope_target_label}</span>
            <span>{dgettext("rules", "label_priority")}: {@group_priority}</span>
          </div>
        </div>

        <div class="flex shrink-0 items-center gap-2">
          <.badge>{@group_rule_count} {dgettext("rules", "label_rules")}</.badge>
          <.icon
            name="hero-chevron-right-mini"
            class={[
              "size-4 transition",
              @selected && "text-cyan-200/90",
              !@selected && "text-white/30"
            ]}
          />
        </div>
      </button>

      <div
        :if={@group_id}
        class="mt-4 flex flex-wrap items-center justify-end gap-2 border-t border-white/8 pt-4"
      >
        <button
          id={"edit-rule-group-#{@group_id}"}
          type="button"
          class="au-btn"
          phx-click="edit_group"
          phx-value-id={@group_id}
        >
          {dgettext("rules", "btn_edit")}
        </button>

        <button
          id={"delete-rule-group-#{@group_id}"}
          type="button"
          class="au-btn"
          phx-click="delete_group"
          phx-value-id={@group_id}
          data-confirm={dgettext("rules", "confirm_delete_rule_group")}
        >
          {dgettext("rules", "btn_delete")}
        </button>
      </div>

      <div :if={!@group_id} class="flex items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <h3 class="text-[13px] font-semibold text-white/92">{@group.name}</h3>
            <.badge variant={scope_badge_variant(@group_scope_type)}>{@group_scope_label}</.badge>
            <.badge :if={!@group_active?} variant={:warn}>
              {dgettext("rules", "badge_inactive")}
            </.badge>
          </div>

          <p :if={present?(@group.description)} class="mt-2 text-[12px] leading-relaxed text-white/68">
            {@group.description}
          </p>

          <div class="mt-3 flex flex-wrap items-center gap-2 text-[11px] text-white/52">
            <span>{dgettext("rules", "label_scope_target")}: {@group_scope_target_label}</span>
            <span>{dgettext("rules", "label_priority")}: {@group_priority}</span>
          </div>
        </div>

        <div class="flex shrink-0 items-center gap-2">
          <.badge>{@group_rule_count} {dgettext("rules", "label_rules")}</.badge>
          <.icon name="hero-chevron-right-mini" class="size-4 text-white/30" />
        </div>
      </div>
    </article>
    """
  end

  @doc """
  Renders one rule row for the selected group detail pane.

  The rule map is expected to include display-ready summaries for conditions
  and actions.
  """
  attr :rule, :map, required: true

  def rule_row(assigns) do
    rule = assigns.rule

    assigns =
      assigns
      |> assign(:rule_id, group_value(rule, :id, nil))
      |> assign(:rule_active?, group_value(rule, :is_active, true))
      |> assign(:rule_position, group_value(rule, :position, group_value(rule, :order, 1)))
      |> assign(:rule_name, group_value(rule, :name, dgettext("rules", "label_rule")))
      |> assign(:rule_description, group_value(rule, :description, nil))
      |> assign(:rule_stop?, group_value(rule, :stop_processing, group_value(rule, :stop, false)))
      |> assign(
        :rule_condition_summary,
        group_value(rule, :condition_summary, group_value(rule, :when, ""))
      )
      |> assign(
        :rule_action_summary,
        group_value(rule, :action_summary, group_value(rule, :then, ""))
      )

    ~H"""
    <article class={[
      "rounded-[20px] border border-white/10 bg-white/[0.03] p-4 transition",
      !@rule_active? && "opacity-65"
    ]}>
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-2">
            <span class="au-badge au-badge-purple au-mono">#{@rule_position}</span>
            <h4 class="text-[13px] font-semibold text-white/92">{@rule_name}</h4>
            <.badge :if={!@rule_active?} variant={:warn}>
              {dgettext("rules", "badge_inactive")}
            </.badge>
            <.badge variant={if(@rule_stop?, do: :good, else: :default)}>
              {if(@rule_stop?,
                do: dgettext("rules", "label_stop_yes"),
                else: dgettext("rules", "label_stop_no")
              )}
            </.badge>
          </div>

          <p :if={present?(@rule_description)} class="mt-2 text-[12px] leading-relaxed text-white/62">
            {@rule_description}
          </p>
        </div>
      </div>

      <div class="mt-4 grid gap-3 lg:grid-cols-2">
        <div class="rounded-2xl border border-white/8 bg-slate-950/35 p-3">
          <p class="text-[10px] uppercase tracking-[0.18em] text-white/38">
            {dgettext("rules", "label_when")}
          </p>
          <p class="mt-2 text-[12px] leading-relaxed text-white/82">{@rule_condition_summary}</p>
        </div>

        <div class="rounded-2xl border border-white/8 bg-slate-950/35 p-3">
          <p class="text-[10px] uppercase tracking-[0.18em] text-white/38">
            {dgettext("rules", "label_then")}
          </p>
          <p class="mt-2 text-[12px] leading-relaxed text-white/82 au-mono">{@rule_action_summary}</p>
        </div>
      </div>

      <div :if={@rule_id} class="mt-4 flex flex-wrap items-center justify-end gap-2">
        <button
          id={"edit-rule-#{@rule_id}"}
          type="button"
          class="au-btn"
          phx-click="edit_rule"
          phx-value-id={@rule_id}
        >
          {dgettext("rules", "btn_edit")}
        </button>

        <button
          id={"delete-rule-#{@rule_id}"}
          type="button"
          class="au-btn"
          phx-click="delete_rule"
          phx-value-id={@rule_id}
          data-confirm={dgettext("rules", "confirm_delete_rule")}
        >
          {dgettext("rules", "btn_delete")}
        </button>
      </div>
    </article>
    """
  end

  defp scope_badge_variant(:account), do: :good
  defp scope_badge_variant(:entity), do: :purple
  defp scope_badge_variant(:global), do: :default
  defp scope_badge_variant(_scope_type), do: :default

  defp scope_label(:account), do: dgettext("rules", "scope_account")
  defp scope_label(:entity), do: dgettext("rules", "scope_entity")
  defp scope_label(:global), do: dgettext("rules", "scope_global")

  defp scope_target_label, do: dgettext("rules", "scope_target_global")

  defp group_value(map, key, default) do
    Map.get(map, key, default)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
