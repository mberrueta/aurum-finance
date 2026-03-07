defmodule AurumFinance.TestSupport.Fixtures do
  @moduledoc """
  Shared fixture helpers built on top of contexts and ExMachina factories.
  """

  alias AurumFinance.Entities
  alias AurumFinance.Ledger

  def entity_fixture(attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      :entity
      |> AurumFinance.Factory.params_for()
      |> Map.merge(attrs)

    {:ok, entity} = Entities.create_entity(params)
    entity
  end

  def account_fixture(entity, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      :account
      |> AurumFinance.Factory.params_for(entity_id: entity.id, entity: entity)
      |> Map.drop([:entity])
      |> Map.merge(%{entity_id: entity.id})
      |> Map.merge(attrs)

    {:ok, account} = Ledger.create_account(params)
    account
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs), do: attrs
end
