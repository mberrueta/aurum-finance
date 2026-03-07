defmodule AurumFinanceWeb.AccountsComponents do
  @moduledoc """
  Components for account management flows.
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.BadgeComponent,
    only: [
      account_type_badge: 1,
      management_group_badge: 1,
      management_group_variant: 1
    ]

  import AurumFinanceWeb.CoreComponents
  import AurumFinanceWeb.UiComponents

  alias AurumFinance.Currency
  alias AurumFinance.Ledger.Account

  attr :entities, :list, required: true
  attr :current_entity, :map, default: nil

  def entity_selector(assigns) do
    ~H"""
    <.form for={%{}} as={:entity_scope} id="accounts-entity-selector" phx-change="select_entity">
      <label for="accounts-entity-id" class="text-xs uppercase tracking-[0.18em] text-white/45">
        {dgettext("accounts", "label_entity")}
      </label>
      <select
        id="accounts-entity-id"
        name="entity_id"
        class="mt-2 min-w-52 rounded-xl border border-white/10 bg-[#0b1020] px-3 py-2 text-sm text-white/90 outline-none transition focus:border-white/30"
      >
        <option value="">{dgettext("accounts", "option_select_entity")}</option>
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

  attr :active_tab, :atom, required: true
  attr :counts, :map, required: true

  def management_tabs(assigns) do
    ~H"""
    <div class="grid gap-2 md:grid-cols-3">
      <button
        :for={tab <- [:institution, :category, :system_managed]}
        id={"accounts-tab-#{tab}"}
        type="button"
        phx-click="switch_tab"
        phx-value-tab={tab}
        class={management_tab_classes(@active_tab == tab)}
      >
        <span class="text-left">
          <span class="block text-sm font-semibold text-white/92">{management_group_label(tab)}</span>
          <span class="mt-1 block text-xs text-white/55">{management_group_hint(tab)}</span>
        </span>
        <.badge variant={management_group_variant(tab)}>{Map.get(@counts, tab, 0)}</.badge>
      </button>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :account, :map, required: true
  attr :editing_account_id, :any, default: nil

  def account_row(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "rounded-2xl border px-4 py-4 transition",
        @editing_account_id == @account.id && "border-white/30 bg-white/[0.08]",
        @editing_account_id != @account.id &&
          "border-white/10 bg-white/[0.03] hover:border-white/20 hover:bg-white/[0.05]"
      ]}
    >
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div class="min-w-0 space-y-3">
          <div class="flex flex-wrap items-center gap-2">
            <p class="text-sm font-semibold text-white/92">{@account.name}</p>
            <.management_group_badge group={@account.management_group} />
            <.account_type_badge type={@account.account_type} />
            <.badge :if={@account.archived_at} variant={:bad}>
              {dgettext("accounts", "status_archived")}
            </.badge>
          </div>

          <dl class="grid gap-3 text-sm text-white/68 sm:grid-cols-2 xl:grid-cols-4">
            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("accounts", "label_currency")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">{@account.currency_code}</dd>
            </div>

            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("accounts", "label_operational_subtype")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">
                {operational_subtype_label(@account.operational_subtype)}
              </dd>
            </div>

            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("accounts", "label_institution")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">
                {@account.institution_name || dgettext("accounts", "value_not_applicable")}
              </dd>
            </div>

            <div>
              <dt class="text-[11px] uppercase tracking-[0.16em] text-white/38">
                {dgettext("accounts", "label_normal_balance")}
              </dt>
              <dd class="mt-1 font-medium text-white/88">
                {normal_balance_label(@account.account_type)}
              </dd>
            </div>
          </dl>

          <p :if={present?(@account.notes)} class="text-sm leading-relaxed text-white/62">
            {@account.notes}
          </p>
        </div>

        <div class="flex shrink-0 flex-wrap gap-2">
          <button
            id={"edit-account-#{@account.id}"}
            type="button"
            class="au-btn"
            phx-click="edit_account"
            phx-value-id={@account.id}
          >
            {dgettext("accounts", "btn_edit")}
          </button>
          <button
            :if={is_nil(@account.archived_at)}
            id={"archive-account-#{@account.id}"}
            type="button"
            class="au-btn"
            phx-click="archive_account"
            phx-value-id={@account.id}
          >
            {dgettext("accounts", "btn_archive")}
          </button>
          <button
            :if={!is_nil(@account.archived_at)}
            id={"unarchive-account-#{@account.id}"}
            type="button"
            class="au-btn"
            phx-click="unarchive_account"
            phx-value-id={@account.id}
          >
            {dgettext("accounts", "btn_unarchive")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :form, :any, required: true
  attr :current_entity, :map, default: nil
  attr :entities, :list, default: []
  attr :editing_account, :any, default: nil
  attr :selected_management_group, :atom, required: true

  def account_form(assigns) do
    assigns =
      assign(assigns,
        editing?: !is_nil(assigns.editing_account),
        derived_account_type:
          derived_account_type(assigns.form, assigns.selected_management_group)
      )

    ~H"""
    <div :if={is_nil(@current_entity)}>
      <.empty_state text={dgettext("accounts", "empty_form_requires_entity")} />
    </div>

    <.form
      :if={!is_nil(@current_entity)}
      for={@form}
      id="account-form"
      phx-change="validate"
      phx-submit="save"
      class="space-y-5"
    >
      <input type="hidden" name="account[entity_id]" value={@current_entity.id} />
      <input type="hidden" name="account[management_group]" value={@selected_management_group} />
      <input
        :if={@editing? && @selected_management_group == :institution}
        type="hidden"
        name="account[operational_subtype]"
        value={@form[:operational_subtype].value}
      />
      <input
        :if={@editing? && @selected_management_group == :category}
        type="hidden"
        name="account[account_type]"
        value={@form[:account_type].value}
      />
      <input
        :if={@editing? && @selected_management_group == :system_managed}
        type="hidden"
        name="account[account_type]"
        value="equity"
      />

      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <.info_label
            for={@form[:management_group].id}
            text={dgettext("accounts", "label_management_group")}
            tooltip={dgettext("accounts", "tooltip_field_management_group")}
          />
          <.input
            field={@form[:management_group]}
            type="select"
            options={management_group_options()}
            disabled
          />
        </div>
        <.input field={@form[:name]} type="text" label={dgettext("accounts", "label_name")} />
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <.info_label
            for={@form[:currency_code].id}
            text={dgettext("accounts", "label_currency")}
            tooltip={dgettext("accounts", "tooltip_field_currency")}
          />
          <.input
            field={@form[:currency_code]}
            type="select"
            options={currency_options()}
            readonly={@editing?}
            disabled={@editing?}
          />
        </div>

        <div :if={@selected_management_group == :institution}>
          <.info_label
            for={@form[:operational_subtype].id}
            text={dgettext("accounts", "label_operational_subtype")}
            tooltip={dgettext("accounts", "tooltip_field_operational_subtype")}
          />
          <.input
            field={@form[:operational_subtype]}
            type="select"
            options={institution_operational_subtype_options()}
            disabled={@editing?}
          />
        </div>

        <div :if={@selected_management_group == :category}>
          <.info_label
            for={@form[:account_type].id}
            text={dgettext("accounts", "label_category_type")}
            tooltip={dgettext("accounts", "tooltip_field_category_type")}
          />
          <.input
            field={@form[:account_type]}
            type="select"
            options={category_account_type_options()}
            disabled={@editing?}
          />
        </div>

        <div :if={@selected_management_group == :system_managed}>
          <label
            for="account-system-managed-type"
            class="block text-sm font-medium leading-6 text-white/88"
          >
            {dgettext("accounts", "label_account_type")}
          </label>
          <input
            id="account-system-managed-type"
            type="text"
            value={account_type_label(:equity)}
            readonly
            disabled
            class="mt-2 block w-full rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 text-sm text-white/78"
          />
        </div>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <.info_label
            for="account-derived-account-type"
            text={dgettext("accounts", "label_account_type")}
            tooltip={dgettext("accounts", "tooltip_field_account_type")}
          />
          <input
            id="account-derived-account-type"
            type="text"
            value={account_type_label(@derived_account_type)}
            readonly
            disabled
            class="mt-2 block w-full rounded-lg border border-white/10 bg-white/[0.03] px-3 py-2 text-sm text-white/78"
          />
        </div>
        <div>
          <.info_label
            for={@form[:institution_name].id}
            text={dgettext("accounts", "label_institution")}
            tooltip={dgettext("accounts", "tooltip_field_institution")}
          />
          <.input field={@form[:institution_name]} type="text" />
        </div>
      </div>

      <div>
        <.info_label
          for={@form[:institution_account_ref].id}
          text={dgettext("accounts", "label_institution_account_ref")}
          tooltip={dgettext("accounts", "tooltip_field_institution_account_ref")}
        />
        <.input field={@form[:institution_account_ref]} type="text" />
      </div>

      <div>
        <.info_label
          for={@form[:notes].id}
          text={dgettext("accounts", "label_notes")}
          tooltip={dgettext("accounts", "tooltip_field_notes")}
        />
        <.input field={@form[:notes]} type="textarea" />
      </div>

      <div class="rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-sm text-white/62">
        <p class="font-medium text-white/88">{dgettext("accounts", "label_entity_scope")}</p>
        <p class="mt-1">{@current_entity.name}</p>
      </div>

      <div class="flex flex-wrap gap-2">
        <button id="save-account-btn" type="submit" class="au-btn au-btn-primary">
          {save_button_label(@editing?)}
        </button>
      </div>
    </.form>
    """
  end

  defp derived_account_type(form, :institution) do
    case Phoenix.HTML.Form.normalize_value("select", form[:operational_subtype].value) do
      nil -> nil
      "" -> nil
      value -> operational_subtype_to_account_type(value)
    end
  end

  defp derived_account_type(form, :category) do
    case Phoenix.HTML.Form.normalize_value("select", form[:account_type].value) do
      nil -> nil
      "" -> nil
      value -> parse_account_type(value)
    end
  end

  defp derived_account_type(_form, :system_managed), do: :equity
  defp derived_account_type(_form, _), do: nil

  defp management_tab_classes(true),
    do:
      "flex items-start justify-between gap-3 rounded-2xl border border-white/30 bg-white/[0.08] px-4 py-3 text-left transition"

  defp management_tab_classes(false),
    do:
      "flex items-start justify-between gap-3 rounded-2xl border border-white/10 bg-white/[0.03] px-4 py-3 text-left transition hover:border-white/20 hover:bg-white/[0.05]"

  defp institution_operational_subtype_options do
    Enum.map(Account.institution_operational_subtypes(), fn subtype ->
      {operational_subtype_label(subtype), subtype}
    end)
  end

  defp currency_options, do: Currency.options()

  defp category_account_type_options do
    Enum.map(Account.category_account_types(), fn type ->
      {account_type_label(type), type}
    end)
  end

  defp management_group_options do
    [
      {management_group_label(:institution), :institution},
      {management_group_label(:category), :category},
      {management_group_label(:system_managed), :system_managed}
    ]
  end

  defp save_button_label(true), do: dgettext("accounts", "btn_save_changes")
  defp save_button_label(false), do: dgettext("accounts", "btn_create_account")

  defp management_group_label(group),
    do: AurumFinanceWeb.BadgeComponent.management_group_label(group)

  defp management_group_hint(:institution),
    do: dgettext("accounts", "management_group_institution_hint")

  defp management_group_hint(:category),
    do: dgettext("accounts", "management_group_category_hint")

  defp management_group_hint(:system_managed),
    do: dgettext("accounts", "management_group_system_managed_hint")

  defp account_type_label(type), do: AurumFinanceWeb.BadgeComponent.account_type_label(type)

  defp operational_subtype_label(type),
    do: AurumFinanceWeb.BadgeComponent.operational_subtype_label(type)

  defp normal_balance_label(account_type) do
    case Account.normal_balance(account_type) do
      :debit -> dgettext("accounts", "normal_balance_debit")
      :credit -> dgettext("accounts", "normal_balance_credit")
    end
  end

  defp operational_subtype_to_account_type(value) when is_atom(value) do
    Account.account_type_for_operational_subtype(value)
  end

  defp operational_subtype_to_account_type(value) when is_binary(value) do
    Account.institution_operational_subtypes()
    |> Enum.find(fn subtype -> Atom.to_string(subtype) == value end)
    |> Account.account_type_for_operational_subtype()
  end

  defp parse_account_type(value) when is_atom(value), do: value

  defp parse_account_type(value) when is_binary(value) do
    Enum.find(Account.account_types(), fn account_type ->
      Atom.to_string(account_type) == value
    end)
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value), do: not is_nil(value)
end
