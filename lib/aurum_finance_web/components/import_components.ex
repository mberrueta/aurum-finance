defmodule AurumFinanceWeb.ImportComponents do
  @moduledoc """
  Components for the Import page.

  Components:
    - scope_panel/1        — entity/account selection controls
    - upload_placeholder/1 — account-required placeholder before upload is available
    - upload_panel/1       — upload form with drag-and-drop target
    - import_expected_format/1 — top-level expected source format guidance
    - import_tips/1        — checks and tips guidance
    - import_history_row/1 — row for one persisted import run
    - import_step/1        — a single step pill in the pipeline indicator
    - preview_row/1        — a row in the import preview table
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.CoreComponents
  import AurumFinanceWeb.UiComponents

  alias AurumFinance.Ingestion.ImportedFile

  attr :entity_form, :any, required: true
  attr :account_form, :any, required: true
  attr :entities, :list, required: true
  attr :current_entity, :map, default: nil
  attr :accounts, :list, required: true
  attr :current_account, :map, default: nil

  def scope_panel(assigns) do
    ~H"""
    <.section_panel
      title={dgettext("import", "section_scope")}
      badge={dgettext("import", "badge_scope")}
    >
      <div class="grid gap-4 md:grid-cols-2">
        <.form for={@entity_form} id="import-entity-selector" phx-change="select_entity">
          <.input
            field={@entity_form[:entity_id]}
            id="import-entity-id"
            type="select"
            label={dgettext("import", "label_entity")}
            options={entity_options(@entities)}
            prompt={dgettext("import", "option_select_entity")}
          />
        </.form>

        <.form for={@account_form} id="import-account-selector" phx-change="select_account">
          <.input
            field={@account_form[:account_id]}
            id="import-account-id"
            type="select"
            label={dgettext("import", "label_account")}
            options={account_options(@accounts)}
            prompt={dgettext("import", "option_select_account")}
            disabled={@accounts == []}
          />
        </.form>
      </div>

      <div class="mt-4 grid gap-3 md:grid-cols-2">
        <div class="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
          <p class="text-[11px] uppercase tracking-[0.18em] text-white/38">
            {dgettext("import", "label_entity_scope")}
          </p>
          <p class="mt-2 text-sm font-semibold text-white/90">
            {entity_scope_text(@current_entity)}
          </p>
          <p class="mt-2 text-[13px] leading-relaxed text-white/60">
            {dgettext("import", "hint_entity_scope")}
          </p>
        </div>

        <div class="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
          <p class="text-[11px] uppercase tracking-[0.18em] text-white/38">
            {dgettext("import", "label_target_account")}
          </p>
          <p class="mt-2 text-sm font-semibold text-white/90">
            {target_account_text(@current_account)}
          </p>
          <p class="mt-2 text-[13px] leading-relaxed text-white/60">
            {target_account_hint(@current_account, @accounts)}
          </p>
        </div>
      </div>
    </.section_panel>
    """
  end

  attr :accounts, :list, required: true

  def upload_placeholder(assigns) do
    ~H"""
    <.section_panel
      title={dgettext("import", "section_upload")}
      badge={dgettext("import", "badge_scope")}
    >
      <div id="import-upload-placeholder" class="space-y-4">
        <.info_callout title={dgettext("import", "upload_placeholder_title")} tone={:info}>
          <p>{dgettext("import", "upload_placeholder_body")}</p>
        </.info_callout>

        <div class="rounded-2xl border border-white/10 bg-white/[0.03] p-4">
          <p class="text-[11px] uppercase tracking-[0.18em] text-white/38">
            {dgettext("import", "label_target_account")}
          </p>
          <p class="mt-2 text-sm font-semibold text-white/90">
            {target_account_text(nil)}
          </p>
          <p class="mt-2 text-[13px] leading-relaxed text-white/60">
            {target_account_hint(nil, @accounts)}
          </p>
        </div>
      </div>
    </.section_panel>
    """
  end

  attr :current_account, :map, default: nil
  attr :uploads, :map, required: true
  attr :upload_error, :string, default: nil

  def upload_panel(assigns) do
    assigns =
      assigns
      |> assign(:entries, assigns.uploads.source_file.entries)
      |> assign(:selected_entry, List.first(assigns.uploads.source_file.entries))

    ~H"""
    <.section_panel
      title={dgettext("import", "section_upload")}
      badge={dgettext("import", "badge_csv_only")}
    >
      <.form
        for={%{}}
        id="import-upload-form"
        phx-change="validate_upload"
        phx-submit="upload"
        class="space-y-4"
      >
        <div
          id="import-upload-dropzone"
          phx-drop-target={@uploads.source_file.ref}
          class={[
            "rounded-[28px] border border-dashed px-5 py-8 transition",
            is_nil(@current_account) && "border-white/10 bg-white/[0.02]",
            !is_nil(@current_account) && "border-white/20 bg-white/[0.04] hover:border-white/35",
            !is_nil(@selected_entry) && "border-emerald-300/40 bg-emerald-400/[0.08]"
          ]}
        >
          <div class="mx-auto max-w-md text-center">
            <div class={[
              "mx-auto flex size-12 items-center justify-center rounded-2xl border border-white/10 bg-white/[0.05]",
              !is_nil(@selected_entry) && "border-emerald-300/30 bg-emerald-300/10"
            ]}>
              <.icon
                name={if(is_nil(@selected_entry), do: "hero-arrow-up-tray", else: "hero-check")}
                class={[
                  "size-6 text-white/80",
                  !is_nil(@selected_entry) && "text-emerald-100"
                ]}
              />
            </div>

            <h3 id="import-upload-title" class="mt-4 text-base font-semibold text-white/92">
              {upload_title(@selected_entry)}
            </h3>

            <p id="import-upload-description" class="mt-2 text-[13px] leading-relaxed text-white/60">
              {upload_description(@current_account, @selected_entry)}
            </p>

            <div
              id="import-upload-selected"
              class={[
                "mt-4 inline-flex max-w-full items-center gap-2 rounded-full border border-emerald-300/25 bg-emerald-300/10 px-3 py-1 text-xs text-emerald-100",
                is_nil(@selected_entry) && "hidden"
              ]}
            >
              <.icon name="hero-document-text" class="size-4 shrink-0" />
              <span id="import-upload-selected-name" class="truncate">
                {if(@selected_entry, do: @selected_entry.client_name)}
              </span>
            </div>

            <label
              id="import-upload-choose-label"
              for={@uploads.source_file.ref}
              class={[
                "mt-5 inline-flex cursor-pointer items-center gap-2 rounded-xl px-4 py-2 text-sm font-medium transition",
                is_nil(@current_account) && "bg-white/[0.06] text-white/40",
                !is_nil(@current_account) && "bg-white/10 text-white/88 hover:bg-white/15",
                !is_nil(@selected_entry) &&
                  "bg-emerald-300/15 text-emerald-100 hover:bg-emerald-300/20"
              ]}
            >
              <.icon name="hero-document-arrow-up" class="size-4" />
              <span id="import-upload-choose-label-text">{upload_button_label(@selected_entry)}</span>
            </label>

            <.live_file_input upload={@uploads.source_file} class="sr-only" />
          </div>
        </div>

        <div :if={@entries != []} id="import-upload-entries" class="space-y-2">
          <div
            :for={entry <- @entries}
            class="flex items-center justify-between gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3"
          >
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-white/90">{entry.client_name}</p>
              <p class="mt-1 text-xs text-white/55">{dgettext("import", "upload_ready_label")}</p>
            </div>
            <.badge variant={:purple}>{entry.client_type || ".csv"}</.badge>
          </div>
        </div>

        <p :if={@upload_error} id="import-upload-error" class="text-sm text-rose-300">
          {@upload_error}
        </p>

        <div class="flex flex-wrap items-center justify-between gap-3">
          <p class="text-[12px] leading-relaxed text-white/48">
            {dgettext("import", "upload_footer")}
          </p>

          <button
            id="import-submit-btn"
            type="submit"
            class="au-btn au-btn-primary"
            disabled={@entries == []}
          >
            {dgettext("import", "btn_queue_import")}
          </button>
        </div>
      </.form>
    </.section_panel>
    """
  end

  attr :selected_format, :string, default: nil
  attr :selected_filename, :string, default: nil

  def import_expected_format(assigns) do
    ~H"""
    <div id="import-guidance">
      <.au_card>
        <:header>
          <span>{dgettext("import", "section_expected_format")}</span>
          <.badge variant={:purple}>{dgettext("import", "badge_simple_flow")}</.badge>
        </:header>

        <div id="import-expectations">
          <.info_callout title={dgettext("import", "callout_expected_title")} tone={:info}>
            <p>{expected_format_body(@selected_format, @selected_filename)}</p>
            <ul class="mt-2 list-disc space-y-1 pl-5">
              <li>{dgettext("import", "callout_expected_item_1")}</li>
              <li>{dgettext("import", "callout_expected_item_2")}</li>
              <li>{dgettext("import", "callout_expected_item_3")}</li>
            </ul>
          </.info_callout>
        </div>
      </.au_card>
    </div>
    """
  end

  attr :selected_format, :string, default: nil

  def import_tips(assigns) do
    ~H"""
    <div id="import-tips">
      <.au_card>
        <:header>
          <span>{dgettext("import", "section_expectations")}</span>
        </:header>

        <div class="grid grid-cols-1 gap-[10px] lg:grid-cols-2">
          <div>
            <.info_callout title={dgettext("import", "callout_checks_title")} tone={:warn}>
              <p>{format_warning_body(@selected_format)}</p>
              <ul class="mt-2 list-disc space-y-1 pl-5">
                <li>{dgettext("import", "callout_checks_item_1")}</li>
                <li>{dgettext("import", "callout_checks_item_2")}</li>
              </ul>
            </.info_callout>
          </div>

          <div>
            <.info_callout title={dgettext("import", "callout_tips_title")} tone={:tip}>
              <p>{tips_body(@selected_format)}</p>
              <ul class="mt-2 list-disc space-y-1 pl-5">
                <li>{dgettext("import", "callout_tips_item_1")}</li>
                <li>{dgettext("import", "callout_tips_item_2")}</li>
              </ul>
            </.info_callout>
          </div>
        </div>
      </.au_card>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :imported_file, ImportedFile, required: true

  def import_history_row(assigns) do
    ~H"""
    <article
      id={@id}
      data-status={@imported_file.status}
      class="rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-4 transition hover:border-white/20 hover:bg-white/[0.05]"
    >
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div class="min-w-0 space-y-3">
          <div class="flex flex-wrap items-center gap-2">
            <p class="truncate text-sm font-semibold text-white/92">{@imported_file.filename}</p>
            <.badge variant={import_status_variant(@imported_file.status)}>
              {import_status_label(@imported_file.status)}
            </.badge>
          </div>

          <dl class="grid gap-3 text-sm text-white/68 sm:grid-cols-2 xl:grid-cols-4">
            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("import", "label_uploaded_at")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">
                {format_timestamp(@imported_file.inserted_at)}
              </dd>
            </div>

            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("import", "label_rows")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">{row_summary(@imported_file)}</dd>
            </div>

            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("import", "label_format")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">
                {String.upcase(to_string(@imported_file.format))}
              </dd>
            </div>

            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("import", "label_size")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">
                {format_byte_size(@imported_file.byte_size)}
              </dd>
            </div>
          </dl>

          <p :if={@imported_file.error_message} class="text-sm leading-relaxed text-rose-300">
            {@imported_file.error_message}
          </p>
        </div>

        <div class="shrink-0 rounded-2xl border border-white/10 bg-black/20 px-4 py-3 text-right">
          <p class="text-[11px] uppercase tracking-[0.16em] text-white/38">
            {dgettext("import", "label_progress")}
          </p>
          <p class="mt-2 text-sm font-semibold text-white/90">
            {progress_copy(@imported_file.status)}
          </p>
          <.link
            id={"view-import-#{@imported_file.id}"}
            navigate={import_details_path(@imported_file)}
            class="mt-3 inline-flex items-center gap-2 text-xs font-medium text-sky-200 transition hover:text-sky-100"
          >
            <span>{dgettext("import", "btn_view_details")}</span>
            <.icon name="hero-arrow-right" class="size-4" />
          </.link>
        </div>
      </div>
    </article>
    """
  end

  @doc """
  Purpose: renders one pipeline step chip in the import wizard.

  Use: pass the step `label`, its `index`, and current `active_step`.

  Example:

      <.import_step label="Preview" index={4} active_step={4} />
  """
  attr :label, :string, required: true
  attr :index, :integer, required: true
  attr :active_step, :integer, required: true

  def import_step(assigns) do
    ~H"""
    <div class={["au-step", @index == @active_step && "active"]}>
      {@index + 1}. {@label}
    </div>
    """
  end

  @doc """
  Purpose: renders one row in the import preview table.

  Use: pass a preview row map with normalized transaction fields and status.

  Example:

      <.preview_row
        row=%{
          date: "2026-03-01",
          description: "UBER *TRIP",
          amount: -47.90,
          currency: "BRL",
          status: :ready,
          hint: "Rule matched: Transport"
        }
      />
  """
  attr :row, :map, required: true

  def preview_row(assigns) do
    ~H"""
    <tr>
      <td class="au-mono whitespace-nowrap">{@row.date}</td>
      <td class="text-white/92">{@row.description}</td>
      <td class="au-mono whitespace-nowrap">{format_money(@row.amount, @row.currency)}</td>
      <td class="au-mono">{@row.currency}</td>
      <td>
        <.badge variant={status_variant(@row.status)}>
          {status_label(@row.status)}
        </.badge>
      </td>
      <td class="text-white/68">{@row.hint}</td>
    </tr>
    """
  end

  defp status_variant(:ready), do: :good
  defp status_variant(:duplicate), do: :warn
  defp status_variant(:error), do: :bad
  defp status_variant(_), do: :default

  defp import_status_variant(:pending), do: :purple
  defp import_status_variant(:processing), do: :warn
  defp import_status_variant(:complete), do: :good
  defp import_status_variant(:failed), do: :bad
  defp import_status_variant(_), do: :default

  defp import_status_label(:pending), do: dgettext("import", "status_pending")
  defp import_status_label(:processing), do: dgettext("import", "status_processing")
  defp import_status_label(:complete), do: dgettext("import", "status_complete")
  defp import_status_label(:failed), do: dgettext("import", "status_failed")
  defp import_status_label(status), do: to_string(status)

  defp status_label(:ready), do: dgettext("import", "status_ready")
  defp status_label(:duplicate), do: dgettext("import", "status_duplicate")
  defp status_label(:error), do: dgettext("import", "status_error")
  defp status_label(s), do: to_string(s)

  defp entity_options(entities), do: Enum.map(entities, &{&1.name, &1.id})

  defp account_options(accounts) do
    Enum.map(accounts, fn account ->
      {"#{account.name} · #{account.currency_code}", account.id}
    end)
  end

  defp entity_scope_text(nil), do: dgettext("import", "value_no_entity_selected")
  defp entity_scope_text(entity), do: entity.name

  defp target_account_text(nil), do: dgettext("import", "value_no_account_selected")
  defp target_account_text(account), do: "#{account.name} · #{account.currency_code}"

  defp target_account_hint(nil, []), do: dgettext("import", "hint_target_account_empty")
  defp target_account_hint(nil, _accounts), do: dgettext("import", "hint_target_account_required")

  defp target_account_hint(account, _accounts),
    do: dgettext("import", "hint_target_account_selected", account: account.name)

  defp upload_hint(nil), do: dgettext("import", "upload_hint_account_required")

  defp upload_hint(account),
    do: dgettext("import", "upload_hint_account_selected", account: account.name)

  defp upload_title(nil), do: dgettext("import", "upload_title")
  defp upload_title(_selected_entry), do: dgettext("import", "upload_title_selected")

  defp upload_description(current_account, nil), do: upload_hint(current_account)

  defp upload_description(_current_account, selected_entry) do
    dgettext("import", "upload_hint_selected_file", file: selected_entry.client_name)
  end

  defp upload_button_label(nil), do: dgettext("import", "btn_choose_file")
  defp upload_button_label(_selected_entry), do: dgettext("import", "btn_change_file")

  defp row_summary(%ImportedFile{row_count: nil}), do: dgettext("import", "value_rows_pending")

  defp row_summary(%ImportedFile{} = imported_file) do
    dgettext("import", "value_rows_summary",
      rows: imported_file.row_count,
      ready: imported_file.imported_row_count,
      duplicates: imported_file.skipped_row_count,
      invalid: imported_file.invalid_row_count
    )
  end

  defp progress_copy(:pending), do: dgettext("import", "progress_pending")
  defp progress_copy(:processing), do: dgettext("import", "progress_processing")
  defp progress_copy(:complete), do: dgettext("import", "progress_complete")
  defp progress_copy(:failed), do: dgettext("import", "progress_failed")
  defp progress_copy(_status), do: dgettext("import", "progress_pending")

  defp import_details_path(%ImportedFile{id: imported_file_id, account_id: account_id}) do
    "/import/accounts/#{account_id}/files/#{imported_file_id}"
  end

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(%DateTime{} = timestamp) do
    Calendar.strftime(timestamp, "%Y-%m-%d %H:%M")
  end

  defp format_byte_size(nil), do: "—"
  defp format_byte_size(byte_size), do: "#{byte_size} B"

  defp expected_format_body(nil, _filename),
    do: dgettext("import", "callout_expected_body_default")

  defp expected_format_body(selected_format, selected_filename) do
    dgettext("import", "callout_expected_body_selected",
      format: selected_format,
      file: selected_filename
    )
  end

  defp format_warning_body(nil), do: dgettext("import", "callout_checks_body_default")
  defp format_warning_body("CSV"), do: dgettext("import", "callout_checks_body_csv")

  defp format_warning_body(selected_format) do
    dgettext("import", "callout_checks_body_other", format: selected_format)
  end

  defp tips_body(nil), do: dgettext("import", "callout_tips_body_default")
  defp tips_body("CSV"), do: dgettext("import", "callout_tips_body_csv")

  defp tips_body(selected_format) do
    dgettext("import", "callout_tips_body_other", format: selected_format)
  end
end
