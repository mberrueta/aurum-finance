defmodule AurumFinance.Factory do
  @moduledoc """
  Shared ExMachina factories for deterministic test setup.
  """

  use ExMachina.Ecto, repo: AurumFinance.Repo

  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Account

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
end
