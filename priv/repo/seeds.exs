alias AurumFinance.Classification
alias AurumFinance.Currency
alias AurumFinance.Entities.Entity
alias AurumFinance.Ledger
alias AurumFinance.Ledger.Account
alias AurumFinance.Ledger.Transaction
alias AurumFinance.Repo
alias AurumFinance.Classification.Rule
alias AurumFinance.Classification.RuleGroup
import Ecto.Query

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
      name: "Travel",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Flights, lodging, and other travel-related spend"
    },
    %{
      name: "Shopping",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "General retail and ecommerce purchases"
    },
    %{
      name: "Health",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Pharmacy, clinic, and other health-related expenses"
    },
    %{
      name: "Fees",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Bank, card, and platform fees"
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
      name: "Utilities",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Electricity, water, gas, internet"
    },
    %{
      name: "Subscriptions",
      management_group: :category,
      account_type: :expense,
      currency_code: "USD",
      notes: "Recurring software and media subscriptions"
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
travel = account.("Travel")
shopping = account.("Shopping")
health = account.("Health")
fees = account.("Fees")
household = account.("Household")
transport = account.("Transport")
utilities = account.("Utilities")
subscriptions = account.("Subscriptions")
dividends = account.("Dividends")
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

_uber_trip =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -1),
    description: "uber trip downtown",
    source_type: :manual,
    postings: [
      %{account_id: credit_card.id, amount: Decimal.new("-24.50")},
      %{account_id: transport.id, amount: Decimal.new("24.50")}
    ]
  })

_netflix_charge =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.utc_today(),
    description: "netflix monthly subscription",
    source_type: :manual,
    postings: [
      %{account_id: credit_card.id, amount: Decimal.new("-19.99")},
      %{account_id: subscriptions.id, amount: Decimal.new("19.99")}
    ]
  })

_spotify_charge =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -1),
    description: "spotify premium subscription",
    source_type: :manual,
    postings: [
      %{account_id: credit_card.id, amount: Decimal.new("-10.99")},
      %{account_id: subscriptions.id, amount: Decimal.new("10.99")}
    ]
  })

electric_utility =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -3),
    description: "electric utility autopay",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-118.72")},
      %{account_id: utilities.id, amount: Decimal.new("118.72")}
    ]
  })

_whole_foods =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -9),
    description: "whole foods market",
    source_type: :manual,
    postings: [
      %{account_id: credit_card.id, amount: Decimal.new("-86.14")},
      %{account_id: food.id, amount: Decimal.new("86.14")}
    ]
  })

_target_household =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -7),
    description: "target household essentials",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-72.33")},
      %{account_id: household.id, amount: Decimal.new("72.33")}
    ]
  })

_delta_flight =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -6),
    description: "delta airlines airfare",
    source_type: :manual,
    postings: [
      %{account_id: credit_card.id, amount: Decimal.new("-248.40")},
      %{account_id: travel.id, amount: Decimal.new("248.40")}
    ]
  })

_cvs_pharmacy =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -5),
    description: "cvs pharmacy",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-24.85")},
      %{account_id: health.id, amount: Decimal.new("24.85")}
    ]
  })

_bank_fee =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -4),
    description: "monthly bank service fee",
    source_type: :manual,
    postings: [
      %{account_id: checking.id, amount: Decimal.new("-12.00")},
      %{account_id: fees.id, amount: Decimal.new("12.00")}
    ]
  })

_amazon_order =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -3),
    description: "amazon marketplace order",
    source_type: :manual,
    postings: [
      %{account_id: credit_card.id, amount: Decimal.new("-54.90")},
      %{account_id: shopping.id, amount: Decimal.new("54.90")}
    ]
  })

dividend_payment =
  ensure_transaction.(%{
    entity_id: personal.id,
    date: Date.add(Date.utc_today(), -5),
    description: "dividend payment vti",
    source_type: :manual,
    postings: [
      %{account_id: savings.id, amount: Decimal.new("32.18")},
      %{account_id: dividends.id, amount: Decimal.new("-32.18")}
    ]
  })

