defmodule AurumFinanceWeb.TransactionsComponents do
  @moduledoc """
  Components for the Transactions page.
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinance.Gettext

  import AurumFinanceWeb.BadgeComponent, only: [account_type_label: 1]
  import AurumFinanceWeb.CoreComponents, only: [icon: 1, input: 1]
  import AurumFinanceWeb.UiComponents
  alias AurumFinanceWeb.FilterQuery

  attr :id, :string, required: true
  attr :transaction, :map, required: true
  attr :current_entity, :map, default: nil
  attr :filters, :map, default: %{}
  attr :expanded_transaction_id, :any, default: nil
  attr :classification_record, :map, default: nil
  attr :classification_forms, :map, default: %{}
  attr :classification_history, :list, default: []
  attr :category_accounts, :list, default: []
  attr :provenance_lookup, :map, default: %{rule_groups: %{}, rules: %{}}
  attr :apply_feedback, :map, default: nil
  attr :applying?, :boolean, default: false
  attr :editor_open, :boolean, default: false

  def tx_row(assigns) do
    ~H"""
    <tbody id={@id} class="border-t border-white/6 first:border-t-0">
      <tr
        id={"#{@id}-summary"}
        phx-click="toggle_transaction"
        phx-value-id={@transaction.id}
        class="au-table-row-interactive"
      >
        <td class="au-mono whitespace-nowrap text-white/72">
          {Date.to_iso8601(@transaction.date)}
        </td>
        <td class="text-white/92">
          <div>{@transaction.description}</div>
          <div :if={@transaction.correlation_id} class="mt-1 text-xs text-white/45 au-mono">
            {dgettext("transactions", "label_correlation_id")}: {@transaction.correlation_id}
          </div>
        </td>
        <td class="text-white/78">
          <.link
            :if={@classification_record && @classification_record.category_account}
            id={"#{@id}-filter-category"}
            patch={
              filter_patch_path(@current_entity, @filters, %{
                category_account_id: @classification_record.category_account.id
              })
            }
            onclick="event.stopPropagation()"
            class="inline-flex max-w-full items-center gap-2 rounded-xl border border-indigo-300/24 bg-indigo-300/12 px-2.5 py-1.5 text-[12px] font-semibold text-indigo-50 shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]"
          >
            <.icon name="hero-folder-mini" class="size-4 shrink-0 text-indigo-100/86" />
            <span class="truncate">{@classification_record.category_account.name}</span>
          </.link>
          <span
            :if={is_nil(@classification_record) || is_nil(@classification_record.category_account)}
            class="text-white/38"
          >
            {dgettext("transactions", "classification_unclassified")}
          </span>
        </td>
        <td class="text-white/78">
          <div
            :if={@classification_record && present_tags?(@classification_record.tags)}
            class="flex max-w-56 flex-wrap gap-1"
          >
            <.link
              :for={{tag, index} <- Enum.with_index(@classification_record.tags)}
              id={"#{@id}-filter-tag-#{index}"}
              patch={filter_patch_path(@current_entity, @filters, %{search_text: tag})}
              onclick="event.stopPropagation()"
              class="rounded-full border border-white/12 bg-white/[0.04] px-2 py-1 text-[11px] font-medium text-white/72"
            >
              {tag}
            </.link>
          </div>
          <span
            :if={is_nil(@classification_record) || not present_tags?(@classification_record.tags)}
            class="text-white/38"
          >
            {dgettext("transactions", "classification_unclassified")}
          </span>
        </td>
        <td>
          <.link
            id={"#{@id}-filter-source"}
            patch={
              filter_patch_path(@current_entity, @filters, %{
                source_type: source_filter_value(@transaction.source_type)
              })
            }
            onclick="event.stopPropagation()"
          >
            <.badge variant={source_badge_variant(@transaction.source_type)}>
              {source_badge_label(@transaction.source_type)}
            </.badge>
          </.link>
        </td>
        <td class="au-mono text-white/72">
          {length(@transaction.postings)}
        </td>
        <td>
          <.badge :if={@transaction.voided_at} variant={:bad}>
            {dgettext("transactions", "badge_voided")}
          </.badge>
        </td>
      </tr>
      <tr :if={@expanded_transaction_id == @transaction.id} id={"#{@id}-detail"}>
        <td colspan="7" class="px-4 pb-4">
          <.tx_posting_detail
            transaction={@transaction}
            classification_record={@classification_record}
            classification_forms={@classification_forms}
            classification_history={@classification_history}
            category_accounts={@category_accounts}
            provenance_lookup={@provenance_lookup}
            apply_feedback={@apply_feedback}
            applying?={@applying?}
            editor_open={@editor_open}
          />
        </td>
      </tr>
    </tbody>
    """
  end

  attr :transaction, :map, required: true
  attr :classification_record, :map, default: nil
  attr :classification_forms, :map, default: %{}
  attr :classification_history, :list, default: []
  attr :category_accounts, :list, default: []
  attr :provenance_lookup, :map, default: %{rule_groups: %{}, rules: %{}}
  attr :apply_feedback, :map, default: nil
  attr :applying?, :boolean, default: false
  attr :editor_open, :boolean, default: false

  def tx_posting_detail(assigns) do
    ~H"""
    <div class="mt-2 grid gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
      <div class="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
        <div class="flex flex-wrap items-center gap-2">
          <h4 class="text-sm font-semibold text-white/90">
            {dgettext("transactions", "posting_detail_title")}
          </h4>
          <.badge variant={source_badge_variant(@transaction.source_type)}>
            {source_badge_label(@transaction.source_type)}
          </.badge>
          <.badge :if={@transaction.voided_at} variant={:bad}>
            {dgettext("transactions", "badge_voided")}
          </.badge>
        </div>

        <div class="mt-3 grid gap-3 text-sm text-white/68 sm:grid-cols-3">
          <div>
            <div class="text-[11px] uppercase tracking-[0.16em] text-white/38">
              {dgettext("transactions", "col_date")}
            </div>
            <div class="mt-1 text-white/88 au-mono">{Date.to_iso8601(@transaction.date)}</div>
          </div>
          <div>
            <div class="text-[11px] uppercase tracking-[0.16em] text-white/38">
              {dgettext("transactions", "col_description")}
            </div>
            <div class="mt-1 text-white/88">{@transaction.description}</div>
          </div>
          <div :if={@transaction.voided_at}>
            <div class="text-[11px] uppercase tracking-[0.16em] text-white/38">
              {dgettext("transactions", "label_voided_at")}
            </div>
            <div class="mt-1 text-white/88 au-mono">
              {DateTime.to_iso8601(@transaction.voided_at)}
            </div>
          </div>
        </div>

        <.classification_feedback :if={@apply_feedback} feedback={@apply_feedback} />

        <.classification_summary
          transaction={@transaction}
          classification_record={@classification_record}
          provenance_lookup={@provenance_lookup}
        />

        <div class="mt-4 overflow-x-auto">
          <table class="au-table">
            <thead>
              <tr>
                <th>{dgettext("transactions", "col_account")}</th>
                <th>{dgettext("transactions", "col_account_type")}</th>
                <th>{dgettext("transactions", "col_amount")}</th>
                <th>{dgettext("transactions", "col_currency")}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={posting <- @transaction.postings} id={"posting-#{posting.id}"}>
                <td class="text-white/88">{posting.account.name}</td>
                <td class="text-white/72">{account_type_label(posting.account.account_type)}</td>
                <td class={["au-mono whitespace-nowrap", amount_class(posting.amount)]}>
                  {Decimal.to_string(posting.amount)}
                </td>
                <td class="au-mono text-white/72">{posting.account.currency_code}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <.classification_history
          history={@classification_history}
          category_accounts={@category_accounts}
          provenance_lookup={@provenance_lookup}
        />
      </div>

      <div
        id={"transaction-#{@transaction.id}-classification"}
        class="rounded-2xl border border-white/10 bg-[#0c152b] p-4 shadow-[0_14px_40px_rgba(4,11,25,0.24)]"
      >
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h4 class="text-sm font-semibold text-white/92">
              {dgettext("transactions", "classification_editor_title")}
            </h4>
            <p class="mt-1 text-xs text-white/55">
              {dgettext("transactions", "classification_editor_subtitle")}
            </p>
          </div>
        </div>

        <div class="mt-4 flex flex-wrap gap-2">
          <button
            id={"transaction-#{@transaction.id}-edit-classification"}
            type="button"
            phx-click="toggle_classification_editor"
            phx-value-id={@transaction.id}
            class={[
              "inline-flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-medium transition",
              if(@editor_open,
                do: "border-white/18 bg-white/[0.08] text-white/92",
                else:
                  "border-sky-300/30 bg-sky-300/12 text-sky-100 hover:border-sky-200/60 hover:bg-sky-300/18"
              )
            ]}
          >
            <.icon name="hero-pencil-square" class="size-4" />
            <span>
              {if(@editor_open,
                do: dgettext("transactions", "classification_close_editor"),
                else: dgettext("transactions", "classification_edit")
              )}
            </span>
          </button>

          <button
            id={"transaction-#{@transaction.id}-apply-rules"}
            type="button"
            phx-click="apply_transaction_rules"
            phx-value-id={@transaction.id}
            phx-disable-with={dgettext("transactions", "classification_apply_rules_loading")}
            disabled={@applying?}
            class={[
              "inline-flex items-center gap-2 rounded-xl border px-3 py-2 text-sm font-medium transition",
              if(@applying?,
                do: "cursor-wait border-emerald-300/25 bg-emerald-300/10 text-emerald-100/70",
                else:
                  "border-emerald-300/35 bg-emerald-300/12 text-emerald-100 hover:border-emerald-200/60 hover:bg-emerald-300/18"
              )
            ]}
          >
            <.icon :if={not @applying?} name="hero-sparkles" class="size-4" />
            <.icon :if={@applying?} name="hero-arrow-path" class="size-4 animate-spin" />
            <span>
              {if(@applying?,
                do: dgettext("transactions", "classification_apply_rules_loading"),
                else: dgettext("transactions", "classification_apply_rules")
              )}
            </span>
          </button>
        </div>

        <div :if={not @editor_open} class="mt-4 rounded-2xl border border-white/8 bg-white/[0.03] p-4">
          <div class="text-sm text-white/72">
            {dgettext("transactions", "classification_editor_closed")}
          </div>
        </div>

        <div :if={@editor_open} class="mt-4 grid gap-3">
          <.classification_editor_field
            :for={field <- classification_fields()}
            transaction={@transaction}
            field={field}
            classification_record={@classification_record}
            classification_form={Map.get(@classification_forms, field)}
            category_accounts={@category_accounts}
            provenance_lookup={@provenance_lookup}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :feedback, :map, required: true

  def classification_feedback(assigns) do
    ~H"""
    <div class={[
      "mt-4 rounded-2xl border px-3 py-3 text-sm",
      feedback_container_class(@feedback.tone)
    ]}>
      <div class="flex flex-wrap items-center gap-2">
        <.badge variant={feedback_badge_variant(@feedback.tone)}>
          {feedback_label(@feedback.kind)}
        </.badge>
        <span class="text-white/84">{feedback_message(@feedback)}</span>
      </div>
    </div>
    """
  end

  attr :transaction, :map, required: true
  attr :classification_record, :map, default: nil
  attr :provenance_lookup, :map, default: %{rule_groups: %{}, rules: %{}}

  def classification_summary(assigns) do
    ~H"""
    <section
      id={"transaction-#{@transaction.id}-classification-summary"}
      class="mt-4 rounded-2xl border border-white/10 bg-[#091121] p-4"
    >
      <div class="flex flex-wrap items-center justify-between gap-2">
        <div>
          <h4 class="text-sm font-semibold text-white/92">
            {dgettext("transactions", "classification_panel_title")}
          </h4>
          <p class="mt-1 text-xs text-white/55">
            {dgettext("transactions", "classification_panel_subtitle")}
          </p>
        </div>
      </div>

      <div class="mt-4 grid gap-3 sm:grid-cols-2">
        <.classification_summary_item
          :for={field <- classification_fields()}
          field={field}
          classification_record={@classification_record}
          provenance_lookup={@provenance_lookup}
        />
      </div>
    </section>
    """
  end

  attr :field, :atom, required: true
  attr :classification_record, :map, default: nil
  attr :provenance_lookup, :map, default: %{rule_groups: %{}, rules: %{}}

  def classification_summary_item(assigns) do
    presentation =
      field_presentation(assigns.classification_record, assigns.field, assigns.provenance_lookup)

    assigns =
      assigns
      |> assign(:presentation, presentation)
      |> assign(:field_dom_id, "classification-summary-#{assigns.field}")

    ~H"""
    <div
      id={@field_dom_id}
      class="rounded-2xl border border-white/8 bg-white/[0.03] p-3"
    >
      <div class="flex flex-wrap items-start justify-between gap-2">
        <div class="min-w-0">
          <div class="text-[11px] font-semibold uppercase tracking-[0.18em] text-white/42">
            {field_label(@field)}
          </div>
          <div class="mt-2 text-sm text-white/92">{field_value_markup(@presentation)}</div>
        </div>

        <div class="flex flex-wrap items-center justify-end gap-2">
          <.badge variant={state_badge_variant(@presentation.state)}>
            {state_badge_label(@presentation)}
          </.badge>
          <span
            :if={@presentation.locked?}
            class="inline-flex items-center gap-1 rounded-full border border-amber-300/30 bg-amber-300/10 px-2 py-1 text-[11px] font-medium text-amber-100"
          >
            <.icon name="hero-lock-closed" class="size-3.5" />
            {dgettext("transactions", "classification_locked")}
          </span>
        </div>
      </div>

      <div :if={@presentation.provenance} class="mt-3 flex flex-wrap items-center gap-2 text-xs">
        <.badge
          :if={show_provenance_source_badge?(@presentation.provenance)}
          variant={provenance_badge_variant(@presentation.provenance.source)}
        >
          {provenance_label(@presentation.provenance.source)}
        </.badge>
        <.badge :if={@presentation.provenance.scope_type} variant={:purple}>
          {scope_label(@presentation.provenance.scope_type)}
        </.badge>
        <span
          :if={@presentation.provenance.group_name}
          class="rounded-full border border-white/10 bg-white/[0.04] px-2 py-1 text-white/72"
        >
          {@presentation.provenance.group_name}
        </span>
        <span
          :if={@presentation.provenance.rule_name}
          class="rounded-full border border-white/10 bg-white/[0.04] px-2 py-1 text-white/72"
        >
          {@presentation.provenance.rule_name}
        </span>
      </div>
    </div>
    """
  end

  attr :transaction, :map, required: true
  attr :field, :atom, required: true
  attr :classification_record, :map, default: nil
  attr :classification_form, :map, default: nil
  attr :category_accounts, :list, default: []
  attr :provenance_lookup, :map, default: %{rule_groups: %{}, rules: %{}}

  def classification_editor_field(assigns) do
    presentation =
      field_presentation(assigns.classification_record, assigns.field, assigns.provenance_lookup)

    assigns =
      assigns
      |> assign(:presentation, presentation)
      |> assign(:field_dom_id, "transaction-#{assigns.transaction.id}-field-#{assigns.field}")

    ~H"""
    <section
      id={@field_dom_id}
      class="rounded-2xl border border-white/8 bg-white/[0.03] p-3 shadow-[inset_0_1px_0_rgba(255,255,255,0.04)]"
    >
      <div class="flex flex-col gap-3">
        <div class="flex flex-wrap items-center justify-between gap-2">
          <div class="flex flex-wrap items-center gap-2">
            <h5 class="text-sm font-semibold text-white/92">{field_label(@field)}</h5>
            <.badge variant={state_badge_variant(@presentation.state)}>
              {state_badge_label(@presentation)}
            </.badge>
          </div>

          <button
            :if={@presentation.locked?}
            id={"#{@field_dom_id}-clear-override"}
            type="button"
            phx-click="clear_manual_override"
            phx-value-transaction_id={@transaction.id}
            phx-value-field={@field}
            class="inline-flex items-center gap-2 rounded-xl border border-white/12 bg-white/[0.04] px-3 py-2 text-sm font-medium text-white/78 transition hover:border-white/22 hover:bg-white/[0.08]"
          >
            <.icon name="hero-lock-open" class="size-4" />
            {dgettext("transactions", "classification_clear_override")}
          </button>
        </div>

        <div class="text-sm text-white/72">{field_value_markup(@presentation)}</div>

        <.form
          :if={@classification_form}
          for={@classification_form}
          id={"#{@field_dom_id}-manual-form"}
          phx-submit="set_manual_field"
          class="grid gap-3"
        >
          <input type="hidden" name="transaction_id" value={@transaction.id} />
          <input type="hidden" name="field" value={@field} />

          <div>
            <.manual_input
              field={@field}
              form={@classification_form}
              category_accounts={@category_accounts}
              input_id={"#{@field_dom_id}-value"}
            />
          </div>

          <button
            id={"#{@field_dom_id}-manual-submit"}
            type="submit"
            class="inline-flex items-center justify-center rounded-xl border border-sky-300/30 bg-sky-300/12 px-3 py-2 text-sm font-medium text-sky-100 transition hover:border-sky-200/60 hover:bg-sky-300/18"
          >
            {dgettext("transactions", "classification_set_manual")}
          </button>
        </.form>
      </div>
    </section>
    """
  end

  attr :field, :atom, required: true
  attr :form, :map, required: true
  attr :category_accounts, :list, default: []
  attr :input_id, :string, required: true

  def manual_input(%{field: :category} = assigns) do
    ~H"""
    <.input
      id={@input_id}
      field={@form[:value]}
      type="select"
      label={dgettext("transactions", "classification_manual_value")}
      options={category_account_options(@category_accounts)}
    />
    """
  end

  def manual_input(%{field: :notes} = assigns) do
    ~H"""
    <.input
      id={@input_id}
      field={@form[:value]}
      type="textarea"
      label={dgettext("transactions", "classification_manual_value")}
      rows="3"
    />
    """
  end

  def manual_input(assigns) do
    ~H"""
    <.input
      id={@input_id}
      field={@form[:value]}
      type="text"
      label={dgettext("transactions", "classification_manual_value")}
    />
    """
  end

  attr :history, :list, default: []
  attr :category_accounts, :list, default: []
  attr :provenance_lookup, :map, default: %{rule_groups: %{}, rules: %{}}

  def classification_history(assigns) do
    assigns = assign(assigns, :accounts_by_id, Map.new(assigns.category_accounts, &{&1.id, &1}))

    ~H"""
    <div class="mt-4">
      <h5 class="text-[11px] font-semibold uppercase tracking-[0.16em] text-white/38">
        {dgettext("transactions", "classification_history_title")}
      </h5>

      <p :if={@history == []} class="mt-2 text-xs text-white/45">
        {dgettext("transactions", "classification_history_empty")}
      </p>

      <ol :if={@history != []} class="mt-2 space-y-2">
        <li
          :for={event <- @history}
          class="flex flex-wrap items-start gap-x-3 gap-y-1 rounded-xl border border-white/6 bg-white/[0.03] px-3 py-2 text-xs"
        >
          <span class="au-mono text-white/38 shrink-0">
            {Calendar.strftime(event.occurred_at, "%Y-%m-%d %H:%M")}
          </span>
          <.badge variant={history_action_badge_variant(event.action)}>
            {history_action_label(event.action)}
          </.badge>
          <span class="font-medium text-white/72">
            {field_label(history_event_field(event))}
          </span>
          <span class="text-white/45">
            {history_value_display(event, :old_value, @accounts_by_id)}
            <span class="mx-1 text-white/28">→</span>
            {history_value_display(event, :new_value, @accounts_by_id)}
          </span>
          <span :if={history_rule_source(event, @provenance_lookup)} class="text-white/38 italic">
            {history_rule_source(event, @provenance_lookup)}
          </span>
        </li>
      </ol>
    </div>
    """
  end

  defp history_event_field(event) do
    case Map.get(event.metadata || %{}, "field") do
      nil -> :notes
      f -> String.to_existing_atom(f)
    end
  end

  defp history_action_label("rule_applied"),
    do: dgettext("transactions", "classification_history_action_rule_applied")

  defp history_action_label("manual_override"),
    do: dgettext("transactions", "classification_history_action_manual_override")

  defp history_action_label("override_cleared"),
    do: dgettext("transactions", "classification_history_action_override_cleared")

  defp history_action_label(action), do: action

  defp history_action_badge_variant("rule_applied"), do: :good
  defp history_action_badge_variant("manual_override"), do: :warn
  defp history_action_badge_variant("override_cleared"), do: :default
  defp history_action_badge_variant(_), do: :default

  defp history_value_display(event, key, accounts_by_id) do
    field = history_event_field(event)
    raw = Map.get(event.metadata || %{}, Atom.to_string(key))
    history_format_value(field, raw, accounts_by_id)
  end

  defp history_format_value(:tags, nil, _),
    do: dgettext("transactions", "classification_history_empty_value")

  defp history_format_value(:tags, json, _) do
    case Jason.decode(json) do
      {:ok, []} -> dgettext("transactions", "classification_history_empty_value")
      {:ok, tags} -> Enum.join(tags, ", ")
      _ -> json
    end
  end

  defp history_format_value(:category, nil, _),
    do: dgettext("transactions", "classification_history_empty_value")

  defp history_format_value(:category, uuid, accounts_by_id) do
    case Map.get(accounts_by_id, uuid) do
      nil -> uuid
      account -> account.name
    end
  end

  defp history_format_value(_field, nil, _),
    do: dgettext("transactions", "classification_history_empty_value")

  defp history_format_value(_field, value, _), do: value

  defp history_rule_source(event, provenance_lookup) do
    meta = event.metadata || %{}

    case {event.action, Map.get(meta, "rule_group_id"), Map.get(meta, "rule_id")} do
      {"rule_applied", group_id, rule_id} when is_binary(group_id) ->
        group_name = provenance_group_name(Map.get(provenance_lookup.rule_groups, group_id))
        rule_name = provenance_rule_name(Map.get(provenance_lookup.rules, rule_id))
        "#{group_name} / #{rule_name}"

      _ ->
        nil
    end
  end

  defp amount_class(%Decimal{} = amount) do
    if Decimal.negative?(amount), do: "au-debit", else: "au-credit"
  end

  defp present_tags?(tags) when is_list(tags), do: tags != []
  defp present_tags?(_tags), do: false

  defp classification_fields, do: [:category, :tags, :investment_type, :notes]

  defp field_presentation(record, field, provenance_lookup) do
    value = field_value(record, field)
    locked? = field_locked?(record, field)
    provenance = field_provenance(record, field, provenance_lookup)

    %{
      state: field_state(value, provenance, locked?),
      value: value,
      display_value: format_field_value(field, value),
      locked?: locked?,
      provenance: provenance
    }
  end

  defp field_state(nil, _provenance, _locked?), do: :unclassified
  defp field_state([], _provenance, _locked?), do: :unclassified
  defp field_state(_value, _provenance, true), do: :manual
  defp field_state(_value, %{source: :manual}, _locked?), do: :manual
  defp field_state(_value, %{source: :rule}, _locked?), do: :rule
  defp field_state(_value, _provenance, _locked?), do: :manual

  defp field_value(nil, _field), do: nil
  defp field_value(record, :category), do: record.category_account
  defp field_value(record, :tags), do: record.tags || []
  defp field_value(record, :investment_type), do: record.investment_type
  defp field_value(record, :notes), do: record.notes

  defp field_locked?(nil, _field), do: false
  defp field_locked?(record, :category), do: record.category_manually_overridden
  defp field_locked?(record, :tags), do: record.tags_manually_overridden
  defp field_locked?(record, :investment_type), do: record.investment_type_manually_overridden
  defp field_locked?(record, :notes), do: record.notes_manually_overridden

  defp field_provenance(nil, _field, _provenance_lookup), do: nil

  defp field_provenance(record, field, provenance_lookup) do
    provenance_map =
      case field do
        :category -> record.category_classified_by
        :tags -> record.tags_classified_by
        :investment_type -> record.investment_type_classified_by
        :notes -> record.notes_classified_by
      end

    build_provenance(provenance_map, provenance_lookup)
  end

  defp build_provenance(nil, _provenance_lookup), do: nil

  defp build_provenance(%{"source" => "user"} = provenance, _provenance_lookup) do
    %{
      source: :manual,
      scope_type: nil,
      group_name: nil,
      rule_name: nil,
      timestamp: Map.get(provenance, "classified_at")
    }
  end

  defp build_provenance(
         %{"source" => "rule", "rule_group_id" => group_id, "rule_id" => rule_id} = provenance,
         provenance_lookup
       ) do
    rule_group = Map.get(provenance_lookup.rule_groups, group_id)
    rule = Map.get(provenance_lookup.rules, rule_id)

    %{
      source: :rule,
      scope_type: rule_group && rule_group.scope_type,
      group_name: provenance_group_name(rule_group),
      rule_name: provenance_rule_name(rule),
      timestamp: Map.get(provenance, "classified_at")
    }
  end

  defp build_provenance(_provenance, _provenance_lookup), do: nil

  defp provenance_group_name(nil), do: dgettext("transactions", "classification_deleted_group")
  defp provenance_group_name(rule_group), do: rule_group.name

  defp provenance_rule_name(nil), do: dgettext("transactions", "classification_deleted_rule")
  defp provenance_rule_name(rule), do: rule.name

  defp format_field_value(:category, nil), do: nil
  defp format_field_value(:category, category_account), do: category_account.name
  defp format_field_value(:tags, tags) when is_list(tags), do: tags
  defp format_field_value(_field, value), do: value

  defp field_value_markup(%{state: :unclassified}) do
    assigns = %{}

    ~H"""
    <span class="text-white/45">{dgettext("transactions", "classification_unclassified")}</span>
    """
  end

  defp field_value_markup(%{display_value: tags}) when is_list(tags) do
    assigns = %{tags: tags}

    ~H"""
    <div class="flex flex-wrap gap-2">
      <span
        :for={tag <- @tags}
        class="rounded-full border border-sky-300/25 bg-sky-300/10 px-2 py-1 text-xs font-medium text-sky-100"
      >
        {tag}
      </span>
    </div>
    """
  end

  defp field_value_markup(%{display_value: value}) do
    assigns = %{value: value}

    ~H"""
    <span class="whitespace-pre-wrap text-white/92">{@value}</span>
    """
  end

  defp field_label(:category), do: dgettext("transactions", "classification_field_category")
  defp field_label(:tags), do: dgettext("transactions", "classification_field_tags")

  defp field_label(:investment_type) do
    dgettext("transactions", "classification_field_investment_type")
  end

  defp field_label(:notes), do: dgettext("transactions", "classification_field_notes")

  defp state_badge_variant(:rule), do: :good
  defp state_badge_variant(:manual), do: :warn
  defp state_badge_variant(:unclassified), do: :default

  defp state_badge_label(%{state: :rule}),
    do: dgettext("transactions", "classification_state_rule")

  defp state_badge_label(%{state: :manual}),
    do: dgettext("transactions", "classification_state_manual")

  defp state_badge_label(%{state: :unclassified}) do
    dgettext("transactions", "classification_state_unclassified")
  end

  defp provenance_badge_variant(:rule), do: :good
  defp provenance_badge_variant(:manual), do: :warn

  defp show_provenance_source_badge?(%{source: :rule}), do: true
  defp show_provenance_source_badge?(_provenance), do: false

  defp provenance_label(:rule), do: dgettext("transactions", "classification_provenance_rule")
  defp provenance_label(:manual), do: dgettext("transactions", "classification_provenance_manual")

  defp scope_label(:global), do: dgettext("transactions", "classification_scope_global")
  defp scope_label(:entity), do: dgettext("transactions", "classification_scope_entity")
  defp scope_label(:account), do: dgettext("transactions", "classification_scope_account")

  defp feedback_container_class(:good), do: "border-emerald-300/20 bg-emerald-300/10"
  defp feedback_container_class(:warn), do: "border-amber-300/20 bg-amber-300/10"

  defp feedback_badge_variant(:good), do: :good
  defp feedback_badge_variant(:warn), do: :warn

  defp feedback_label(:applied), do: dgettext("transactions", "classification_feedback_applied")
  defp feedback_label(:no_match), do: dgettext("transactions", "classification_feedback_no_match")

  defp feedback_label(:protected),
    do: dgettext("transactions", "classification_feedback_protected")

  defp feedback_label(:no_change),
    do: dgettext("transactions", "classification_feedback_no_change")

  defp feedback_message(%{kind: :applied, fields_applied: count}) do
    dgettext("transactions", "classification_feedback_applied_message", count: count)
  end

  defp feedback_message(%{kind: :protected, fields_skipped_manual: count}) do
    dgettext("transactions", "classification_feedback_protected_message", count: count)
  end

  defp feedback_message(%{kind: :no_match}) do
    dgettext("transactions", "classification_feedback_no_match_message")
  end

  defp feedback_message(%{kind: :no_change}) do
    dgettext("transactions", "classification_feedback_no_change_message")
  end

  defp category_account_options(accounts) do
    [
      {dgettext("transactions", "classification_category_prompt"), ""}
      | Enum.map(accounts, &{&1.name, &1.id})
    ]
  end

  defp source_badge_variant(:manual), do: :purple
  defp source_badge_variant(:import), do: :good
  defp source_badge_variant(:system), do: :warn

  defp source_badge_label(:manual), do: dgettext("transactions", "badge_manual")
  defp source_badge_label(:import), do: dgettext("transactions", "badge_import")
  defp source_badge_label(:system), do: dgettext("transactions", "badge_system")

  defp source_filter_value(:manual), do: "manual"
  defp source_filter_value(:import), do: "import"
  defp source_filter_value(:system), do: "system"
  defp source_filter_value(_value), do: ""

  defp filter_patch_path(current_entity, filters, changes) do
    filters = Map.merge(filters, changes)

    FilterQuery.build_path("/transactions",
      entity: current_entity && current_entity.id,
      account: Map.get(filters, :account_id),
      category: Map.get(filters, :category_account_id),
      search: FilterQuery.skip_default(Map.get(filters, :search_text, ""), ""),
      date: FilterQuery.skip_default(Map.get(filters, :date_preset, "all"), "all"),
      source: FilterQuery.skip_default(Map.get(filters, :source_type, ""), ""),
      voided: Map.get(filters, :include_voided) && "true"
    )
  end
end
