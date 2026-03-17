defmodule AurumFinance.Classification.PreviewTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.Factory

  alias AurumFinance.Classification
  alias AurumFinance.Classification.Engine.Result
  alias AurumFinance.Ledger

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_transaction(entity, account, opts) do
    date = Keyword.get(opts, :date, ~D[2026-03-14])
    description = Keyword.get(opts, :description, "Uber trip")
    amount = Keyword.get(opts, :amount, "-10.00")

    # Double-entry: needs a contra account for balanced postings
    contra_account =
      case Keyword.get(opts, :contra_account) do
        nil ->
          insert_account(entity, %{
            name: "Contra Expense",
            account_type: :expense,
            management_group: :category,
            operational_subtype: nil,
            institution_name: nil,
            institution_account_ref: nil
          })

        acct ->
          acct
      end

    {:ok, txn} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: date,
        description: description,
        source_type: :manual,
        postings: [
          %{account_id: account.id, amount: amount},
          %{account_id: contra_account.id, amount: negate_amount(amount)}
        ]
      })

    txn
  end

  defp negate_amount(amount) when is_binary(amount) do
    amount
    |> Decimal.new()
    |> Decimal.negate()
    |> Decimal.to_string()
  end

  # ---------------------------------------------------------------------------
  # S39-S40: Entity scoping and date-range filtering
  # ---------------------------------------------------------------------------

  describe "preview_classification/1 entity scoping and date range" do
    test "S39: only returns transactions for the specified entity" do
      entity = insert_entity()
      other_entity = insert_entity()
      account = insert_account(entity)
      other_account = insert_account(other_entity)

      _txn = create_transaction(entity, account, description: "Uber trip")
      _other_txn = create_transaction(other_entity, other_account, description: "Uber trip")

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert length(results) == 1
      assert hd(results).transaction.entity_id == entity.id
    end

    test "S40: only returns transactions within the date range" do
      entity = insert_entity()
      account = insert_account(entity)

      _in_range = create_transaction(entity, account, date: ~D[2026-03-15], description: "Uber")
      _before = create_transaction(entity, account, date: ~D[2026-02-28], description: "Uber")
      _after = create_transaction(entity, account, date: ~D[2026-04-01], description: "Uber")

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert length(results) == 1
      assert hd(results).transaction.date == ~D[2026-03-15]
    end

    test "S41: empty date range returns empty list" do
      entity = insert_entity()
      account = insert_account(entity)
      _txn = create_transaction(entity, account, date: ~D[2026-06-15])

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert results == []
    end

    test "S42: voided transactions are excluded from preview" do
      entity = insert_entity()
      account = insert_account(entity)
      txn = create_transaction(entity, account, description: "Uber trip")

      # Reload full transaction to void it
      loaded_txn = Ledger.get_transaction!(entity.id, txn.id)
      {:ok, _voided} = Ledger.void_transaction(loaded_txn)

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      # The voided transaction is excluded; a reversal transaction may exist
      # but the original voided one must not appear
      voided_txn_ids = Enum.map(results, & &1.transaction.id)
      refute txn.id in voided_txn_ids

      # All returned transactions must have voided_at == nil
      Enum.each(results, fn result ->
        assert is_nil(result.transaction.voided_at)
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # S43-S44: Rule group loading for preview
  # ---------------------------------------------------------------------------

  describe "preview_classification/1 rule group loading" do
    test "S43: loads global + entity + account-scoped groups" do
      entity = insert_entity()
      account = insert_account(entity)

      _global_group =
        insert_global_rule_group(%{name: "Global Rules"})

      _entity_group =
        insert_rule_group(entity, %{name: "Entity Rules"})

      _account_group =
        insert_account_rule_group(account, %{name: "Account Rules"})

      # Create a rule in each group that matches
      insert_rule(
        Classification.get_rule_group!(
          hd(Classification.list_rule_groups(scope_type: :global)).id
        ),
        %{
          name: "Global Rule",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :tags, operation: :add, value: "global"}]
        }
      )

      entity_groups = Classification.list_rule_groups(scope_type: :entity, entity_id: entity.id)

      insert_rule(
        Classification.get_rule_group!(hd(entity_groups).id),
        %{
          name: "Entity Rule",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :notes, operation: :set, value: "entity"}]
        }
      )

      account_groups =
        Classification.list_rule_groups(scope_type: :account, account_id: account.id)

      insert_rule(
        Classification.get_rule_group!(hd(account_groups).id),
        %{
          name: "Account Rule",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :investment_type, operation: :set, value: "etf"}]
        }
      )

      _txn = create_transaction(entity, account, description: "Uber trip")

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert [%Result{} = result] = results
      refute result.no_match?

      group_names = Enum.map(result.matched_groups, & &1.rule_group.name)
      # Account first, then entity, then global (scope precedence)
      assert "Account Rules" in group_names
      assert "Entity Rules" in group_names
      assert "Global Rules" in group_names
      assert hd(group_names) == "Account Rules"
    end

    test "S44: does not load groups from a different entity" do
      entity = insert_entity()
      other_entity = insert_entity()
      account = insert_account(entity)

      _other_group =
        insert_rule_group(other_entity, %{name: "Other Entity Rules"})

      insert_rule(
        Classification.get_rule_group!(
          hd(Classification.list_rule_groups(entity_id: other_entity.id)).id
        ),
        %{
          name: "Other Rule",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :tags, operation: :add, value: "other"}]
        }
      )

      _txn = create_transaction(entity, account, description: "Uber trip")

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert [%Result{} = result] = results
      # The other entity's group should not match
      assert result.no_match?
    end
  end

  # ---------------------------------------------------------------------------
  # S45-S47: No-match, matched rows, protected indicators
  # ---------------------------------------------------------------------------

  describe "preview_classification/1 result states" do
    test "S45: no-match rows have no_match? true" do
      entity = insert_entity()
      account = insert_account(entity)

      insert_global_rule_group(%{name: "Rules"})

      insert_rule(
        Classification.get_rule_group!(
          hd(Classification.list_rule_groups(scope_type: :global)).id
        ),
        %{
          name: "Uber only",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :tags, operation: :add, value: "ride"}]
        }
      )

      _non_matching = create_transaction(entity, account, description: "Grocery store")

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert [%Result{no_match?: true}] = results
    end

    test "S46: matched rows have no_match? false and proposed_changes" do
      entity = insert_entity()
      account = insert_account(entity)

      insert_global_rule_group(%{name: "Rules"})

      insert_rule(
        Classification.get_rule_group!(
          hd(Classification.list_rule_groups(scope_type: :global)).id
        ),
        %{
          name: "Uber",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :tags, operation: :add, value: "ride"}]
        }
      )

      _txn = create_transaction(entity, account, description: "Uber trip")

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert [%Result{no_match?: false} = result] = results
      assert result.proposed_changes != []
      assert hd(result.proposed_changes).status == :proposed
    end

    # The context now loads persisted ClassificationRecords during preview.
    # This engine-level test still verifies the protected-field contract
    # directly, independent of the DB-backed integration coverage.
    test "S47: protected indicators are surfaced when current_classifications provided" do
      alias AurumFinance.Classification.Engine

      txn_id = Ecto.UUID.generate()

      txn = %AurumFinance.Ledger.Transaction{
        id: txn_id,
        entity_id: "e1",
        date: ~D[2026-03-14],
        description: "Uber trip",
        source_type: :manual,
        postings: [
          %AurumFinance.Ledger.Posting{
            account_id: "a1",
            amount: Decimal.new("-10"),
            account: %AurumFinance.Ledger.Account{
              id: "a1",
              currency_code: "USD",
              name: "Checking",
              account_type: :asset,
              institution_name: "Bank"
            }
          }
        ]
      }

      g = %AurumFinance.Classification.RuleGroup{
        id: Ecto.UUID.generate(),
        scope_type: :global,
        name: "G",
        priority: 1,
        is_active: true,
        rules: [
          %AurumFinance.Classification.Rule{
            id: Ecto.UUID.generate(),
            name: "R",
            position: 1,
            expression: ~s|description contains "uber"|,
            is_active: true,
            stop_processing: true,
            actions: [
              %AurumFinance.Classification.RuleAction{
                field: :category,
                operation: :set,
                value: Ecto.UUID.generate()
              },
              %AurumFinance.Classification.RuleAction{
                field: :tags,
                operation: :add,
                value: "ride"
              }
            ]
          }
        ]
      }

      [result] =
        Engine.evaluate([txn], [g],
          current_classifications: %{
            txn_id => %{protected_fields: [:category]}
          }
        )

      cat_change =
        Enum.find(result.proposed_changes, &(&1.field == :category and &1.status == :protected))

      assert cat_change != nil
      assert cat_change.currently_overridden? == true

      tag_change =
        Enum.find(result.proposed_changes, &(&1.field == :tags and &1.status == :proposed))

      assert tag_change != nil
    end
  end

  # ---------------------------------------------------------------------------
  # S48: No DB writes during preview
  # ---------------------------------------------------------------------------

  describe "preview_classification/1 no writes" do
    test "S48: preview does not write to any table" do
      entity = insert_entity()
      account = insert_account(entity)

      insert_global_rule_group(%{name: "Preview Rules"})

      insert_rule(
        Classification.get_rule_group!(
          hd(Classification.list_rule_groups(scope_type: :global)).id
        ),
        %{
          name: "Uber",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :tags, operation: :add, value: "ride"}]
        }
      )

      _txn = create_transaction(entity, account, description: "Uber trip")

      # Count rows in key tables before preview
      txn_count_before = Repo.aggregate(AurumFinance.Ledger.Transaction, :count, :id)

      rule_group_count_before =
        Repo.aggregate(AurumFinance.Classification.RuleGroup, :count, :id)

      rule_count_before = Repo.aggregate(AurumFinance.Classification.Rule, :count, :id)

      _results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      # Assert counts are unchanged
      assert Repo.aggregate(AurumFinance.Ledger.Transaction, :count, :id) == txn_count_before

      assert Repo.aggregate(AurumFinance.Classification.RuleGroup, :count, :id) ==
               rule_group_count_before

      assert Repo.aggregate(AurumFinance.Classification.Rule, :count, :id) == rule_count_before
    end
  end

  # ---------------------------------------------------------------------------
  # S49: Inactive groups excluded from preview
  # ---------------------------------------------------------------------------

  describe "preview_classification/1 active filtering" do
    test "S49: inactive groups are excluded from preview results" do
      entity = insert_entity()
      account = insert_account(entity)

      insert_global_rule_group(%{name: "Active Group", is_active: true})

      insert_rule(
        Classification.get_rule_group!(
          hd(Classification.list_rule_groups(scope_type: :global, is_active: true)).id
        ),
        %{
          name: "Active Rule",
          expression: ~s|description contains "uber"|,
          actions: [%{field: :tags, operation: :add, value: "active"}]
        }
      )

      insert_global_rule_group(%{name: "Inactive Group", is_active: false})

      _txn = create_transaction(entity, account, description: "Uber trip")

      results =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      assert [%Result{} = result] = results

      group_names = Enum.map(result.matched_groups, & &1.rule_group.name)
      assert "Active Group" in group_names
      refute "Inactive Group" in group_names
    end
  end
end