main_llc = Repo.get_by!(Entity, name: "Main LLC")

llc_account =
  fn name ->
    Repo.get_by!(Account, entity_id: main_llc.id, name: name)
  end

operating_checking = llc_account.("Operating Checking")
software = llc_account.("Software")
consulting_revenue = llc_account.("Consulting Revenue")

_client_payment =
  ensure_transaction.(%{
    entity_id: main_llc.id,
    date: Date.add(Date.utc_today(), -7),
    description: "client wire march",
    source_type: :manual,
    postings: [
      %{account_id: operating_checking.id, amount: Decimal.new("3500.00")},
      %{account_id: consulting_revenue.id, amount: Decimal.new("-3500.00")}
    ]
  })

_linear_subscription =
  ensure_transaction.(%{
    entity_id: main_llc.id,
    date: Date.add(Date.utc_today(), -2),
    description: "linear subscription invoice",
    source_type: :manual,
    postings: [
      %{account_id: operating_checking.id, amount: Decimal.new("-96.00")},
      %{account_id: software.id, amount: Decimal.new("96.00")}
    ]
  })

ensure_rule_group =
  fn attrs ->
    existing_rule_group =
      RuleGroup
      |> where([rule_group], rule_group.scope_type == ^attrs.scope_type)
      |> where([rule_group], rule_group.name == ^attrs.name)
      |> then(fn query ->
        case attrs.entity_id do
          nil -> where(query, [rule_group], is_nil(rule_group.entity_id))
          entity_id -> where(query, [rule_group], rule_group.entity_id == ^entity_id)
        end
      end)
      |> then(fn query ->
        case attrs.account_id do
          nil -> where(query, [rule_group], is_nil(rule_group.account_id))
          account_id -> where(query, [rule_group], rule_group.account_id == ^account_id)
        end
      end)
      |> Repo.one()

    case existing_rule_group do
      nil ->
        {:ok, rule_group} =
          Classification.create_rule_group(attrs, actor: "seed", channel: :system)

        IO.puts("seeded rule group: #{attrs.name}")
        rule_group

      rule_group ->
        {:ok, updated_rule_group} =
          Classification.update_rule_group(rule_group, attrs, actor: "seed", channel: :system)

        IO.puts("rule group already exists, refreshed: #{attrs.name}")
        updated_rule_group
    end
  end

ensure_rule =
  fn rule_group, attrs ->
    lookup_attrs =
      attrs
      |> Map.take([:name, :position])
      |> Map.put(:rule_group_id, rule_group.id)

    attrs = Map.put(attrs, :rule_group_id, rule_group.id)

    case Repo.get_by(Rule, lookup_attrs) do
      nil ->
        {:ok, rule} = Classification.create_rule(attrs, actor: "seed", channel: :system)
        IO.puts("seeded rule: #{rule_group.name} / #{attrs.name}")
        rule

      rule ->
        {:ok, updated_rule} =
          Classification.update_rule(rule, attrs, actor: "seed", channel: :system)

        IO.puts("rule already exists, refreshed: #{rule_group.name} / #{attrs.name}")
        updated_rule
    end
  end

personal_global_group =
  ensure_rule_group.(%{
    scope_type: :global,
    entity_id: nil,
    account_id: nil,
    name: "Seed Global Merchant Tags",
    description: "Cross-entity starter rules that only suggest generic tags and notes.",
    priority: 3,
    target_fields: ["tags", "notes"],
    is_active: true
  })

personal_entity_group =
  ensure_rule_group.(%{
    scope_type: :entity,
    entity_id: personal.id,
    account_id: nil,
    name: "Personal Merchant Categories",
    description: "Personal category defaults for common recurring merchants.",
    priority: 2,
    target_fields: ["category", "tags", "investment_type", "notes"],
    is_active: true
  })

personal_card_group =
  ensure_rule_group.(%{
    scope_type: :account,
    entity_id: nil,
    account_id: credit_card.id,
    name: "Chase Sapphire Overrides",
    description: "Higher-precedence card-specific rules for personal card spend.",
    priority: 1,
    target_fields: ["category", "tags", "notes"],
    is_active: true
  })

