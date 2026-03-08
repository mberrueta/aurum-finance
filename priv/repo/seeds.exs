alias AurumFinance.Currency
alias AurumFinance.Entities.Entity
alias AurumFinance.Ledger
alias AurumFinance.Ledger.Account
alias AurumFinance.Ledger.Transaction
alias AurumFinance.Repo

now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

default_entities = [
  %{
    name: "Personal",
    type: :individual,
    country_code: "US",
    fiscal_residency_country_code: "US",
    default_tax_rate_type: "irs_official",
    notes: "Default personal books"
  },
  %{
    name: "Main LLC",
    type: :legal_entity,
    country_code: "US",
    fiscal_residency_country_code: "US",
    default_tax_rate_type: "irs_official",
    notes: "Primary legal entity"
  },
  %{
    name: "Family Trust",
    type: :trust,
    country_code: "US",
    fiscal_residency_country_code: "US",
    default_tax_rate_type: "irs_official",
    notes: "Trust ownership boundary"
  }
]

demo_accounts_by_entity = %{
  "Personal" => [
    %{
      name: "Mercury Checking",
      management_group: :institution,
      account_type: :asset,
      operational_subtype: :bank_checking,
      currency_code: "USD",
      institution_name: "Mercury",
      institution_account_ref: "1001",
      notes: "Primary operating cash account"
    },
    %{
      name: "Fidelity Brokerage Cash",
      management_group: :institution,
      account_type: :asset,
      operational_subtype: :brokerage_cash,
      currency_code: "USD",
      institution_name: "Fidelity",
      institution_account_ref: "2001",
      notes: "Brokerage settlement cash"
    },
    %{
      name: "High Yield Savings",
      management_group: :institution,
      account_type: :asset,
      operational_subtype: :bank_savings,
      currency_code: "USD",
      institution_name: "Ally",
      institution_account_ref: "2002",
      notes: "Reserve cash account"
    },
    %{
      name: "Chase Sapphire",
      management_group: :institution,
      account_type: :liability,
      operational_subtype: :credit_card,
      currency_code: "USD",
      institution_name: "Chase",
      institution_account_ref: "3001",
      notes: "Primary personal card"
    },
    %{
      name: "Salary",
      management_group: :category,
      account_type: :income,
      currency_code: "USD",
      notes: "Primary employment income"
    },
    %{
      name: "Dividends",
      management_group: :category,
      account_type: :income,
      currency_code: "USD",
      notes: "Investment distributions"
    },
    %{
      name: "Food",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Restaurants and groceries"
    },
    %{
      name: "Household",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Home supplies and misc household purchases"
    },
    %{
      name: "Transport",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Fuel, rides, transit"
    },
    %{
      name: "Opening Balances",
      management_group: :system_managed,
      account_type: :equity,
      currency_code: "USD",
      notes: "System account for initial balances"
    },
    %{
      name: "FX Trading",
      management_group: :system_managed,
      account_type: :equity,
      currency_code: "USD",
      notes: "System account for FX balancing entries"
    }
  ],
  "Main LLC" => [
    %{
      name: "Operating Checking",
      management_group: :institution,
      account_type: :asset,
      operational_subtype: :bank_checking,
      currency_code: "USD",
      institution_name: "Mercury",
      institution_account_ref: "4001",
      notes: "Primary business checking"
    },
    %{
      name: "Tax Savings",
      management_group: :institution,
      account_type: :asset,
      operational_subtype: :bank_savings,
      currency_code: "USD",
      institution_name: "Mercury",
      institution_account_ref: "4002",
      notes: "Reserved for taxes"
    },
    %{
      name: "Consulting Revenue",
      management_group: :category,
      account_type: :income,
      currency_code: "USD",
      notes: "Services rendered"
    },
    %{
      name: "Software",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "SaaS and subscriptions"
    },
    %{
      name: "Opening Balances",
      management_group: :system_managed,
      account_type: :equity,
      currency_code: "USD",
      notes: "System account for initial balances"
    }
  ],
  "Family Trust" => [
    %{
      name: "Trust Custody Cash",
      management_group: :institution,
      account_type: :asset,
      operational_subtype: :brokerage_cash,
      currency_code: "USD",
      institution_name: "Schwab",
      institution_account_ref: "5001",
      notes: "Trust liquidity account"
    },
    %{
      name: "Distributions",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Trust beneficiary distributions"
    },
    %{
      name: "Interest Income",
      management_group: :category,
      account_type: :income,
      currency_code: "USD",
      notes: "Trust cash yield"
    },
    %{
      name: "Opening Balances",
      management_group: :system_managed,
      account_type: :equity,
      currency_code: "USD",
      notes: "System account for initial balances"
    }
  ]
}

