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
end