llc_entity_group =
  ensure_rule_group.(%{
    scope_type: :entity,
    entity_id: main_llc.id,
    account_id: nil,
    name: "Main LLC Ops Rules",
    description: "Starter business rules for recurring software and revenue descriptions.",
    priority: 1,
    target_fields: ["category", "tags", "notes"],
    is_active: true
  })

seed_rules =
  fn rule_group, rules ->
    rules
    |> Enum.with_index(1)
    |> Enum.each(fn {attrs, position} ->
      attrs =
        attrs
        |> Map.put_new(:position, position)
        |> Map.put_new(:is_active, true)
        |> Map.put_new(:stop_processing, true)

      ensure_rule.(rule_group, attrs)
    end)
  end

seed_rules.(personal_global_group, [
  %{
    name: "Ride share merchants",
    description: "Tags common ride share merchants.",
    expression: ~S[description matches_regex "(?i)(uber|lyft)"],
    stop_processing: false,
    actions: [
      %{field: :tags, operation: :add, value: "mobility"},
      %{field: :notes, operation: :set, value: "Seeded mobility merchant match"}
    ]
  },
  %{
    name: "Streaming subscriptions",
    description: "Tags major streaming and media subscriptions.",
    expression:
      ~S[description matches_regex "(?i)(netflix|spotify|hbo|max|disney|prime video|youtube premium)"],
    stop_processing: false,
    actions: [
      %{field: :tags, operation: :add, value: "streaming"},
      %{field: :notes, operation: :set, value: "Seeded streaming subscription match"}
    ]
  },
  %{
    name: "Delivery apps",
    description: "Tags common food delivery merchants.",
    expression: ~S[description matches_regex "(?i)(doordash|ubereats|uber eats|grubhub|rappi)"],
    actions: [%{field: :tags, operation: :add, value: "delivery"}]
  },
  %{
    name: "Grocery merchants",
    description: "Tags grocery store transactions.",
    expression:
      ~S[description matches_regex "(?i)(whole foods|trader joe|costco|safeway|kroger)"],
    actions: [%{field: :tags, operation: :add, value: "groceries"}]
  },
  %{
    name: "Coffee shops",
    description: "Tags coffee and cafe merchants.",
    expression: ~S[description matches_regex "(?i)(starbucks|blue bottle|philz|coffee)"],
    actions: [%{field: :tags, operation: :add, value: "coffee"}]
  },
  %{
    name: "Travel merchants",
    description: "Tags airlines, hotels, and booking providers.",
    expression:
      ~S[description matches_regex "(?i)(delta|united|american airlines|airbnb|booking|hotel)"],
    actions: [%{field: :tags, operation: :add, value: "travel"}]
  },
  %{
    name: "Pharmacy and care",
    description: "Tags pharmacy and clinic spend.",
    expression:
      ~S[description matches_regex "(?i)(cvs|walgreens|pharmacy|dental|clinic|medical)"],
    actions: [%{field: :tags, operation: :add, value: "health"}]
  },
  %{
    name: "Transfers and card payments",
    description: "Tags transfers and internal settlement movements.",
    expression:
      ~S[description matches_regex "(?i)(transfer|credit card payment|move cash|payment)"],
    actions: [%{field: :tags, operation: :add, value: "internal_transfer"}]
  },
  %{
    name: "Payroll and salary",
    description: "Tags recurring income deposits.",
    expression: ~S[description matches_regex "(?i)(salary|payroll|paycheck|direct deposit)"],
    actions: [%{field: :tags, operation: :add, value: "income_recurring"}]
  },
  %{
    name: "Bank and platform fees",
    description: "Tags fee-like charges.",
    expression: ~S[description matches_regex "(?i)(fee|chargeback fee|service fee)"],
    actions: [%{field: :tags, operation: :add, value: "fees"}]
  }
])

