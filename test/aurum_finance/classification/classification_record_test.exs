defmodule AurumFinance.Classification.ClassificationRecordTest do
  use AurumFinance.DataCase, async: true

  import AurumFinance.Factory

  alias AurumFinance.Audit
  alias AurumFinance.Classification
  alias AurumFinance.Classification.ClassificationRecord
  alias AurumFinance.Classification.Engine.ProposedChange
  alias AurumFinance.Ledger

  describe "ClassificationRecord.changeset/2" do
    test "S01: validates required fields and field length constraints" do
      changeset =
        ClassificationRecord.changeset(%ClassificationRecord{}, %{
          tags: Enum.map(1..20, &"tag-#{&1}") ++ [String.duplicate("x", 51)],
          notes: String.duplicate("n", 2001)
        })

      errors = errors_on(changeset)

      assert translated_error("error_field_required") in errors.transaction_id
      assert translated_error("error_field_required") in errors.entity_id
      assert translated_error("error_classification_tags_too_many") in errors.tags
      assert translated_error("error_classification_tag_length_invalid") in errors.tags
      assert translated_error("error_classification_notes_length_invalid") in errors.notes
    end

    test "S01: enforces one classification record per transaction" do
      entity = insert_entity()
      account = insert_account(entity)
      transaction = create_transaction(entity, account)

      insert_classification_record(transaction)

      assert {:error, changeset} =
               %ClassificationRecord{}
               |> ClassificationRecord.changeset(%{
                 transaction_id: transaction.id,
                 entity_id: entity.id,
                 tags: []
               })
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).transaction_id
    end
  end

  describe "get_classification_record/1" do
    test "S02: returns nil when no record exists" do
      assert Classification.get_classification_record(Ecto.UUID.generate()) == nil
    end

    test "S02: lists multiple classification records with category accounts preloaded" do
      entity = insert_entity()
      account = insert_account(entity)
      groceries = insert_category_account(entity, "Groceries")
      fuel = insert_category_account(entity, "Fuel")
      transaction_a = create_transaction(entity, account, description: "Groceries run")
      transaction_b = create_transaction(entity, account, description: "Fuel stop")

      record_a =
        insert_classification_record(transaction_a, %{
          category_account_id: groceries.id,
          tags: ["food"]
        })

      record_b =
        insert_classification_record(transaction_b, %{
          category_account_id: fuel.id,
          tags: ["car"]
        })

      records =
        Classification.list_classification_records([
          transaction_a.id,
          transaction_b.id
        ])

      records_by_transaction_id = Map.new(records, &{&1.transaction_id, &1})

      assert Map.keys(records_by_transaction_id) |> Enum.sort() ==
               Enum.sort([transaction_a.id, transaction_b.id])

      assert records_by_transaction_id[transaction_a.id].id == record_a.id
      assert records_by_transaction_id[transaction_a.id].category_account.name == "Groceries"
      assert records_by_transaction_id[transaction_b.id].id == record_b.id
      assert records_by_transaction_id[transaction_b.id].category_account.name == "Fuel"
    end
  end

  describe "classify_transaction/2" do
    test "S03: creates a classification record with rule provenance and audit metadata" do
      entity = insert_entity()
      account = insert_account(entity)
      transport = insert_category_account(entity, "Transport")

      {rule_group, rule} =
        insert_matching_rule(
          :global,
          nil,
          [
            %{field: :category, operation: :set, value: transport.id},
            %{field: :tags, operation: :add, value: "ride"}
          ],
          group_name: "Global Defaults"
        )

      transaction = create_transaction(entity, account)

      assert {:ok, result} =
               Classification.classify_transaction(
                 transaction.id,
                 entity_id: entity.id,
                 actor: "qa-apply",
                 channel: :ai_assistant
               )

      assert result.classified?
      assert result.fields_applied == 2
      assert result.fields_skipped_manual == 0
      refute result.no_match?

      classification_record = result.classification_record

      assert classification_record.category_account_id == transport.id
      assert classification_record.tags == ["ride"]
      assert classification_record.category_classified_by["source"] == "rule"
      assert classification_record.category_classified_by["rule_group_id"] == rule_group.id
      assert classification_record.category_classified_by["rule_id"] == rule.id
      assert is_binary(classification_record.category_classified_by["classified_at"])
      assert classification_record.tags_classified_by["source"] == "rule"
      assert classification_record.tags_classified_by["rule_group_id"] == rule_group.id
      assert classification_record.tags_classified_by["rule_id"] == rule.id

      events = audit_events_for(classification_record)
      assert Enum.count(events, &(&1.action == "rule_applied")) == 2

      category_event = find_event(events, "rule_applied", :category)
      assert category_event.actor == "qa-apply"
      assert category_event.channel == :ai_assistant
      assert category_event.before == nil
      assert category_event.metadata["old_value"] == nil
      assert category_event.metadata["new_value"] == transport.id
      assert category_event.metadata["rule_group_id"] == rule_group.id
      assert category_event.metadata["rule_id"] == rule.id
      assert category_event.after["category_account_id"] == transport.id

      tags_event = find_event(events, "rule_applied", :tags)
      assert tags_event.metadata["old_value"] == "[]"
      assert tags_event.metadata["new_value"] == "[\"ride\"]"
      assert tags_event.metadata["rule_group_id"] == rule_group.id
      assert tags_event.metadata["rule_id"] == rule.id
      assert tags_event.after["tags"] == ["ride"]
    end

    test "S04: updates an existing unlocked classification record in place" do
      entity = insert_entity()
      account = insert_account(entity)
      food = insert_category_account(entity, "Food")
      transport = insert_category_account(entity, "Transport")
      transaction = create_transaction(entity, account)

      existing_record =
        insert_classification_record(transaction, %{
          category_account_id: food.id,
          category_classified_by: %{"source" => "user"},
          tags: ["existing"],
          tags_classified_by: %{"source" => "user"},
          investment_type: "legacy",
          investment_type_classified_by: %{"source" => "user"},
          notes: "legacy note",
          notes_classified_by: %{"source" => "user"}
        })

      {rule_group, rule} =
        insert_matching_rule(
          :global,
          nil,
          [
            %{field: :category, operation: :set, value: transport.id},
            %{field: :tags, operation: :add, value: "ride"},
            %{field: :investment_type, operation: :set, value: "expense"},
            %{field: :notes, operation: :set, value: "updated by rule"}
          ],
          group_name: "Unlocked Updates"
        )

      assert {:ok, result} =
               Classification.classify_transaction(
                 transaction.id,
                 entity_id: entity.id,
                 actor: "qa-update",
                 channel: :mcp
               )

      assert result.classified?
      assert result.fields_applied == 4
      assert result.fields_skipped_manual == 0
      refute result.no_match?
      assert result.classification_record.id == existing_record.id

      classification_record = result.classification_record

      assert classification_record.category_account_id == transport.id
      assert classification_record.tags == ["existing", "ride"]
      assert classification_record.investment_type == "expense"
      assert classification_record.notes == "updated by rule"
      refute classification_record.category_manually_overridden
      refute classification_record.tags_manually_overridden
      refute classification_record.investment_type_manually_overridden
      refute classification_record.notes_manually_overridden

      assert classification_record.category_classified_by["rule_group_id"] == rule_group.id
      assert classification_record.category_classified_by["rule_id"] == rule.id
      assert classification_record.tags_classified_by["rule_group_id"] == rule_group.id
      assert classification_record.tags_classified_by["rule_id"] == rule.id
      assert classification_record.investment_type_classified_by["rule_group_id"] == rule_group.id
      assert classification_record.investment_type_classified_by["rule_id"] == rule.id
      assert classification_record.notes_classified_by["rule_group_id"] == rule_group.id
      assert classification_record.notes_classified_by["rule_id"] == rule.id

      events = audit_events_for(classification_record)
      assert Enum.count(events, &(&1.action == "rule_applied")) == 4

      category_event = find_event(events, "rule_applied", :category)
      assert category_event.before["category_account_id"] == food.id
      assert category_event.after["category_account_id"] == transport.id
      assert category_event.metadata["old_value"] == food.id
      assert category_event.metadata["new_value"] == transport.id
      assert category_event.metadata["rule_group_id"] == rule_group.id
      assert category_event.metadata["rule_id"] == rule.id

      notes_event = find_event(events, "rule_applied", :notes)
      assert notes_event.before["notes"] == "legacy note"
      assert notes_event.after["notes"] == "updated by rule"
      assert notes_event.metadata["old_value"] == "legacy note"
      assert notes_event.metadata["new_value"] == "updated by rule"
    end

    test "S07: applies account-scoped rules before entity and global groups" do
      entity = insert_entity()
      account = insert_account(entity)
      transaction = create_transaction(entity, account, description: "Uber commute")
      global_category = insert_category_account(entity, "Global Category")
      entity_category = insert_category_account(entity, "Entity Category")
      account_category = insert_category_account(entity, "Account Category")

      {_global_group, _global_rule} =
        insert_matching_rule(
          :global,
          nil,
          [%{field: :category, operation: :set, value: global_category.id}],
          group_name: "Global Winner If Ordered Wrong",
          priority: 1
        )

      {_entity_group, _entity_rule} =
        insert_matching_rule(
          :entity,
          entity,
          [%{field: :category, operation: :set, value: entity_category.id}],
          group_name: "Entity Winner If Scope Ignored",
          priority: 2
        )

      {account_group, account_rule} =
        insert_matching_rule(
          :account,
          account,
          [%{field: :category, operation: :set, value: account_category.id}],
          group_name: "Account Scope Wins",
          priority: 99
        )

      assert {:ok, result} =
               Classification.classify_transaction(transaction.id, entity_id: entity.id)

      assert result.classification_record.category_account_id == account_category.id
      assert result.fields_applied == 1
      refute result.no_match?

      assert result.classification_record.category_classified_by == %{
               "source" => "rule",
               "rule_group_id" => account_group.id,
               "rule_id" => account_rule.id,
               "classified_at" =>
                 result.classification_record.category_classified_by["classified_at"]
             }
    end

    test "S11: keeps historical provenance usable after the source rule and group are deleted" do
      entity = insert_entity()
      account = insert_account(entity)
      transport = insert_category_account(entity, "Transport")
      transaction = create_transaction(entity, account)

      {rule_group, rule} =
        insert_matching_rule(
          :global,
          nil,
          [%{field: :category, operation: :set, value: transport.id}],
          group_name: "Historical Provenance"
        )

      assert {:ok, applied} =
               Classification.classify_transaction(transaction.id, entity_id: entity.id)

      assert applied.classification_record.category_classified_by["rule_group_id"] ==
               rule_group.id

      assert applied.classification_record.category_classified_by["rule_id"] == rule.id

      assert {:ok, _deleted_rule} = Classification.delete_rule(rule)
      assert {:ok, _deleted_group} = Classification.delete_rule_group(rule_group)

      persisted_record = Classification.get_classification_record(transaction.id)

      assert persisted_record.category_classified_by["rule_group_id"] == rule_group.id
      assert persisted_record.category_classified_by["rule_id"] == rule.id

      assert {:ok, replay_result} =
               Classification.classify_transaction(transaction.id, entity_id: entity.id)

      assert replay_result.classification_record.id == persisted_record.id
      assert replay_result.fields_applied == 0
      assert replay_result.no_match?
    end
  end

  describe "classify_transactions/1" do
    test "S05: returns summary counts and skips only manually protected fields" do
      entity = insert_entity()
      account = insert_account(entity)
      transport = insert_category_account(entity, "Transport")
      food = insert_category_account(entity, "Food")

      insert_matching_rule(
        :global,
        nil,
        [
          %{field: :category, operation: :set, value: transport.id},
          %{field: :tags, operation: :add, value: "ride"},
          %{field: :notes, operation: :set, value: "matched by rule"}
        ]
      )

      matching_transaction = create_transaction(entity, account, description: "Uber dinner ride")

      _non_matching_transaction =
        create_transaction(entity, account, description: "Grocery store")

      insert_classification_record(matching_transaction, %{
        category_account_id: food.id,
        category_classified_by: %{"source" => "user"},
        category_manually_overridden: true,
        tags: []
      })

      assert {:ok, summary} =
               Classification.classify_transactions(%{
                 entity_id: entity.id,
                 date_from: ~D[2026-03-01],
                 date_to: ~D[2026-03-31]
               })

      assert summary.classified == 1
      assert summary.fields_applied == 2
      assert summary.fields_skipped_manual == 1
      assert summary.no_match == 1
      assert summary.failed == 0
      assert summary.failures == []

      classification_record = Classification.get_classification_record(matching_transaction.id)

      assert classification_record.category_account_id == food.id
      assert classification_record.tags == ["ride"]
      assert classification_record.notes == "matched by rule"
      assert classification_record.tags_classified_by["source"] == "rule"
      assert classification_record.notes_classified_by["source"] == "rule"
      assert classification_record.category_classified_by["source"] == "user"
    end

    test "S06: reports failed transactions without rolling back successful applies" do
      entity = insert_entity()
      account = insert_account(entity)

      insert_matching_rule(
        :global,
        nil,
        [%{field: :tags, operation: :add, value: "overflow"}],
        group_name: "Overflow Tags"
      )

      successful_transaction =
        create_transaction(entity, account, description: "Uber airport ride")

      failing_transaction = create_transaction(entity, account, description: "Uber office ride")

      original_tags = Enum.map(1..20, &"tag-#{&1}")

      insert_classification_record(failing_transaction, %{
        tags: original_tags,
        tags_classified_by: %{"source" => "user"}
      })

      assert {:ok, summary} =
               Classification.classify_transactions(%{
                 entity_id: entity.id,
                 date_from: ~D[2026-03-01],
                 date_to: ~D[2026-03-31]
               })

      assert summary.classified == 1
      assert summary.fields_applied == 1
      assert summary.fields_skipped_manual == 0
      assert summary.no_match == 0
      assert summary.failed == 1
      assert [%{transaction_id: failing_id, reason: reason}] = summary.failures
      assert failing_id == failing_transaction.id
      assert is_binary(reason)
      refute reason == ""

      assert Classification.get_classification_record(successful_transaction.id).tags == [
               "overflow"
             ]

      assert Classification.get_classification_record(failing_transaction.id).tags ==
               original_tags
    end
  end

  describe "manual overrides" do
    test "S08: set_manual_field/4 supports category, tags, investment_type, and notes" do
      entity = insert_entity()
      account = insert_account(entity)
      category = insert_category_account(entity, "Transport")
      transaction = create_transaction(entity, account)

      assert {:ok, record_after_category} =
               Classification.set_manual_field(
                 transaction.id,
                 :category,
                 category.id,
                 entity_id: entity.id,
                 actor: "qa-reviewer",
                 channel: :web
               )

      assert {:ok, record_after_tags} =
               Classification.set_manual_field(
                 transaction.id,
                 :tags,
                 " ride, urgent,ride ",
                 entity_id: entity.id,
                 actor: "qa-reviewer",
                 channel: :web
               )

      assert {:ok, record_after_investment_type} =
               Classification.set_manual_field(
                 transaction.id,
                 :investment_type,
                 " taxable ",
                 entity_id: entity.id,
                 actor: "qa-reviewer",
                 channel: :web
               )

      assert {:ok, final_record} =
               Classification.set_manual_field(
                 transaction.id,
                 :notes,
                 " review manually ",
                 entity_id: entity.id,
                 actor: "qa-reviewer",
                 channel: :web
               )

      assert record_after_category.category_account_id == category.id
      assert record_after_tags.tags == ["ride", "urgent"]
      assert record_after_investment_type.investment_type == "taxable"
      assert final_record.notes == "review manually"
      assert final_record.category_manually_overridden
      assert final_record.tags_manually_overridden
      assert final_record.investment_type_manually_overridden
      assert final_record.notes_manually_overridden
      assert final_record.category_classified_by["source"] == "user"
      assert final_record.tags_classified_by["source"] == "user"
      assert final_record.investment_type_classified_by["source"] == "user"
      assert final_record.notes_classified_by["source"] == "user"

      events = audit_events_for(final_record)
      assert Enum.count(events, &(&1.action == "manual_override")) == 4

      category_event = find_event(events, "manual_override", :category)
      assert category_event.actor == "qa-reviewer"
      assert category_event.channel == :web
      assert category_event.metadata["old_value"] == nil
      assert category_event.metadata["new_value"] == category.id

      tags_event = find_event(events, "manual_override", :tags)
      assert tags_event.metadata["old_value"] == "[]"
      assert tags_event.metadata["new_value"] == "[\"ride\",\"urgent\"]"
    end

    test "S09: clear_manual_override/3 retains the value and unlocks future automation" do
      entity = insert_entity()
      account = insert_account(entity)
      transaction = create_transaction(entity, account)

      insert_matching_rule(
        :global,
        nil,
        [%{field: :notes, operation: :set, value: "rule note"}],
        group_name: "Notes Automation"
      )

      assert {:ok, locked_record} =
               Classification.set_manual_field(
                 transaction.id,
                 :notes,
                 "review manually",
                 entity_id: entity.id,
                 actor: "qa-reviewer",
                 channel: :web
               )

      assert locked_record.notes == "review manually"
      assert locked_record.notes_manually_overridden

      assert {:ok, unlocked_record} =
               Classification.clear_manual_override(
                 transaction.id,
                 :notes,
                 entity_id: entity.id,
                 actor: "qa-reviewer",
                 channel: :web
               )

      assert unlocked_record.notes == "review manually"
      refute unlocked_record.notes_manually_overridden

      assert {:ok, result} =
               Classification.classify_transaction(transaction.id, entity_id: entity.id)

      assert result.classification_record.notes == "rule note"
      refute result.classification_record.notes_manually_overridden
      assert result.fields_applied == 1

      events = audit_events_for(result.classification_record)

      assert find_event(events, "manual_override", :notes)
      assert find_event(events, "override_cleared", :notes)
      assert find_event(events, "rule_applied", :notes)
    end

    test "S10: category values must be same-entity category accounts" do
      entity = insert_entity()
      other_entity = insert_entity()
      account = insert_account(entity)
      transaction = create_transaction(entity, account)
      category = insert_category_account(entity, "Transport")
      foreign_category = insert_category_account(other_entity, "Foreign Category")

      assert {:ok, record} =
               Classification.set_manual_field(
                 transaction.id,
                 :category,
                 category.id,
                 entity_id: entity.id
               )

      assert record.category_account_id == category.id

      assert {:error, :invalid_category_account} =
               Classification.set_manual_field(
                 transaction.id,
                 :category,
                 account.id,
                 entity_id: entity.id
               )

      assert {:error, :invalid_category_account} =
               Classification.set_manual_field(
                 transaction.id,
                 :category,
                 foreign_category.id,
                 entity_id: entity.id
               )
    end
  end

  describe "preview_classification/1" do
    test "S12: surfaces protected fields from persisted classification records" do
      entity = insert_entity()
      account = insert_account(entity)
      transport = insert_category_account(entity, "Transport")
      food = insert_category_account(entity, "Food")

      insert_matching_rule(
        :global,
        nil,
        [
          %{field: :category, operation: :set, value: transport.id},
          %{field: :tags, operation: :add, value: "ride"}
        ]
      )

      transaction = create_transaction(entity, account, description: "Uber trip")

      insert_classification_record(transaction, %{
        category_account_id: food.id,
        category_classified_by: %{"source" => "user"},
        category_manually_overridden: true,
        tags: []
      })

      [result] =
        Classification.preview_classification(%{
          entity_id: entity.id,
          date_from: ~D[2026-03-01],
          date_to: ~D[2026-03-31]
        })

      category_change =
        Enum.find(result.proposed_changes, fn
          %ProposedChange{field: :category, status: :protected} -> true
          _change -> false
        end)

      assert category_change.currently_overridden?
      assert category_change.current_value == food.id

      assert Enum.any?(result.proposed_changes, fn
               %ProposedChange{field: :tags, status: :proposed, proposed_value: ["ride"]} -> true
               _change -> false
             end)
    end
  end

  defp create_transaction(entity, account, opts \\ []) do
    date = Keyword.get(opts, :date, ~D[2026-03-14])
    description = Keyword.get(opts, :description, "Uber trip")
    amount = Keyword.get(opts, :amount, "-10.00")

    contra_account =
      case Keyword.get(opts, :contra_account) do
        nil ->
          insert_category_account(entity, "Contra Expense")

        existing_account ->
          existing_account
      end

    {:ok, transaction} =
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

    transaction
  end

  defp insert_category_account(entity, name) do
    insert_account(entity, %{
      name: name,
      account_type: :expense,
      management_group: :category,
      operational_subtype: nil,
      institution_name: nil,
      institution_account_ref: nil
    })
  end

  defp insert_matching_rule(scope_type, scope_subject, actions, opts \\ []) do
    group_attrs = %{
      name: Keyword.get(opts, :group_name, "Matching Rules"),
      priority: Keyword.get(opts, :priority, 1),
      target_fields: target_fields_for(actions)
    }

    rule_group =
      case scope_type do
        :global -> insert_global_rule_group(group_attrs)
        :entity -> insert_rule_group(scope_subject, group_attrs)
        :account -> insert_account_rule_group(scope_subject, group_attrs)
      end

    rule =
      insert_rule(rule_group, %{
        name: Keyword.get(opts, :rule_name, "Matching Rule"),
        expression: Keyword.get(opts, :expression, ~s|description contains "uber"|),
        actions: actions
      })

    {rule_group, rule}
  end

  defp target_fields_for(actions) do
    actions
    |> Enum.map(&Map.fetch!(&1, :field))
    |> Enum.map(&Atom.to_string/1)
    |> Enum.uniq()
  end

  defp audit_events_for(classification_record) do
    Audit.list_audit_events(
      entity_type: "classification_record",
      entity_id: classification_record.id,
      limit: 50
    )
  end

  defp find_event(events, action, field) do
    Enum.find(events, fn event ->
      event.action == action and event.metadata["field"] == Atom.to_string(field)
    end)
  end

  defp translated_error(key) do
    Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", key)
  end

  defp negate_amount(amount) do
    amount
    |> Decimal.new()
    |> Decimal.negate()
    |> Decimal.to_string()
  end
end
