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

  alias Decimal

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

  @doc """
  Renders one preview result row for a transaction, showing proposed changes
  per classification field with scope/rule explainability and protected-field
  indicators.

  ## Examples

      <.preview_result_row result={result} index={0} />
  """
  attr :result, :any, required: true
  attr :index, :integer, required: true
  attr :category_lookup, :map, default: %{}

  def preview_result_row(assigns) do
    transaction = assigns.result.transaction
    postings = Map.get(transaction, :postings, [])

    assigns =
      assigns
      |> assign(:transaction, transaction)
      |> assign(:postings, postings)
      |> assign(:no_match?, assigns.result.no_match?)
      |> assign(:field_summaries, summarize_proposed_changes(assigns.result.proposed_changes))

    ~H"""
    <div class="flex flex-wrap items-start gap-3 lg:gap-4">
      <div class="min-w-[220px] flex-1 basis-[260px]">
        <div class="flex flex-wrap items-center gap-2">
          <span class="au-badge au-badge-purple au-mono">#{@index + 1}</span>
          <time
            class="text-[12px] font-semibold text-white/82"
            datetime={Date.to_iso8601(@transaction.date)}
          >
            {Calendar.strftime(@transaction.date, "%Y-%m-%d")}
          </time>
          <span class="text-[13px] font-semibold text-white/92">
            {@transaction.description}
          </span>
          <.badge :if={@no_match?} variant={:warn}>
            {dgettext("rules", "badge_no_match")}
          </.badge>
        </div>
      </div>

      <div :if={@postings != []} class="flex min-w-[240px] flex-1 basis-[280px] flex-wrap gap-2">
        <span
          :for={posting <- @postings}
          class="inline-flex items-center gap-1.5 rounded-full border border-white/8 bg-slate-950/40 px-2.5 py-0.5 text-[11px] text-white/62"
        >
          <span :if={account_name(posting)}>{account_name(posting)}</span>
          <span class="au-mono">{format_posting_amount(posting.amount)}</span>
        </span>
      </div>

      <div
        :if={!@no_match? && @field_summaries != []}
        class="flex min-w-[280px] flex-[2_1_420px] basis-[420px] flex-wrap gap-2"
      >
        <.proposed_change_cell
          :for={summary <- @field_summaries}
          change_summary={summary}
          category_lookup={@category_lookup}
          dom_id={"preview-change-#{@index}-#{summary.field}"}
        />
      </div>

      <div :if={!@no_match? && @field_summaries == []} class="min-w-[180px] flex-1 basis-[240px]">
        <p class="text-[12px] text-white/45">{dgettext("rules", "preview_no_proposed_changes")}</p>
      </div>
    </div>
    """
  end

  @doc """
  Renders one proposed-change cell within a preview result row.

  Distinguishes `:proposed`, `:protected`, `:skipped_claimed`, and `:invalid`
  statuses with appropriate styling. Shows the group/rule name for
  explainability.
  """
  attr :change_summary, :map, required: true
  attr :category_lookup, :map, default: %{}
  attr :dom_id, :string, required: true

  def proposed_change_cell(assigns) do
    summary = assigns.change_summary
    primary_change = summary.primary_change

    assigns =
      assigns
      |> assign(:status, primary_change.status)
      |> assign(:field, summary.field)
      |> assign(:proposed_value, primary_change.proposed_value)
      |> assign(:rule_group, primary_change.rule_group)
      |> assign(:rule, primary_change.rule)
      |> assign(:scope_type, primary_change.rule_group && primary_change.rule_group.scope_type)
      |> assign(:supporting_changes, summary.supporting_changes)

    ~H"""
    <div
      id={@dom_id}
      data-preview-field={@field}
      class={[
        "basis-[180px] grow rounded-2xl border px-3 py-2.5 text-[12px]",
        @status == :proposed && "border-cyan-400/20 bg-cyan-400/[0.06]",
        @status == :protected && "border-amber-400/20 bg-amber-400/[0.06]",
        @status == :skipped_claimed && "border-white/8 bg-white/[0.02] opacity-60",
        @status == :invalid && "border-red-400/20 bg-red-400/[0.06]"
      ]}
    >
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-[10px] uppercase tracking-[0.16em] text-white/40">
          {field_label(@field)}
        </span>
        <.change_status_badge status={@status} />
        <.scope_badge :if={@scope_type} scope_type={@scope_type} />
      </div>

      <p class={[
        "mt-1 au-mono text-[11px] leading-relaxed",
        @status == :proposed && "text-cyan-200/90",
        @status == :protected && "text-amber-200/80",
        @status in [:skipped_claimed, :invalid] && "text-white/45"
      ]}>
        {format_proposed_value(@field, @proposed_value, @category_lookup)}
      </p>

      <p :if={@rule_group && @rule} class="mt-1 text-[10px] text-white/38 truncate">
        {@rule_group.name} / {@rule.name}
      </p>

      <p
        :for={supporting_change <- @supporting_changes}
        class="mt-1 text-[10px] leading-relaxed text-white/38"
      >
        {change_status_label(supporting_change.status)}: {supporting_change.rule_group.name} / {supporting_change.rule.name}
      </p>
    </div>
    """
  end

  @doc """
  Renders a small badge for the proposed-change status.
  """
  attr :status, :atom, required: true

  def change_status_badge(assigns) do
    ~H"""
    <span class={["au-badge text-[9px]", change_status_badge_class(@status)]}>
      {change_status_label(@status)}
    </span>
    """
  end

  @doc """
  Renders a small scope badge used within preview cells.
  """
  attr :scope_type, :atom, required: true

  def scope_badge(assigns) do
    ~H"""
    <.badge variant={scope_badge_variant(@scope_type)}>
      {scope_label(@scope_type)}
    </.badge>
    """
  end

  defp change_status_badge_class(:proposed), do: "au-badge-good"
  defp change_status_badge_class(:protected), do: "au-badge-warn"
  defp change_status_badge_class(:skipped_claimed), do: ""
  defp change_status_badge_class(:invalid), do: "au-badge-bad"
  defp change_status_badge_class(_), do: ""

  defp change_status_label(:proposed), do: dgettext("rules", "change_status_proposed")
  defp change_status_label(:protected), do: dgettext("rules", "change_status_protected")
  defp change_status_label(:skipped_claimed), do: dgettext("rules", "change_status_skipped")
  defp change_status_label(:invalid), do: dgettext("rules", "change_status_invalid")
  defp change_status_label(_status), do: ""

  defp field_label(:category), do: dgettext("rules", "target_field_category")
  defp field_label(:tags), do: dgettext("rules", "target_field_tags")
  defp field_label(:investment_type), do: dgettext("rules", "target_field_investment_type")
  defp field_label(:notes), do: dgettext("rules", "target_field_notes")
  defp field_label(field) when is_atom(field), do: Atom.to_string(field)
  defp field_label(field) when is_binary(field), do: field
  defp field_label(_), do: ""

  defp format_proposed_value(:category, value, category_lookup) when is_binary(value) do
    Map.get(category_lookup, value, value)
  end

  defp format_proposed_value(:tags, values, _category_lookup) when is_list(values),
    do: Enum.join(values, ", ")

  defp format_proposed_value(_field, nil, _category_lookup), do: "—"
  defp format_proposed_value(_field, value, _category_lookup) when is_binary(value), do: value
  defp format_proposed_value(_field, value, _category_lookup), do: inspect(value)

  defp format_posting_amount(nil), do: "—"

  defp format_posting_amount(%Decimal{} = amount) do
    Decimal.to_string(amount, :normal)
  end

  defp format_posting_amount(amount) when is_binary(amount), do: amount
  defp format_posting_amount(amount), do: inspect(amount)

  defp account_name(posting) do
    posting
    |> Map.get(:account)
    |> case do
      nil -> nil
      account -> Map.get(account, :name)
    end
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

  defp summarize_proposed_changes(proposed_changes) do
    {field_order, grouped_changes} =
      Enum.reduce(proposed_changes, {[], %{}}, fn change, {field_order, grouped_changes} ->
        field = change.field

        if Map.has_key?(grouped_changes, field) do
          {field_order, Map.update!(grouped_changes, field, &(&1 ++ [change]))}
        else
          {field_order ++ [field], Map.put(grouped_changes, field, [change])}
        end
      end)

    Enum.map(field_order, fn field ->
      changes = Map.fetch!(grouped_changes, field)
      primary_change = select_primary_change(changes)

      %{
        field: field,
        primary_change: primary_change,
        supporting_changes: Enum.reject(changes, &(&1 == primary_change))
      }
    end)
  end

  defp select_primary_change(changes) do
    Enum.reduce(changes, nil, fn change, best_change ->
      cond do
        is_nil(best_change) ->
          change

        change_priority(change) > change_priority(best_change) ->
          change

        true ->
          best_change
      end
    end)
  end

  defp change_priority(%{status: :proposed}), do: 4
  defp change_priority(%{status: :protected}), do: 3
  defp change_priority(%{status: :invalid}), do: 2
  defp change_priority(%{status: :skipped_claimed}), do: 1
  defp change_priority(_change), do: 0

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false
end