ensure_entity = fn attrs ->
  case Repo.get_by(Entity, name: attrs.name) do
    nil ->
      entity =
        attrs
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)
        |> then(&Entity.changeset(%Entity{}, &1))
        |> Repo.insert!()

      IO.puts("seeded entity: #{attrs.name}")
      entity

    entity ->
      IO.puts("entity already exists, skipping: #{attrs.name}")
      entity
  end
end

ensure_account = fn entity, attrs ->
  attrs =
    attrs
    |> Map.put_new(:currency_code, Currency.default_code_for_country(entity.country_code))
    |> Map.put(:entity_id, entity.id)
    |> Map.put(:inserted_at, now)
    |> Map.put(:updated_at, now)

  case Repo.get_by(Account, entity_id: entity.id, name: attrs.name) do
    nil ->
      attrs
      |> then(&Account.changeset(%Account{}, &1))
      |> Repo.insert!()

      IO.puts("seeded account: #{entity.name} / #{attrs.name}")

    _account ->
      IO.puts("account already exists, skipping: #{entity.name} / #{attrs.name}")
  end
end

entities = Enum.map(default_entities, ensure_entity)

Enum.each(entities, fn entity ->
  entity.name
  |> then(&Map.get(demo_accounts_by_entity, &1, []))
  |> Enum.each(&ensure_account.(entity, &1))
end)

personal = Repo.get_by!(Entity, name: "Personal")

account =
  fn name ->
    Repo.get_by!(Account, entity_id: personal.id, name: name)
  end

checking = account.("Mercury Checking")
savings = account.("High Yield Savings")
credit_card = account.("Chase Sapphire")
food = account.("Food")
household = account.("Household")
opening_balances = account.("Opening Balances")

ensure_transaction =
  fn attrs ->
    lookup_attrs = Map.take(attrs, [:entity_id, :date, :description, :source_type])

    case Repo.get_by(Transaction, lookup_attrs) do
      nil ->
        {:ok, transaction} = Ledger.create_transaction(attrs)
        IO.puts("seeded transaction: #{attrs.description}")
        transaction

      transaction ->
        IO.puts("transaction already exists, skipping: #{attrs.description}")
        transaction
    end
  end

ensure_voided_transaction =
  fn attrs ->
    transaction = ensure_transaction.(attrs)

    if transaction.voided_at do
      IO.puts("transaction already voided, skipping void workflow: #{attrs.description}")
      transaction
    else
      {:ok, %{voided: voided}} = Ledger.void_transaction(transaction)
      IO.puts("voided seeded transaction: #{attrs.description}")
      voided
    end
  end

_opening_balance =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -12),
    description: "Initial checking balance",
    source_type: :system,
    postings: [
      %{account_id: opening_balances.id, amount: Decimal.new("-2500.00")},
      %{account_id: checking.id, amount: Decimal.new("2500.00")}
    ]
  })

_voided_source =
  ensure_voided_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -10),
    description: "Corner market groceries",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-45.00")},
      %{account_id: food.id, amount: Decimal.new("45.00")}
    ]
  })

_transfer =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -8),
    description: "Move cash to savings",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-1000.00")},
      %{account_id: savings.id, amount: Decimal.new("1000.00")}
    ]
  })

_card_purchase =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -6),
    description: "Restaurant dinner",
    source_type: :manual,
    postings: [
      %{account_id: food.id, amount: Decimal.new("85.00")},
      %{account_id: credit_card.id, amount: Decimal.new("-85.00")}
    ]
  })

_card_payment =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -4),
    description: "Credit card payment",
    source_type: :manual,
    postings: [
      %{account_id: credit_card.id, amount: Decimal.new("500.00")},
      %{account_id: checking.id, amount: Decimal.new("-500.00")}
    ]
  })

_split_purchase =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -2),
    description: "Superstore run",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-150.00")},
      %{account_id: food.id, amount: Decimal.new("80.00")},
      %{account_id: household.id, amount: Decimal.new("70.00")}
    ]
  })