seed_rules.(personal_entity_group, [
  %{
    name: "Utility autopay",
    description: "Classifies household utility payments.",
    expression:
      ~S[description matches_regex "(?i)(utility|electric|water|gas|internet|comcast|verizon)"],
    actions: [
      %{field: :category, operation: :set, value: utilities.id},
      %{field: :tags, operation: :add, value: "home"},
      %{field: :notes, operation: :set, value: "Seeded household utility rule"}
    ]
  },
  %{
    name: "Dividend income",
    description: "Marks dividend-related inflows.",
    expression: ~S[description matches_regex "(?i)(dividend|distribution)"],
    actions: [
      %{field: :category, operation: :set, value: dividends.id},
      %{field: :tags, operation: :add, value: "investment_income"},
      %{field: :investment_type, operation: :set, value: "dividend"}
    ]
  },
  %{
    name: "Streaming subscriptions category",
    description: "Maps streaming services into subscriptions.",
    expression:
      ~S[description matches_regex "(?i)(netflix|spotify|hbo|max|disney|prime video|youtube premium)"],
    actions: [
      %{field: :category, operation: :set, value: subscriptions.id},
      %{field: :tags, operation: :add, value: "recurring"}
    ]
  },
  %{
    name: "Groceries and markets",
    description: "Maps grocery merchants into Food.",
    expression:
      ~S[description matches_regex "(?i)(whole foods|trader joe|costco|safeway|kroger|market)"],
    actions: [
      %{field: :category, operation: :set, value: food.id},
      %{field: :tags, operation: :add, value: "groceries"}
    ]
  },
  %{
    name: "Restaurants and cafes",
    description: "Maps dining merchants into Food with a dining tag.",
    expression:
      ~S[description matches_regex "(?i)(restaurant|dinner|lunch|starbucks|chipotle|burger|cafe)"],
    actions: [
      %{field: :category, operation: :set, value: food.id},
      %{field: :tags, operation: :add, value: "dining"}
    ]
  },
  %{
    name: "Household retail",
    description: "Maps home and big-box purchases into Household.",
    expression:
      ~S[description matches_regex "(?i)(target|ikea|home depot|lowe|household|walmart)"],
    actions: [
      %{field: :category, operation: :set, value: household.id},
      %{field: :tags, operation: :add, value: "household"}
    ]
  },
  %{
    name: "General ecommerce",
    description: "Maps ecommerce orders into Shopping.",
    expression: ~S[description matches_regex "(?i)(amazon|marketplace|retail order)"],
    actions: [
      %{field: :category, operation: :set, value: shopping.id},
      %{field: :tags, operation: :add, value: "ecommerce"}
    ]
  },
  %{
    name: "Flights and lodging",
    description: "Maps travel providers into Travel.",
    expression: ~S[description matches_regex "(?i)(delta|united|airbnb|booking|hotel|airfare)"],
    actions: [
      %{field: :category, operation: :set, value: travel.id},
      %{field: :tags, operation: :add, value: "travel"}
    ]
  },
  %{
    name: "Pharmacy and wellness",
    description: "Maps pharmacy and clinic charges into Health.",
    expression:
      ~S[description matches_regex "(?i)(cvs|walgreens|pharmacy|medical|clinic|health)"],
    actions: [
      %{field: :category, operation: :set, value: health.id},
      %{field: :tags, operation: :add, value: "health"}
    ]
  },
  %{
    name: "Bank service fees",
    description: "Maps fee charges into Fees.",
    expression:
      ~S[description matches_regex "(?i)(service fee|bank fee|maintenance fee|overdraft)"],
    actions: [
      %{field: :category, operation: :set, value: fees.id},
      %{field: :tags, operation: :add, value: "fees"}
    ]
  },
  %{
    name: "Salary deposits",
    description: "Maps payroll-like deposits into Salary.",
    expression: ~S[description matches_regex "(?i)(salary|payroll|paycheck|direct deposit)"],
    actions: [
      %{field: :category, operation: :set, value: account.("Salary").id},
      %{field: :tags, operation: :add, value: "income_recurring"}
    ]
  }
])

