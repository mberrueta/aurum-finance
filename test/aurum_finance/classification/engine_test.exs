defmodule AurumFinance.Classification.EngineTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Classification.Engine
  alias AurumFinance.Classification.Engine.ProposedChange
  alias AurumFinance.Classification.Engine.Result
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleAction
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias Decimal, as: D

  # ---------------------------------------------------------------------------
  # Helpers: in-memory structs only, no DB
  # ---------------------------------------------------------------------------

  defp transaction(entity_id, postings, opts \\ []) do
    %Transaction{
      id: Ecto.UUID.generate(),
      entity_id: entity_id,
      date: Keyword.get(opts, :date, ~D[2026-03-14]),
      description: Keyword.get(opts, :description, "Uber trip"),
      source_type: Keyword.get(opts, :source_type, :import),
      postings: postings
    }
  end

  defp posting(account_id, amount, opts \\ []) do
    currency = Keyword.get(opts, :currency_code, "USD")
    name = Keyword.get(opts, :account_name, "Checking")
    type = Keyword.get(opts, :account_type, :asset)
    institution = Keyword.get(opts, :institution_name, "Bank")

    %Posting{
      account_id: account_id,
      amount: amount,
      account: %Account{
        id: account_id,
        currency_code: currency,
        name: name,
        account_type: type,
        institution_name: institution
      }
    }
  end

  defp group(scope_type, name, priority, rules, opts \\ []) do
    %RuleGroup{
      id: Keyword.get(opts, :id, Ecto.UUID.generate()),
      scope_type: scope_type,
      name: name,
      priority: priority,
      is_active: Keyword.get(opts, :is_active, true),
      entity_id: Keyword.get(opts, :entity_id),
      account_id: Keyword.get(opts, :account_id),
      rules: rules
    }
  end

  defp rule(name, position, expression, actions, opts \\ []) do
    %Rule{
      id: Keyword.get(opts, :id, Ecto.UUID.generate()),
      name: name,
      position: position,
      expression: expression,
      is_active: Keyword.get(opts, :is_active, true),
      stop_processing: Keyword.get(opts, :stop_processing, true),
      actions: actions
    }
  end

  defp action(field, operation, value) do
    %RuleAction{field: field, operation: operation, value: value}
  end

  defp proposed_fields(result) do
    result.proposed_changes
    |> Enum.filter(&(&1.status == :proposed))
    |> Enum.map(& &1.field)
  end

  defp change_for(result, field, status \\ :proposed) do
    Enum.find(result.proposed_changes, &(&1.field == field and &1.status == status))
  end

  # ---------------------------------------------------------------------------
  # S01-S03: Scope precedence
  # ---------------------------------------------------------------------------

  describe "scope precedence" do
    test "S01: account-scoped groups outrank entity-scoped which outrank global" do
      cat_account = Ecto.UUID.generate()
      cat_entity = Ecto.UUID.generate()
      cat_global = Ecto.UUID.generate()

      txn =
        transaction("entity-1", [
          posting("acct-1", D.new("-10"))
        ])

      groups = [
        group(:global, "Global", 1, [
          rule("G", 1, ~s|description contains "uber"|, [
            action(:category, :set, cat_global)
          ])
        ]),
        group(
          :entity,
          "Entity",
          1,
          [
            rule("E", 1, ~s|description contains "uber"|, [
              action(:category, :set, cat_entity)
            ])
          ],
          entity_id: "entity-1"
        ),
        group(
          :account,
          "Account",
          1,
          [
            rule("A", 1, ~s|description contains "uber"|, [
              action(:category, :set, cat_account)
            ])
          ],
          account_id: "acct-1"
        )
      ]

      [result] = Engine.evaluate([txn], groups)

      # Account group wins because it has the highest scope precedence
      assert change_for(result, :category).proposed_value == cat_account

      assert change_for(result, :category, :skipped_claimed) == nil ||
               Enum.count(
                 result.proposed_changes,
                 &(&1.field == :category and &1.status == :skipped_claimed)
               ) == 2
    end

    test "S02: matched_groups are ordered account, entity, global" do
      txn = transaction("entity-1", [posting("acct-1", D.new("-5"))])

      groups = [
        group(:global, "Zulu Global", 1, [
          rule("ZG", 1, ~s|description contains "uber"|, [action(:tags, :add, "g")])
        ]),
        group(
          :entity,
          "Alpha Entity",
          1,
          [
            rule("AE", 1, ~s|description contains "uber"|, [action(:notes, :set, "entity")])
          ],
          entity_id: "entity-1"
        ),
        group(
          :account,
          "Bravo Account",
          1,
          [
            rule("BA", 1, ~s|description contains "uber"|, [action(:investment_type, :set, "etf")])
          ],
          account_id: "acct-1"
        )
      ]

      [result] = Engine.evaluate([txn], groups)

      assert Enum.map(result.matched_groups, & &1.rule_group.name) == [
               "Bravo Account",
               "Alpha Entity",
               "Zulu Global"
             ]
    end

    test "S03: inactive groups are excluded from matching" do
      txn = transaction("entity-1", [posting("acct-1", D.new("-5"))])

      groups = [
        group(:global, "Active", 1, [
          rule("A", 1, ~s|description contains "uber"|, [action(:tags, :add, "yes")])
        ]),
        group(
          :global,
          "Inactive",
          2,
          [
            rule("I", 1, ~s|description contains "uber"|, [action(:notes, :set, "no")])
          ],
          is_active: false
        )
      ]

      [result] = Engine.evaluate([txn], groups)
      assert Enum.map(result.matched_groups, & &1.rule_group.name) == ["Active"]
    end
  end

  # ---------------------------------------------------------------------------
  # S04-S06: Group ordering within same scope
  # ---------------------------------------------------------------------------

  describe "group ordering" do
    test "S04: groups ordered by priority ASC within same scope" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      groups = [
        group(:global, "High", 5, [
          rule("H", 1, ~s|description contains "uber"|, [
            action(:category, :set, Ecto.UUID.generate())
          ])
        ]),
        group(:global, "Low", 1, [
          rule("L", 1, ~s|description contains "uber"|, [
            action(:category, :set, Ecto.UUID.generate())
          ])
        ])
      ]

      [result] = Engine.evaluate([txn], groups)

      # Low priority group wins category (first writer wins)
      assert Enum.map(result.matched_groups, & &1.rule_group.name) == ["Low", "High"]
    end

    test "S05: tie-break by name ASC when priority is equal" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      groups = [
        group(:global, "Zulu", 1, [
          rule("Z", 1, ~s|description contains "uber"|, [action(:tags, :add, "z")])
        ]),
        group(:global, "Alpha", 1, [
          rule("A", 1, ~s|description contains "uber"|, [action(:tags, :add, "a")])
        ])
      ]

      [result] = Engine.evaluate([txn], groups)

      assert Enum.map(result.matched_groups, & &1.rule_group.name) == ["Alpha", "Zulu"]
    end
  end

  # ---------------------------------------------------------------------------
  # S06-S08: Rule ordering within a group
  # ---------------------------------------------------------------------------

  describe "rule ordering" do
    test "S06: rules ordered by position ASC, tie-break by name ASC" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Zulu", 1, ~s|description contains "uber"|, [action(:tags, :add, "z")],
            stop_processing: false
          ),
          rule("Alpha", 1, ~s|description contains "uber"|, [action(:notes, :set, "a")],
            stop_processing: false
          ),
          rule(
            "Beta",
            2,
            ~s|description contains "uber"|,
            [action(:investment_type, :set, "bond")],
            stop_processing: false
          )
        ])

      [result] = Engine.evaluate([txn], [g])

      # Same position=1: Alpha before Zulu by name; then Beta at position=2
      assert Enum.map(result.matched_rules, & &1.name) == ["Alpha", "Zulu", "Beta"]
    end

    test "S07: inactive rules are skipped" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Active", 1, ~s|description contains "uber"|, [action(:tags, :add, "a")],
            stop_processing: false
          ),
          rule("Inactive", 2, ~s|description contains "uber"|, [action(:notes, :set, "x")],
            is_active: false,
            stop_processing: false
          )
        ])

      [result] = Engine.evaluate([txn], [g])
      assert Enum.map(result.matched_rules, & &1.name) == ["Active"]
    end
  end

  # ---------------------------------------------------------------------------
  # S08-S09: stop_processing semantics
  # ---------------------------------------------------------------------------

  describe "stop_processing" do
    test "S08: stop_processing true halts after first match in the group" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("First", 1, ~s|description contains "uber"|, [action(:tags, :add, "first")],
            stop_processing: true
          ),
          rule("Second", 2, ~s|description contains "uber"|, [action(:notes, :set, "second")],
            stop_processing: false
          )
        ])

      [result] = Engine.evaluate([txn], [g])

      assert Enum.map(result.matched_rules, & &1.name) == ["First"]
      assert [:tags] = proposed_fields(result)
    end

    test "S09: stop_processing false continues evaluating subsequent rules" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("First", 1, ~s|description contains "uber"|, [action(:tags, :add, "first")],
            stop_processing: false
          ),
          rule("Second", 2, ~s|description contains "uber"|, [action(:notes, :set, "second")],
            stop_processing: false
          )
        ])

      [result] = Engine.evaluate([txn], [g])

      assert Enum.map(result.matched_rules, & &1.name) == ["First", "Second"]
      assert :tags in proposed_fields(result)
      assert :notes in proposed_fields(result)
    end

    test "S09b: stop_processing false allows additive rules to compose the same field within a group" do
      # Regression: previously the first rule claimed the field immediately via the
      # global claims set, causing subsequent rules in the same group to be
      # marked :skipped_claimed even with stop_processing: false.
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("First", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")],
            stop_processing: false
          ),
          rule("Second", 2, ~s|description contains "uber"|, [action(:tags, :add, "uber")],
            stop_processing: false
          )
        ])

      [result] = Engine.evaluate([txn], [g])

      assert Enum.map(result.matched_rules, & &1.name) == ["First", "Second"]

      # Both rules must produce :proposed changes — not :skipped_claimed
      tags_changes = Enum.filter(result.proposed_changes, &(&1.field == :tags))
      assert length(tags_changes) == 2
      assert Enum.all?(tags_changes, &(&1.status == :proposed))

      # The second rule chains on the first: final proposed value includes both tags
      last_tags_change = List.last(tags_changes)
      assert last_tags_change.proposed_value == ["ride", "uber"]
    end

    test "S10: stop_processing only affects current group, not subsequent groups" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g1 =
        group(:global, "G1", 1, [
          rule("Stop", 1, ~s|description contains "uber"|, [action(:tags, :add, "g1")],
            stop_processing: true
          ),
          rule("Skipped", 2, ~s|description contains "uber"|, [action(:notes, :set, "skip")])
        ])

      g2 =
        group(:global, "G2", 2, [
          rule("Continue", 1, ~s|description contains "uber"|, [action(:notes, :set, "g2")])
        ])

      [result] = Engine.evaluate([txn], [g1, g2])

      assert Enum.map(result.matched_rules, & &1.name) == ["Stop", "Continue"]
      assert change_for(result, :notes).proposed_value == "g2"
    end
  end

  # ---------------------------------------------------------------------------
  # S11-S12: Multi-posting transaction matching
  # ---------------------------------------------------------------------------

  describe "multi-posting matching" do
    test "S11: rule matches if any posting satisfies all conditions" do
      txn =
        transaction("e1", [
          posting("checking", D.new("-100"),
            currency_code: "USD",
            account_name: "Checking"
          ),
          posting("savings", D.new("100"),
            currency_code: "EUR",
            account_name: "Savings"
          )
        ])

      g =
        group(:global, "G", 1, [
          rule("EUR match", 1, ~s|currency_code equals "EUR"|, [action(:tags, :add, "euro")])
        ])

      [result] = Engine.evaluate([txn], [g])
      refute result.no_match?
      assert change_for(result, :tags).proposed_value == ["euro"]
    end

    test "S12: rule does not match when no single posting satisfies all conditions" do
      # Both postings are USD, so a EUR condition should not match
      txn =
        transaction("e1", [
          posting("a1", D.new("-10"), currency_code: "USD"),
          posting("a2", D.new("10"), currency_code: "USD")
        ])

      g =
        group(:global, "G", 1, [
          rule("EUR only", 1, ~s|currency_code equals "EUR"|, [action(:tags, :add, "euro")])
        ])

      [result] = Engine.evaluate([txn], [g])
      assert result.no_match?
    end
  end

  # ---------------------------------------------------------------------------
  # S13: memo is NOT in v1 supported fields
  # ---------------------------------------------------------------------------

  describe "memo exclusion" do
    test "S13: memo field is not supported in v1 and rule using it does not match" do
      txn = transaction("e1", [posting("a1", D.new("-5"))], description: "Uber trip")

      g =
        group(:global, "G", 1, [
          rule("Memo rule", 1, ~s|memo contains "uber"|, [action(:tags, :add, "memo")])
        ])

      [result] = Engine.evaluate([txn], [g])

      # The expression references an unsupported field, so it should fail to compile
      # and be treated as no-match (fail-safe)
      assert result.no_match?
      assert result.proposed_changes == []
    end
  end

  # ---------------------------------------------------------------------------
  # S14: currency_code matched through posting.account.currency_code
  # ---------------------------------------------------------------------------

  describe "currency_code matching" do
    test "S14: currency_code reads from posting.account.currency_code" do
      txn =
        transaction("e1", [
          posting("acct", D.new("-50"), currency_code: "BRL")
        ])

      g =
        group(:global, "G", 1, [
          rule("BRL", 1, ~s|currency_code equals "BRL"|, [action(:tags, :add, "brazil")])
        ])

      [result] = Engine.evaluate([txn], [g])
      refute result.no_match?
      assert change_for(result, :tags).proposed_value == ["brazil"]
    end

    test "S15: currency_code does not match when account has different currency" do
      txn =
        transaction("e1", [
          posting("acct", D.new("-50"), currency_code: "USD")
        ])

      g =
        group(:global, "G", 1, [
          rule("BRL", 1, ~s|currency_code equals "BRL"|, [action(:tags, :add, "brazil")])
        ])

      [result] = Engine.evaluate([txn], [g])
      assert result.no_match?
    end
  end

  # ---------------------------------------------------------------------------
  # S16-S18: First-writer-wins per field across groups
  # ---------------------------------------------------------------------------

  describe "first-writer-wins" do
    test "S16: first group to propose a field wins, later proposals are skipped_claimed" do
      cat_first = Ecto.UUID.generate()
      cat_second = Ecto.UUID.generate()
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      groups = [
        group(:global, "Alpha", 1, [
          rule("A", 1, ~s|description contains "uber"|, [action(:category, :set, cat_first)])
        ]),
        group(:global, "Beta", 2, [
          rule("B", 1, ~s|description contains "uber"|, [action(:category, :set, cat_second)])
        ])
      ]

      [result] = Engine.evaluate([txn], groups)

      assert change_for(result, :category).proposed_value == cat_first
      skipped = change_for(result, :category, :skipped_claimed)
      assert skipped != nil
      assert skipped.reason == :field_claimed
    end

    test "S17: different fields from different groups can all be proposed" do
      cat_id = Ecto.UUID.generate()
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      groups = [
        group(:global, "Alpha", 1, [
          rule("A", 1, ~s|description contains "uber"|, [action(:category, :set, cat_id)])
        ]),
        group(:global, "Beta", 2, [
          rule("B", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")])
        ])
      ]

      [result] = Engine.evaluate([txn], groups)

      assert MapSet.equal?(result.claimed_fields, MapSet.new([:category, :tags]))
      assert Enum.all?(result.proposed_changes, &(&1.status == :proposed))
    end
  end

  # ---------------------------------------------------------------------------
  # S18-S21: Tags add/remove and notes append semantics
  # ---------------------------------------------------------------------------

  describe "tags add/remove semantics" do
    test "S18: add tags without duplicates" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Tags", 1, ~s|description contains "uber"|, [
            action(:tags, :add, "ride"),
            action(:tags, :add, "transport"),
            action(:tags, :add, "ride")
          ])
        ])

      [result] =
        Engine.evaluate([txn], [g], current_classifications: %{txn.id => %{tags: []}})

      assert change_for(result, :tags).proposed_value == ["ride", "transport"]
    end

    test "S19: add to existing tags preserves existing and deduplicates" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Tags", 1, ~s|description contains "uber"|, [
            action(:tags, :add, "ride"),
            action(:tags, :add, "existing")
          ])
        ])

      [result] =
        Engine.evaluate([txn], [g], current_classifications: %{txn.id => %{tags: ["existing"]}})

      assert change_for(result, :tags).proposed_value == ["existing", "ride"]
    end

    test "S20: remove tag from existing set" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Tags", 1, ~s|description contains "uber"|, [
            action(:tags, :remove, "old"),
            action(:tags, :add, "new")
          ])
        ])

      [result] =
        Engine.evaluate([txn], [g],
          current_classifications: %{txn.id => %{tags: ["old", "keep"]}}
        )

      assert change_for(result, :tags).proposed_value == ["keep", "new"]
    end
  end

  describe "notes append semantics" do
    test "S21: append adds newline-separated content" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Notes", 1, ~s|description contains "uber"|, [
            action(:notes, :append, "extra info")
          ])
        ])

      [result] =
        Engine.evaluate([txn], [g], current_classifications: %{txn.id => %{notes: "original"}})

      assert change_for(result, :notes).proposed_value == "original\nextra info"
    end

    test "S22: append to nil/empty notes sets the value directly" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Notes", 1, ~s|description contains "uber"|, [
            action(:notes, :append, "first note")
          ])
        ])

      [result] = Engine.evaluate([txn], [g])

      assert change_for(result, :notes).proposed_value == "first note"
    end

    test "S23: notes set replaces entirely" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Notes", 1, ~s|description contains "uber"|, [
            action(:notes, :set, "overwritten")
          ])
        ])

      [result] =
        Engine.evaluate([txn], [g], current_classifications: %{txn.id => %{notes: "original"}})

      assert change_for(result, :notes).proposed_value == "overwritten"
    end
  end

  # ---------------------------------------------------------------------------
  # S24-S26: Protected / manual override semantics
  # ---------------------------------------------------------------------------

  describe "protected fields" do
    test "S24: protected fields are marked as protected and currently_overridden" do
      cat_id = Ecto.UUID.generate()
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("R", 1, ~s|description contains "uber"|, [
            action(:category, :set, cat_id),
            action(:tags, :add, "ride")
          ])
        ])

      [result] =
        Engine.evaluate([txn], [g],
          current_classifications: %{
            txn.id => %{protected_fields: [:category]}
          }
        )

      cat_change = change_for(result, :category, :protected)
      assert cat_change != nil
      assert cat_change.currently_overridden? == true

      # Tags are not protected, so they are proposed
      tag_change = change_for(result, :tags)
      assert tag_change.status == :proposed
    end

    test "S25: protected_fields accepts MapSet" do
      cat_id = Ecto.UUID.generate()
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("R", 1, ~s|description contains "uber"|, [
            action(:category, :set, cat_id)
          ])
        ])

      [result] =
        Engine.evaluate([txn], [g],
          current_classifications: %{
            txn.id => %{protected_fields: MapSet.new([:category])}
          }
        )

      assert change_for(result, :category, :protected) != nil
    end
  end

  # ---------------------------------------------------------------------------
  # S26-S28: Fail-safe behavior
  # ---------------------------------------------------------------------------

  describe "fail-safe behavior" do
    test "S26: invalid expression does not crash; other groups still evaluate" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      groups = [
        group(:global, "Bad", 1, [
          rule("Broken", 1, ~s|memo contains "uber"|, [action(:tags, :add, "broken")])
        ]),
        group(:global, "Good", 2, [
          rule("Works", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")])
        ])
      ]

      [result] = Engine.evaluate([txn], groups)

      assert Enum.map(result.matched_groups, & &1.rule_group.name) == ["Good"]
      assert change_for(result, :tags).proposed_value == ["ride"]
    end

    test "S27: invalid action payload produces :invalid status without crash" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      # category set requires a valid UUID; "not-a-uuid" should fail
      g =
        group(:global, "G", 1, [
          rule("Bad category", 1, ~s|description contains "uber"|, [
            action(:category, :set, "not-a-uuid"),
            action(:tags, :add, "ride")
          ])
        ])

      [result] = Engine.evaluate([txn], [g])

      cat_change = change_for(result, :category, :invalid)
      assert cat_change != nil
      assert cat_change.reason == :invalid_category_value

      # Tags should still be proposed despite the category being invalid
      assert change_for(result, :tags).status == :proposed
    end

    test "S28: empty tag value produces :invalid status" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Bad tag", 1, ~s|description contains "uber"|, [
            action(:tags, :add, "   ")
          ])
        ])

      [result] = Engine.evaluate([txn], [g])

      tag_change = Enum.find(result.proposed_changes, &(&1.field == :tags))
      assert tag_change.status == :invalid
      assert tag_change.reason == :invalid_tag_value
    end
  end

  # ---------------------------------------------------------------------------
  # S29-S30: No-match and empty inputs
  # ---------------------------------------------------------------------------

  describe "no-match and empty inputs" do
    test "S29: no_match? is true when no rule matches" do
      txn = transaction("e1", [posting("a1", D.new("-5"))], description: "Grocery store")

      g =
        group(:global, "G", 1, [
          rule("Uber", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")])
        ])

      [result] = Engine.evaluate([txn], [g])
      assert result.no_match?
      assert result.matched_rules == []
      assert result.proposed_changes == []
    end

    test "S30: empty transactions returns empty results" do
      assert Engine.evaluate([], []) == []
    end

    test "S31: transactions with no matching groups still produce results" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      # Entity group for a different entity
      g =
        group(
          :entity,
          "Other",
          1,
          [
            rule("R", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")])
          ],
          entity_id: "other-entity"
        )

      [result] = Engine.evaluate([txn], [g])
      assert result.no_match?
    end
  end

  # ---------------------------------------------------------------------------
  # S32-S33: Category action / investment_type
  # ---------------------------------------------------------------------------

  describe "category and investment_type actions" do
    test "S32: category values are UUID strings" do
      cat_id = Ecto.UUID.generate()
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Cat", 1, ~s|description contains "uber"|, [action(:category, :set, cat_id)])
        ])

      [result] = Engine.evaluate([txn], [g])
      assert change_for(result, :category).proposed_value == cat_id
    end

    test "S33: investment_type set works with valid string" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Inv", 1, ~s|description contains "uber"|, [
            action(:investment_type, :set, "etf")
          ])
        ])

      [result] = Engine.evaluate([txn], [g])
      assert change_for(result, :investment_type).proposed_value == "etf"
    end

    test "S34: investment_type rejects blank value" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("Inv", 1, ~s|description contains "uber"|, [
            action(:investment_type, :set, "   ")
          ])
        ])

      [result] = Engine.evaluate([txn], [g])
      inv_change = Enum.find(result.proposed_changes, &(&1.field == :investment_type))
      assert inv_change.status == :invalid
    end
  end

  # ---------------------------------------------------------------------------
  # S35: Multiple transactions
  # ---------------------------------------------------------------------------

  describe "multiple transactions" do
    test "S35: each transaction is evaluated independently" do
      txn1 = transaction("e1", [posting("a1", D.new("-5"))], description: "Uber trip")
      txn2 = transaction("e1", [posting("a1", D.new("-5"))], description: "Grocery store")

      g =
        group(:global, "G", 1, [
          rule("Uber", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")])
        ])

      [r1, r2] = Engine.evaluate([txn1, txn2], [g])

      refute r1.no_match?
      assert r2.no_match?
    end
  end

  # ---------------------------------------------------------------------------
  # S36: Result struct shape
  # ---------------------------------------------------------------------------

  describe "result struct" do
    test "S36: result contains transaction, matched data, and claimed fields" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("R", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")])
        ])

      [%Result{} = result] = Engine.evaluate([txn], [g])

      assert result.transaction == txn
      assert is_list(result.matched_groups)
      assert is_list(result.matched_rules)
      assert is_list(result.proposed_changes)
      assert %MapSet{} = result.claimed_fields
      assert is_boolean(result.no_match?)
    end

    test "S37: proposed_change struct has all required fields" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      g =
        group(:global, "G", 1, [
          rule("R", 1, ~s|description contains "uber"|, [action(:tags, :add, "ride")])
        ])

      [result] = Engine.evaluate([txn], [g])
      [%ProposedChange{} = change] = result.proposed_changes

      assert change.field == :tags
      assert change.status == :proposed
      assert change.proposed_value == ["ride"]
      assert %RuleGroup{} = change.rule_group
      assert %Rule{} = change.rule
      assert is_list(change.actions)
    end
  end

  # ---------------------------------------------------------------------------
  # S38: Unsupported action field is ignored
  # ---------------------------------------------------------------------------

  describe "unsupported action fields" do
    test "S38: action with unknown field is ignored" do
      txn = transaction("e1", [posting("a1", D.new("-5"))])

      # Manually construct a rule action with an unsupported field
      g =
        group(:global, "G", 1, [
          %Rule{
            id: Ecto.UUID.generate(),
            name: "R",
            position: 1,
            expression: ~s|description contains "uber"|,
            is_active: true,
            stop_processing: true,
            actions: [
              %RuleAction{field: :tags, operation: :add, value: "ride"},
              # Simulate an unknown field stored as string
              %RuleAction{field: nil, operation: :set, value: "bad"}
            ]
          }
        ])

      [result] = Engine.evaluate([txn], [g])

      # Only the valid tags action should produce a proposed change
      assert length(result.proposed_changes) == 1
      assert change_for(result, :tags).proposed_value == ["ride"]
    end
  end
end
