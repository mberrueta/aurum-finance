defmodule AurumFinance.Factory do
  @moduledoc """
  Shared ExMachina factories for deterministic test setup.
  """

  use ExMachina.Ecto, repo: AurumFinance.Repo

  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction

  def entity_factory do
    %Entity{
      name: sequence(:entity_name, fn n -> "#{Faker.Person.name()} #{n}" end),
      type: :individual,
      country_code: "US",
      fiscal_residency_country_code: "US",
      default_tax_rate_type: "irs_official",
      notes: Faker.Lorem.sentence()
    }
  end

  def account_factory do
    entity = insert(:entity)

    %Account{
      entity: entity,
      entity_id: entity.id,
      name: sequence(:account_name, fn n -> "#{Faker.Company.bs()} #{n}" end),
      account_type: :asset,
      operational_subtype: :bank_checking,
      management_group: :institution,
      currency_code: "USD",
      institution_name: Faker.Company.name(),
      institution_account_ref: sequence(:account_ref, fn n -> Integer.to_string(1000 + n) end),
      notes: Faker.Lorem.sentence()
    }
  end

  def transaction_factory do
    entity = insert(:entity)

    %Transaction{
      entity: entity,
      entity_id: entity.id,
      date: Date.utc_today(),
      description: sequence(:transaction_description, fn n -> "Transaction #{n}" end),
      source_type: :manual,
      correlation_id: nil,
      voided_at: nil
    }
  end

  def posting_factory do
    entity = insert(:entity)
    transaction = insert(:transaction, entity: entity, entity_id: entity.id)
    account = insert(:account, entity: entity, entity_id: entity.id)

    %Posting{
      transaction: transaction,
      transaction_id: transaction.id,
      account: account,
      account_id: account.id,
      amount: Decimal.new("10.00")
    }
  end

  def insert_entity(attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      :entity
      |> params_for()
      |> Map.merge(attrs)

    {:ok, entity} = Entities.create_entity(params)
    entity
  end

  def insert_account(entity, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      :account
      |> params_for(entity_id: entity.id, entity: entity)
      |> Map.drop([:entity])
      |> Map.merge(%{entity_id: entity.id})
      |> Map.merge(attrs)

    {:ok, account} = Ledger.create_account(params)
    account
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs), do: attrs
end
