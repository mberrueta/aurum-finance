defmodule AurumFinanceWeb.ReconciliationComponents do
  @moduledoc """
  Components for the reconciliation workflow.
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.CoreComponents
  import AurumFinanceWeb.UiComponents

  alias AurumFinance.Helpers
  alias AurumFinance.Reconciliation.ReconciliationSession

  attr :entities, :list, required: true
  attr :current_entity, :map, default: nil

  def entity_scope_selector(assigns) do
    ~H"""
    <.form
      for={%{}}
      as={:entity_scope}
      id="reconciliation-entity-selector"
      phx-change="select_entity"
    >
      <label
        for="reconciliation-entity-id"
        class="text-xs uppercase tracking-[0.18em] text-white/45"
      >
        {dgettext("reconciliation", "label_entity")}
      </label>
      <select
        id="reconciliation-entity-id"
        name="entity_id"
        class="mt-2 min-w-52 rounded-xl border border-white/10 bg-[#0b1020] px-3 py-2 text-sm text-white/90 outline-none transition focus:border-white/30"
      >
        <option value="">{dgettext("reconciliation", "option_select_entity")}</option>
        <option
          :for={entity <- @entities}
          value={entity.id}
          selected={!is_nil(@current_entity) and @current_entity.id == entity.id}
        >
          {entity.name}
        </option>
      </select>
    </.form>
    """
  end

  attr :accounts, :list, required: true
  attr :selected_account_id, :string, default: nil

  def account_filter(assigns) do
    ~H"""
    <.form
      for={%{}}
      as={:session_filter}
      id="reconciliation-account-filter"
      phx-change="filter_sessions"
    >
      <label
        for="reconciliation-account-id"
        class="text-xs uppercase tracking-[0.18em] text-white/45"
      >
        {dgettext("reconciliation", "label_account_filter")}
      </label>
      <select
        id="reconciliation-account-id"
        name="account_id"
        class="mt-2 min-w-52 rounded-xl border border-white/10 bg-[#0b1020] px-3 py-2 text-sm text-white/90 outline-none transition focus:border-white/30"
      >
        <option value="">{dgettext("reconciliation", "option_all_accounts")}</option>
        <option
          :for={account <- @accounts}
          value={account.id}
          selected={@selected_account_id == account.id}
        >
          {account.name}
        </option>
      </select>
    </.form>
    """
  end

  attr :id, :string, required: true
  attr :session, ReconciliationSession, required: true
  attr :selected?, :boolean, default: false
  attr :href, :string, required: true

  def session_item(assigns) do
    ~H"""
    <.link
      id={@id}
      navigate={@href}
      class={[
        "block rounded-2xl border px-4 py-4 transition",
        @selected? && "border-white/30 bg-white/[0.08]",
        !@selected? && "border-white/10 bg-white/[0.03] hover:border-white/20 hover:bg-white/[0.05]"
      ]}
    >
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0 space-y-2">
          <div class="flex flex-wrap items-center gap-2">
            <p class="truncate text-sm font-semibold text-white/92">{@session.account.name}</p>
            <.badge variant={session_badge_variant(@session)}>
              {session_status_label(@session)}
            </.badge>
          </div>

          <dl class="grid gap-2 text-sm text-white/66 sm:grid-cols-2">
            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("reconciliation", "label_statement_date")}
              </dt>
              <dd class="mt-1 text-white/86">{format_date(@session.statement_date)}</dd>
            </div>
            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("reconciliation", "label_statement_balance")}
              </dt>
              <dd class="mt-1 text-white/86">
                {format_money(@session.statement_balance, @session.account.currency_code)}
              </dd>
            </div>
            <div :if={!is_nil(@session.completed_at)} class="sm:col-span-2">
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("reconciliation", "label_completed_at")}
              </dt>
              <dd class="mt-1 text-white/86">{format_datetime(@session.completed_at)}</dd>
            </div>
          </dl>
        </div>

        <span class="text-xs text-white/38">
          <.icon name="hero-chevron-right" class="size-4" />
        </span>
      </div>
    </.link>
    """
  end

  attr :id, :string, required: true
  attr :posting, :map, required: true
  attr :currency_code, :string, required: true
  attr :session_completed?, :boolean, default: false
  attr :selected?, :boolean, default: false
  attr :inspected?, :boolean, default: false

  def posting_row(assigns) do
    ~H"""
    <tr id={@id} class={["border-t border-white/6 transition", @inspected? && "bg-sky-400/10"]}>
      <td class="whitespace-nowrap px-4 py-3">
        <button
          :if={selectable_posting?(@posting, @session_completed?)}
          id={"toggle-posting-#{@posting.id}"}
          type="button"
          class={[
            "inline-flex size-6 items-center justify-center rounded-lg border transition",
            @selected? && "border-emerald-400 bg-emerald-400/15 text-emerald-200",
            !@selected? && "border-white/15 bg-white/[0.03] text-white/50 hover:border-white/25"
          ]}
          phx-click="toggle_posting_selection"
          phx-value-id={@posting.id}
          aria-pressed={to_string(@selected?)}
        >
          <.icon :if={@selected?} name="hero-check" class="size-4" />
        </button>
        <span
          :if={!selectable_posting?(@posting, @session_completed?)}
          class="text-xs text-white/28"
        >
          -
        </span>
      </td>
      <td class="whitespace-nowrap px-4 py-3 text-sm text-white/72">
        {format_date(@posting.transaction_date)}
      </td>
      <td class="px-4 py-3">
        <div class="space-y-1">
          <p class="text-sm font-medium text-white/92">{@posting.transaction_description}</p>
          <p :if={present?(@posting.reason)} class="text-xs text-white/48">
            {@posting.reason}
          </p>
        </div>
      </td>
      <td class="whitespace-nowrap px-4 py-3 text-sm font-medium text-white/92">
        {format_money(@posting.amount, @currency_code)}
      </td>
      <td class="whitespace-nowrap px-4 py-3">
        <.badge variant={posting_status_variant(@posting.reconciliation_status)}>
          {posting_status_label(@posting.reconciliation_status)}
        </.badge>
      </td>
      <td class="whitespace-nowrap px-4 py-3">
        <div class="flex flex-wrap items-center gap-2">
          <button
            id={"inspect-posting-#{@posting.id}"}
            type="button"
            class={[
              "au-btn",
              @inspected? && "border-sky-300/40 bg-sky-300/10 text-sky-100"
            ]}
            phx-click="inspect_posting_matches"
            phx-value-id={@posting.id}
          >
            {dgettext("reconciliation", "btn_inspect_matches")}
          </button>
          <button
            :if={unclearable_posting?(@posting, @session_completed?)}
            id={"unclear-posting-#{@posting.id}"}
            type="button"
            class="au-btn"
            phx-click="unclear_posting"
            phx-value-id={@posting.id}
          >
            {dgettext("reconciliation", "btn_unclear")}
          </button>
          <span
            :if={!unclearable_posting?(@posting, @session_completed?) and !@inspected?}
            class="text-xs text-white/28"
          >
            -
          </span>
        </div>
      </td>
    </tr>
    """
  end

  attr :posting, :map, default: nil
  attr :match_candidates, :list, default: []
  attr :currency_code, :string, required: true
  attr :accept_enabled?, :boolean, default: false

  def posting_match_panel(assigns) do
    ~H"""
    <div class="rounded-[24px] border border-sky-300/15 bg-[#071422] p-4 sm:p-5">
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div class="space-y-2">
          <p class="text-sm font-semibold text-white/92">
            {dgettext("reconciliation", "section_match_candidates")}
          </p>
          <p class="text-sm text-white/62">
            {dgettext("reconciliation", "match_candidates_intro")}
          </p>
          <p class="text-xs uppercase tracking-[0.16em] text-white/42">
            {dgettext("reconciliation", "match_candidates_read_only")}
          </p>
        </div>

        <button
          :if={!is_nil(@posting)}
          id="clear-posting-match-inspection-btn"
          type="button"
          class="au-btn"
          phx-click="clear_posting_match_inspection"
        >
          {dgettext("reconciliation", "btn_close_match_candidates")}
        </button>
      </div>

      <div :if={is_nil(@posting)} id="reconciliation-match-candidates-empty" class="mt-4">
        <.empty_state text={dgettext("reconciliation", "empty_match_candidates_idle")} />
      </div>

      <div :if={!is_nil(@posting)} class="mt-4 space-y-4">
        <div
          id="selected-posting-match-summary"
          class="rounded-2xl border border-white/10 bg-white/[0.03] p-4"
        >
          <p class="text-[11px] uppercase tracking-[0.16em] text-white/40">
            {dgettext("reconciliation", "label_selected_posting")}
          </p>
          <div class="mt-3 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
            <div class="space-y-1">
              <p class="text-sm font-semibold text-white/92">{@posting.transaction_description}</p>
              <p class="text-sm text-white/64">{format_date(@posting.transaction_date)}</p>
            </div>
            <div class="text-sm font-medium text-white/88">
              {format_money(@posting.amount, @currency_code)}
            </div>
          </div>
        </div>

        <div :if={@match_candidates == []} id="reconciliation-match-candidates-none">
          <.empty_state text={dgettext("reconciliation", "empty_match_candidates_none")} />
        </div>

        <div
          :if={@match_candidates != []}
          id="reconciliation-match-candidates-list"
          class="space-y-3"
        >
          <div
            :for={candidate <- @match_candidates}
            id={"match-candidate-#{candidate.imported_row_id}"}
            class="rounded-2xl border border-white/10 bg-white/[0.03] p-4"
          >
            <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div class="space-y-2">
                <div class="flex flex-wrap items-center gap-2">
                  <.badge variant={match_band_variant(candidate.match_band)}>
                    {match_band_label(candidate.match_band)}
                  </.badge>
                  <span class="text-xs text-white/50">
                    {format_match_score(candidate.score)}
                  </span>
                </div>
                <p class="text-sm font-semibold text-white/92">
                  {candidate.imported_row.description || "-"}
                </p>
                <div class="flex flex-wrap gap-x-4 gap-y-1 text-sm text-white/64">
                  <span>{format_date(candidate.imported_row.posted_on)}</span>
                  <span>{format_money(candidate.imported_row.amount, @currency_code)}</span>
                  <span>
                    {dgettext("reconciliation", "label_match_file_id",
                      file_id: candidate.imported_file_id
                    )}
                  </span>
                </div>
              </div>

              <div class="flex flex-wrap gap-2">
                <.badge :for={reason <- candidate.reasons} variant={:default}>
                  {match_reason_label(reason)}
                </.badge>
                <button
                  :if={@accept_enabled?}
                  id={"accept-match-candidate-#{candidate.imported_row_id}"}
                  type="button"
                  class="au-btn au-btn-primary"
                  phx-click="accept_match_candidate"
                  phx-value-posting_id={@posting.id}
                  phx-value-imported_row_id={candidate.imported_row_id}
                >
                  {dgettext("reconciliation", "btn_accept_match_candidate")}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :caption, :string, default: nil
  attr :tone, :atom, default: :default, values: [:default, :good, :warn, :purple]

  def summary_tile(assigns) do
    ~H"""
    <div class={["rounded-2xl border px-4 py-4", summary_tile_class(@tone)]}>
      <p class="text-[11px] uppercase tracking-[0.16em] text-white/42">{@title}</p>
      <p class="mt-3 text-xl font-semibold text-white/94">{@value}</p>
      <p :if={@caption} class="mt-2 text-sm text-white/62">{@caption}</p>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :current_entity, :map, default: nil
  attr :institution_accounts, :list, default: []

  def session_form(assigns) do
    ~H"""
    <div :if={is_nil(@current_entity)}>
      <.empty_state text={dgettext("reconciliation", "empty_form_requires_entity")} />
    </div>

    <div :if={!is_nil(@current_entity) and @institution_accounts == []}>
      <.empty_state text={dgettext("reconciliation", "empty_form_requires_account")} />
    </div>

    <.form
      :if={!is_nil(@current_entity) and @institution_accounts != []}
      for={@form}
      id="reconciliation-create-form"
      phx-change="validate_session"
      phx-submit="create_session"
      class="space-y-5"
    >
      <div class="space-y-2">
        <p class="text-xs uppercase tracking-[0.18em] text-white/40">
          {dgettext("reconciliation", "label_entity")}
        </p>
        <p class="rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-sm text-white/88">
          {@current_entity.name}
        </p>
      </div>

      <.input
        field={@form[:account_id]}
        type="select"
        label={dgettext("reconciliation", "label_account")}
        options={account_options(@institution_accounts)}
        prompt={dgettext("reconciliation", "option_select_account")}
        class="w-full rounded-2xl border border-white/10 bg-[#0b1020] px-3 py-3 text-sm text-white/90"
      />

      <.input
        field={@form[:statement_date]}
        type="date"
        label={dgettext("reconciliation", "label_statement_date")}
        class="w-full rounded-2xl border border-white/10 bg-[#0b1020] px-3 py-3 text-sm text-white/90"
      />

      <div class="flex flex-wrap gap-2">
        <button
          id="statement-date-last-month-btn"
          type="button"
          class="au-btn"
          phx-click="set_statement_date_preset"
          phx-value-preset="last_month"
        >
          {dgettext("reconciliation", "btn_statement_date_last_month")}
        </button>
        <button
          id="statement-date-last-year-btn"
          type="button"
          class="au-btn"
          phx-click="set_statement_date_preset"
          phx-value-preset="last_year"
        >
          {dgettext("reconciliation", "btn_statement_date_last_year")}
        </button>
      </div>

      <.input
        field={@form[:statement_balance]}
        type="text"
        label={dgettext("reconciliation", "label_statement_balance")}
        class="w-full rounded-2xl border border-white/10 bg-[#0b1020] px-3 py-3 text-sm text-white/90"
      />

      <div class="rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-4">
        <p class="text-[11px] uppercase tracking-[0.18em] text-white/40">
          {dgettext("reconciliation", "panel_session_flow_title")}
        </p>
        <ul class="mt-3 list-disc space-y-2 pl-5 text-sm leading-relaxed text-white/70">
          <li>{dgettext("reconciliation", "panel_session_flow_item_1")}</li>
          <li>{dgettext("reconciliation", "panel_session_flow_item_2")}</li>
          <li>{dgettext("reconciliation", "panel_session_flow_item_3")}</li>
        </ul>
      </div>

      <button
        id="save-reconciliation-session-btn"
        type="submit"
        class="au-btn au-btn-primary w-full justify-center"
      >
        {dgettext("reconciliation", "btn_create_session")}
      </button>
    </.form>
    """
  end

  def detail_panel_title(nil), do: dgettext("reconciliation", "section_detail")

  def detail_panel_title(%ReconciliationSession{} = session) do
    dgettext("reconciliation", "section_detail_for_account", account: session.account.name)
  end

  def detail_panel_badge(nil), do: dgettext("reconciliation", "badge_detail_idle")

  def detail_panel_badge(%ReconciliationSession{} = session) do
    session_status_label(session)
  end

  def detail_panel_badge_variant(nil), do: :default

  def detail_panel_badge_variant(%ReconciliationSession{} = session),
    do: session_badge_variant(session)

  def difference_caption(true), do: dgettext("reconciliation", "difference_balanced")
  def difference_caption(false), do: dgettext("reconciliation", "difference_unbalanced")

  def session_status_label(%ReconciliationSession{completed_at: nil}),
    do: dgettext("reconciliation", "status_in_progress")

  def session_status_label(%ReconciliationSession{}),
    do: dgettext("reconciliation", "status_completed")

  def select_all_button_label(selected_posting_ids, postings) do
    clearable_count =
      postings
      |> Enum.count(&(&1.reconciliation_status == :unreconciled))

    cond do
      clearable_count == 0 ->
        dgettext("reconciliation", "btn_select_all_disabled")

      MapSet.size(selected_posting_ids) == clearable_count ->
        dgettext("reconciliation", "btn_clear_selection")

      true ->
        dgettext("reconciliation", "btn_select_all")
    end
  end

  def complete_confirmation(true),
    do: dgettext("reconciliation", "confirm_complete_balanced")

  def complete_confirmation(false),
    do: dgettext("reconciliation", "confirm_complete_unbalanced")

  def format_date(%Date{} = date), do: Calendar.strftime(date, "%b %d, %Y")
  def format_date(_date), do: "-"

  def format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%b %d, %Y %H:%M")
  def format_datetime(_datetime), do: "-"

  defp account_options(accounts), do: Enum.map(accounts, &{&1.name, &1.id})

  defp session_badge_variant(%ReconciliationSession{completed_at: nil}), do: :warn
  defp session_badge_variant(%ReconciliationSession{}), do: :good

  defp posting_status_variant(:unreconciled), do: :bad
  defp posting_status_variant(:cleared), do: :purple
  defp posting_status_variant(:reconciled), do: :good
  defp posting_status_variant(_status), do: :default

  defp match_band_variant(:exact_match), do: :good
  defp match_band_variant(:near_match), do: :purple
  defp match_band_variant(:weak_match), do: :warn
  defp match_band_variant(:below_threshold), do: :default

  defp posting_status_label(:unreconciled), do: dgettext("reconciliation", "status_unreconciled")
  defp posting_status_label(:cleared), do: dgettext("reconciliation", "status_cleared")
  defp posting_status_label(:reconciled), do: dgettext("reconciliation", "status_reconciled")
  defp posting_status_label(status), do: Helpers.humanize_token(status)

  defp match_band_label(:exact_match), do: dgettext("reconciliation", "match_band_exact")
  defp match_band_label(:near_match), do: dgettext("reconciliation", "match_band_near")
  defp match_band_label(:weak_match), do: dgettext("reconciliation", "match_band_weak")

  defp match_band_label(:below_threshold),
    do: dgettext("reconciliation", "match_band_below_threshold")

  defp match_reason_label(:exact_amount),
    do: dgettext("reconciliation", "match_reason_exact_amount")

  defp match_reason_label(:close_amount),
    do: dgettext("reconciliation", "match_reason_close_amount")

  defp match_reason_label(:same_day), do: dgettext("reconciliation", "match_reason_same_day")
  defp match_reason_label(:near_date), do: dgettext("reconciliation", "match_reason_near_date")

  defp match_reason_label(:description_similarity),
    do: dgettext("reconciliation", "match_reason_description_similarity")

  defp match_reason_label(reason), do: Helpers.humanize_token(reason)

  defp format_match_score(score) do
    percentage = (score * 100) |> Float.round(0) |> trunc()
    dgettext("reconciliation", "label_match_score", score: percentage)
  end

  defp summary_tile_class(:good), do: "border-emerald-500/25 bg-emerald-500/10"
  defp summary_tile_class(:warn), do: "border-amber-400/25 bg-amber-400/10"
  defp summary_tile_class(:purple), do: "border-violet-400/20 bg-violet-400/10"
  defp summary_tile_class(:default), do: "border-white/10 bg-white/[0.03]"

  defp selectable_posting?(posting, false), do: posting.reconciliation_status == :unreconciled
  defp selectable_posting?(_posting, true), do: false

  defp unclearable_posting?(posting, false), do: posting.reconciliation_status == :cleared
  defp unclearable_posting?(_posting, true), do: false

  defp present?(value), do: !Helpers.blank?(value)
end
