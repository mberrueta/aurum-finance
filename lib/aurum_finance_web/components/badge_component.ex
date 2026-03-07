defmodule AurumFinanceWeb.BadgeComponent do
  @moduledoc """
  Centralized badge components.
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  alias AurumFinance.Helpers

  import AurumFinanceWeb.UiComponents, only: [badge: 1]

  @doc """
  Renders a color-coded badge for entity types.

  Example:

      <.entity_type_badge type={:individual} />
  """
  attr :type, :any, required: true

  def entity_type_badge(assigns) do
    ~H"""
    <.badge variant={entity_type_variant(@type)}>{entity_type_label(@type)}</.badge>
    """
  end

  defp entity_type_variant(type) when is_atom(type), do: entity_type_variant(Atom.to_string(type))
  defp entity_type_variant("individual"), do: :good
  defp entity_type_variant("legal_entity"), do: :purple
  defp entity_type_variant("trust"), do: :warn
  defp entity_type_variant("other"), do: :default
  defp entity_type_variant(_unknown), do: :default

  defp entity_type_label(type) when is_atom(type), do: entity_type_label(Atom.to_string(type))
  defp entity_type_label("individual"), do: dgettext("entities", "entity_type_individual")
  defp entity_type_label("legal_entity"), do: dgettext("entities", "entity_type_legal_entity")
  defp entity_type_label("trust"), do: dgettext("entities", "entity_type_trust")
  defp entity_type_label("other"), do: dgettext("entities", "entity_type_other")
  defp entity_type_label(unknown), do: Helpers.humanize_token(unknown)

  @doc """
  Renders a badge for account management groups.

  Example:

      <.management_group_badge group={:institution} />
  """
  attr :group, :any, required: true

  def management_group_badge(assigns) do
    ~H"""
    <.badge variant={management_group_variant(@group)}>{management_group_label(@group)}</.badge>
    """
  end

  @doc """
  Renders a badge for account types.

  Example:

      <.account_type_badge type={:asset} />
  """
  attr :type, :any, required: true

  def account_type_badge(assigns) do
    ~H"""
    <.badge variant={account_type_variant(@type)}>{account_type_label(@type)}</.badge>
    """
  end

  @doc """
  Returns the translated account management group label.

  ## Examples

      iex> AurumFinanceWeb.BadgeComponent.management_group_label(:institution)
      "Institution"

      iex> AurumFinanceWeb.BadgeComponent.management_group_label("system_managed")
      "System-managed"
  """
  def management_group_label(group) when is_atom(group),
    do: management_group_label(Atom.to_string(group))

  def management_group_label("institution"),
    do: dgettext("accounts", "management_group_institution")

  def management_group_label("category"), do: dgettext("accounts", "management_group_category")

  def management_group_label("system_managed"),
    do: dgettext("accounts", "management_group_system_managed")

  def management_group_label(_unknown), do: dgettext("accounts", "management_group_unknown")

  @doc """
  Returns the badge variant for an account management group.

  ## Examples

      iex> AurumFinanceWeb.BadgeComponent.management_group_variant(:institution)
      :purple

      iex> AurumFinanceWeb.BadgeComponent.management_group_variant("category")
      :warn
  """
  def management_group_variant(group) when is_atom(group),
    do: management_group_variant(Atom.to_string(group))

  def management_group_variant("institution"), do: :purple
  def management_group_variant("category"), do: :warn
  def management_group_variant("system_managed"), do: :bad
  def management_group_variant(_unknown), do: :default

  @doc """
  Returns the translated account type label.

  ## Examples

      iex> AurumFinanceWeb.BadgeComponent.account_type_label(:asset)
      "Asset"

      iex> AurumFinanceWeb.BadgeComponent.account_type_label(nil)
      "Pending"
  """
  def account_type_label(nil), do: dgettext("accounts", "value_pending")
  def account_type_label(type) when is_atom(type), do: account_type_label(Atom.to_string(type))
  def account_type_label("asset"), do: dgettext("accounts", "account_type_asset")
  def account_type_label("liability"), do: dgettext("accounts", "account_type_liability")
  def account_type_label("equity"), do: dgettext("accounts", "account_type_equity")
  def account_type_label("income"), do: dgettext("accounts", "account_type_income")
  def account_type_label("expense"), do: dgettext("accounts", "account_type_expense")
  def account_type_label(unknown), do: Helpers.humanize_token(unknown)

  @doc """
  Returns the translated operational subtype label.

  ## Examples

      iex> AurumFinanceWeb.BadgeComponent.operational_subtype_label(:bank_checking)
      "Bank checking"

      iex> AurumFinanceWeb.BadgeComponent.operational_subtype_label(nil)
      "Not applicable"
  """
  def operational_subtype_label(nil), do: dgettext("accounts", "value_not_applicable")

  def operational_subtype_label(type) when is_atom(type),
    do: operational_subtype_label(Atom.to_string(type))

  def operational_subtype_label("bank_checking"),
    do: dgettext("accounts", "operational_subtype_bank_checking")

  def operational_subtype_label("bank_savings"),
    do: dgettext("accounts", "operational_subtype_bank_savings")

  def operational_subtype_label("cash"), do: dgettext("accounts", "operational_subtype_cash")

  def operational_subtype_label("brokerage_cash"),
    do: dgettext("accounts", "operational_subtype_brokerage_cash")

  def operational_subtype_label("brokerage_securities"),
    do: dgettext("accounts", "operational_subtype_brokerage_securities")

  def operational_subtype_label("crypto_wallet"),
    do: dgettext("accounts", "operational_subtype_crypto_wallet")

  def operational_subtype_label("credit_card"),
    do: dgettext("accounts", "operational_subtype_credit_card")

  def operational_subtype_label("loan"), do: dgettext("accounts", "operational_subtype_loan")

  def operational_subtype_label("other_asset"),
    do: dgettext("accounts", "operational_subtype_other_asset")

  def operational_subtype_label("other_liability"),
    do: dgettext("accounts", "operational_subtype_other_liability")

  def operational_subtype_label(unknown), do: Helpers.humanize_token(unknown)

  defp account_type_variant(type) when is_atom(type),
    do: account_type_variant(Atom.to_string(type))

  defp account_type_variant("asset"), do: :good
  defp account_type_variant("liability"), do: :bad
  defp account_type_variant("equity"), do: :purple
  defp account_type_variant("income"), do: :good
  defp account_type_variant("expense"), do: :warn
  defp account_type_variant(_unknown), do: :default
end