seed_rules.(personal_card_group, [
  %{
    name: "Uber commute override",
    description: "Card-specific commute categorization with higher precedence.",
    expression: ~S[description matches_regex "(?i)(uber|lyft)"],
    actions: [
      %{field: :category, operation: :set, value: transport.id},
      %{field: :tags, operation: :add, value: "commute"},
      %{field: :notes, operation: :set, value: "High-precedence card rule"}
    ]
  },
  %{
    name: "Netflix subscriptions",
    description: "Card-specific streaming classification.",
    expression: ~s|description contains "netflix"|,
    actions: [
      %{field: :category, operation: :set, value: subscriptions.id},
      %{field: :tags, operation: :add, value: "streaming"}
    ]
  },
  %{
    name: "Spotify subscriptions",
    description: "Card-specific audio streaming classification.",
    expression: ~s|description contains "spotify"|,
    actions: [
      %{field: :category, operation: :set, value: subscriptions.id},
      %{field: :tags, operation: :add, value: "streaming"}
    ]
  },
  %{
    name: "Airlines on card",
    description: "Card-specific travel classification for airfare.",
    expression: ~S[description matches_regex "(?i)(delta|united|american airlines|airfare)"],
    actions: [
      %{field: :category, operation: :set, value: travel.id},
      %{field: :tags, operation: :add, value: "travel"}
    ]
  },
  %{
    name: "Hotels and lodging on card",
    description: "Card-specific travel classification for lodging.",
    expression: ~S[description matches_regex "(?i)(airbnb|hotel|booking)"],
    actions: [
      %{field: :category, operation: :set, value: travel.id},
      %{field: :tags, operation: :add, value: "lodging"}
    ]
  },
  %{
    name: "Amazon shopping on card",
    description: "Card-specific ecommerce classification.",
    expression: ~S[description matches_regex "(?i)(amazon|marketplace)"],
    actions: [
      %{field: :category, operation: :set, value: shopping.id},
      %{field: :tags, operation: :add, value: "ecommerce"}
    ]
  },
  %{
    name: "Dining on card",
    description: "Card-specific restaurant classification.",
    expression:
      ~S[description matches_regex "(?i)(restaurant|dinner|lunch|chipotle|burger|cafe|starbucks)"],
    actions: [
      %{field: :category, operation: :set, value: food.id},
      %{field: :tags, operation: :add, value: "dining"}
    ]
  },
  %{
    name: "Delivery apps on card",
    description: "Card-specific delivery classification.",
    expression: ~S[description matches_regex "(?i)(doordash|ubereats|uber eats|grubhub|rappi)"],
    actions: [
      %{field: :category, operation: :set, value: food.id},
      %{field: :tags, operation: :add, value: "delivery"}
    ]
  }
])

ensure_rule.(llc_entity_group, %{
  name: "Software subscriptions",
  description: "Business SaaS categorization.",
  position: 1,
  is_active: true,
  stop_processing: true,
  expression: ~s|description contains "subscription"|,
  actions: [
    %{field: :category, operation: :set, value: software.id},
    %{field: :tags, operation: :add, value: "saas"},
    %{field: :notes, operation: :set, value: "Recurring business subscription"}
  ]
})

ensure_rule.(llc_entity_group, %{
  name: "Client revenue",
  description: "Marks client wires as consulting income.",
  position: 2,
  is_active: true,
  stop_processing: true,
  expression: ~s|description contains "client wire"|,
  actions: [
    %{field: :category, operation: :set, value: consulting_revenue.id},
    %{field: :tags, operation: :add, value: "client_payment"}
  ]
})

{:ok, _dividend_result} =
  Classification.classify_transaction(
    dividend_payment.id,
    entity_id: personal.id,
    actor: "seed",
    channel: :system
  )

{:ok, _utility_classification} =
  Classification.set_manual_field(
    electric_utility.id,
    :tags,
    "manual-review,utilities",
    entity_id: personal.id,
    actor: "seed",
    channel: :system
  )

{:ok, _utility_note} =
  Classification.set_manual_field(
    electric_utility.id,
    :notes,
    "Manual override left locked on purpose for preview/apply demos",
    entity_id: personal.id,
    actor: "seed",
    channel: :system
  )
