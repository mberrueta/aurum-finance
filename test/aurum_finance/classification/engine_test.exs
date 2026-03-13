defmodule AurumFinance.Classification.EngineTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Classification.Engine
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleAction
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias Decimal, as: D

  describe "evaluate/3" do
    test "uses scope precedence and first-writer-wins per field" do
      transaction =
        transaction_fixture("entity-1", [
          posting_fixture("account-1", "USD", "Card", :asset, D.new("-12.50"))
        ])

      global_group =
        rule_group_fixture(:global, "Global", 1, [
          rule_fixture("Global Uber", 1, ~s|description contains "uber"|, [
            action_fixture(:category, :set, Ecto.UUID.generate())
          ])
        ])

      entity_group =
        rule_group_fixture(:entity, "Entity", 1, [
          rule_fixture("Entity Uber", 1, ~s|description contains "uber"|, [
            action_fixture(:tags, :add, "ride")
          ])
        ])
        |> Map.put(:entity_id, "entity-1")

      winning_category = Ecto.UUID.generate()

      account_group =
        rule_group_fixture(:account, "Account", 1, [
          rule_fixture("Account Uber", 1, ~s|description contains "uber"|, [
            action_fixture(:category, :set, winning_category)
          ])
        ])
        |> Map.put(:account_id, "account-1")

      [result] = Engine.evaluate([transaction], [global_group, entity_group, account_group])

      assert result.no_match? == false

      assert Enum.map(result.matched_groups, & &1.rule_group.name) == [
               "Account",
               "Entity",
               "Global"
             ]

      assert MapSet.equal?(result.claimed_fields, MapSet.new([:category, :tags]))

      assert [
               %{field: :category, status: :proposed, proposed_value: ^winning_category},
               %{field: :tags, status: :proposed, proposed_value: ["ride"]},
               %{field: :category, status: :skipped_claimed}
             ] = result.proposed_changes
    end

    test "treats string operators as case-insensitive" do
      transaction =
        transaction_fixture("entity-1", [
          posting_fixture("account-1", "USD", "Card", :asset, D.new("-12.50"))
        ])

      rule_group =
        rule_group_fixture(:global, "Global", 1, [
          rule_fixture("Uber", 1, ~s|description contains "uber"|, [
            action_fixture(:tags, :add, "ride")
          ])
        ])

      [result] = Engine.evaluate([transaction], [rule_group])

      assert [%{field: :tags, status: :proposed, proposed_value: ["ride"]}] =
               result.proposed_changes
    end

    test "honors stop_processing inside one group" do
      transaction =
        transaction_fixture("entity-1", [
          posting_fixture("account-1", "USD", "Card", :asset, D.new("-12.50"))
        ])

      rule_group =
        rule_group_fixture(:global, "Global", 1, [
          rule_fixture("First", 1, ~s|description contains "uber"|, [
            action_fixture(:tags, :add, "first")
          ]),
          rule_fixture("Second", 2, ~s|description contains "uber"|, [
            action_fixture(:notes, :set, "second")
          ])
        ])

      [result] = Engine.evaluate([transaction], [rule_group])

      assert Enum.map(result.matched_rules, & &1.name) == ["First"]
      assert [%{field: :tags, proposed_value: ["first"]}] = result.proposed_changes
    end

    test "surfaces protected fields and applies tags and notes deterministically" do
      category_id = Ecto.UUID.generate()

      transaction =
        transaction_fixture("entity-1", [
          posting_fixture("account-1", "USD", "Card", :asset, D.new("-12.50"))
        ])

      rule_group =
        rule_group_fixture(:global, "Global", 1, [
          rule_fixture("Uber", 1, ~s|description contains "uber"|, [
            action_fixture(:category, :set, category_id),
            action_fixture(:tags, :add, "ride"),
            action_fixture(:tags, :add, "existing"),
            action_fixture(:notes, :append, "extra")
          ])
        ])

      [result] =
        Engine.evaluate([transaction], [rule_group],
          current_classifications: %{
            transaction.id => %{
              tags: ["existing"],
              notes: "base",
              protected_fields: [:category]
            }
          }
        )

      assert [
               %{field: :category, status: :protected, currently_overridden?: true},
               %{field: :tags, status: :proposed, proposed_value: ["existing", "ride"]},
               %{field: :notes, status: :proposed, proposed_value: "base\nextra"}
             ] = result.proposed_changes
    end

    test "fails safe for invalid expressions" do
      transaction =
        transaction_fixture("entity-1", [
          posting_fixture("account-1", "USD", "Card", :asset, D.new("-12.50"))
        ])

      invalid_group =
        rule_group_fixture(:global, "Invalid", 1, [
          rule_fixture("Broken", 1, ~s|memo contains "uber"|, [
            action_fixture(:tags, :add, "broken")
          ])
        ])

      valid_group =
        rule_group_fixture(:global, "Valid", 2, [
          rule_fixture("Working", 1, ~s|description contains "uber"|, [
            action_fixture(:tags, :add, "ride")
          ])
        ])

      [result] = Engine.evaluate([transaction], [invalid_group, valid_group])

      assert Enum.map(result.matched_groups, & &1.rule_group.name) == ["Valid"]
      assert [%{field: :tags, proposed_value: ["ride"]}] = result.proposed_changes
    end
  end

  defp transaction_fixture(entity_id, postings) do
    %Transaction{
      id: Ecto.UUID.generate(),
      entity_id: entity_id,
      date: ~D[2026-03-13],
      description: "Uber trip",
      source_type: :import,
      postings: postings
    }
  end

  defp posting_fixture(account_id, currency_code, account_name, account_type, amount) do
    %Posting{
      account_id: account_id,
      amount: amount,
      account: %Account{
        id: account_id,
        currency_code: currency_code,
        name: account_name,
        account_type: account_type,
        institution_name: "Bank"
      }
    }
  end

  defp rule_group_fixture(scope_type, name, priority, rules) do
    %RuleGroup{
      id: Ecto.UUID.generate(),
      scope_type: scope_type,
      name: name,
      priority: priority,
      is_active: true,
      rules: rules
    }
  end

  defp rule_fixture(name, position, expression, actions) do
    %Rule{
      id: Ecto.UUID.generate(),
      name: name,
      position: position,
      expression: expression,
      is_active: true,
      stop_processing: true,
      actions: actions
    }
  end

  defp action_fixture(field, operation, value) do
    %RuleAction{field: field, operation: operation, value: value}
  end
end
