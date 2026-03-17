defmodule AurumFinance.Classification do
  @moduledoc """
  Classification context for scoped rule groups, ordered rules, and DSL-backed
  rule authoring.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Audit.AuditEvent
  alias AurumFinance.Audit.Multi, as: AuditMulti
  alias AurumFinance.Classification.ClassificationRecord
  alias AurumFinance.Classification.Engine
  alias AurumFinance.Classification.ExpressionCompiler
  alias AurumFinance.Classification.ExpressionValidator
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Repo

  @default_actor "system"
  @rule_group_entity_type "rule_group"
  @rule_entity_type "rule"
  @classification_record_entity_type "classification_record"
  @classification_fields [:category, :tags, :investment_type, :notes]

  @type audit_opt :: {:actor, String.t()} | {:channel, Audit.audit_channel()}

  @type rule_group_list_opt ::
          {:scope_type, :global | :entity | :account}
          | {:entity_id, Ecto.UUID.t()}
          | {:account_id, Ecto.UUID.t()}
          | {:visible_to_entity_id, Ecto.UUID.t()}
          | {:visible_to_account_ids, [Ecto.UUID.t()]}
          | {:is_active, boolean()}

  @type rule_list_opt :: {:rule_group_id, Ecto.UUID.t()} | {:is_active, boolean()}
  @dialyzer {:nowarn_function,
             delete_rule_group: 2,
             delete_rule: 2,
             new_multi: 0,
             multi_delete: 3,
             persist_classification_record: 5,
             put_classification_record_step: 3,
             append_classification_audits: 4}

  @type preview_opt ::
          {:entity_id, Ecto.UUID.t()}
          | {:date_from, Date.t()}
          | {:date_to, Date.t()}

  @type classification_field :: :category | :tags | :investment_type | :notes

  @doc """
  Previews classification results for transactions in a date range without
  writing to any table.

  Loads entity-scoped transactions with all preloads needed by the engine,
  loads visible rule groups (global + entity + account-scoped for the posting
  accounts present in those transactions), and runs the pure engine to produce
  explainable per-field proposals.

  Returns `[]` when no transactions exist in the date range.

  ## Options

  - `:entity_id` (required) - the entity boundary for transactions and rules
  - `:date_from` (required) - inclusive start date
  - `:date_to` (required) - inclusive end date

  ## Examples

      iex> AurumFinance.Classification.preview_classification(%{
      ...>   entity_id: Ecto.UUID.generate(),
      ...>   date_from: ~D[2026-03-01],
      ...>   date_to: ~D[2026-03-31]
      ...> })
      []
  """
  @spec preview_classification(map()) :: [Engine.Result.t()]
  def preview_classification(%{entity_id: entity_id, date_from: date_from, date_to: date_to}) do
    transactions = load_preview_transactions(entity_id, date_from, date_to)

    case transactions do
      [] ->
        []

      _ ->
        account_ids = extract_posting_account_ids(transactions)
        rule_groups = load_preview_rule_groups(entity_id, account_ids)
        current_classifications = load_current_classifications(transactions)

        Engine.evaluate(transactions, rule_groups,
          current_classifications: current_classifications
        )
    end
  end

  @doc """
  Returns the persisted classification record for one transaction or `nil`.

  ## Examples

  Typical read after applying rules:

  ```elixir
  {:ok, %{classification_record: record}} =
    AurumFinance.Classification.classify_transaction(transaction.id, entity_id: entity.id)

  same_record =
    AurumFinance.Classification.get_classification_record(transaction.id)

  same_record.id == record.id
  #=> true
  ```

  Missing records return `nil`:

      iex> AurumFinance.Classification.get_classification_record(Ecto.UUID.generate())
      nil
  """
  @spec get_classification_record(Ecto.UUID.t()) :: ClassificationRecord.t() | nil
  def get_classification_record(transaction_id) do
    transaction_id
    |> List.wrap()
    |> list_classification_records()
    |> List.first()
  end

  @doc """
  Returns persisted classification records for multiple transactions in one query.

  The returned records include the same preloads used by `get_classification_record/1`
  so callers can render category labels without additional queries.

  ## Examples

  ```elixir
  records =
    AurumFinance.Classification.list_classification_records([
      transaction_a.id,
      transaction_b.id
    ])

  Enum.map(records, & &1.transaction_id)
  #=> [transaction_a.id, transaction_b.id]
  ```
  """
  @spec list_classification_records([Ecto.UUID.t()]) :: [ClassificationRecord.t()]
  def list_classification_records([]), do: []

  def list_classification_records(transaction_ids) when is_list(transaction_ids) do
    ClassificationRecord
    |> where([classification_record], classification_record.transaction_id in ^transaction_ids)
    |> preload([:transaction, :category_account])
    |> Repo.all()
  end

  @doc """
  Returns audit events for a classification record, ordered oldest-first.

  Used to render the per-transaction classification history view, which shows
  every rule application, manual override, and override-clear event in
  chronological order.

  Returns an empty list if `record` is `nil` (transaction never classified).

  ## Examples

  ```elixir
  AurumFinance.Classification.list_classification_history(record)
  #=> [%AuditEvent{action: "rule_applied", ...}, %AuditEvent{action: "manual_override", ...}]

  AurumFinance.Classification.list_classification_history(nil)
  #=> []
  ```
  """
  @spec list_classification_history(ClassificationRecord.t() | nil) :: [AuditEvent.t()]
  def list_classification_history(nil), do: []

  def list_classification_history(%ClassificationRecord{id: record_id}) do
    AuditEvent
    |> where(
      [ae],
      ae.entity_type == ^@classification_record_entity_type and ae.entity_id == ^record_id
    )
    |> order_by([ae], asc: ae.occurred_at)
    |> Repo.all()
  end

  @doc """
  Applies active rules to one transaction and upserts its classification record.

  Returns the updated record (when any field changed or a record already exists),
  together with per-transaction summary counters.

  ## Examples

  Happy path:

  ```elixir
  {:ok, result} =
    AurumFinance.Classification.classify_transaction(transaction.id, entity_id: entity.id)

  result.classified?
  #=> true

  result.fields_applied
  #=> 2

  result.classification_record.category_account_id
  #=> transport_account.id
  ```

  Missing transactions fail safely:

  ```elixir
  AurumFinance.Classification.classify_transaction(
    Ecto.UUID.generate(),
    entity_id: entity.id
  )
  #=> {:error, :not_found}
  ```
  """
  @spec classify_transaction(Transaction.t(), [audit_opt()]) ::
          {:ok,
           %{
             classification_record: ClassificationRecord.t() | nil,
             classified?: boolean(),
             fields_applied: non_neg_integer(),
             fields_skipped_manual: non_neg_integer(),
             no_match?: boolean()
           }}
          | {:error, term()}
  @spec classify_transaction(Ecto.UUID.t(), [audit_opt() | {:entity_id, Ecto.UUID.t()}]) ::
          {:ok,
           %{
             classification_record: ClassificationRecord.t() | nil,
             classified?: boolean(),
             fields_applied: non_neg_integer(),
             fields_skipped_manual: non_neg_integer(),
             no_match?: boolean()
           }}
          | {:error, term()}
  def classify_transaction(transaction, opts \\ [])

  def classify_transaction(%Transaction{} = transaction, opts) do
    transaction = Repo.preload(transaction, postings: :account)

    if transaction.voided_at do
      {:ok,
       %{
         classification_record: get_classification_record(transaction.id),
         classified?: false,
         fields_applied: 0,
         fields_skipped_manual: 0,
         no_match?: true
       }}
    else
      existing_record = get_classification_record(transaction.id)
      current_classifications = build_current_classifications([transaction], [existing_record])
      account_ids = extract_posting_account_ids([transaction])
      rule_groups = load_preview_rule_groups(transaction.entity_id, account_ids)

      [result] =
        Engine.evaluate([transaction], rule_groups,
          current_classifications: current_classifications
        )

      do_apply_engine_result(transaction, existing_record, result, opts)
    end
  end

  def classify_transaction(transaction_id, opts) when is_binary(transaction_id) do
    entity_id = Keyword.fetch!(opts, :entity_id)

    try do
      entity_id
      |> Ledger.get_transaction!(transaction_id)
      |> classify_transaction(opts)
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end

  @doc """
  Applies active rules to all non-voided transactions in one entity/date range.

  The operation is atomic per transaction. Failures on one transaction do not
  roll back successful classifications for others.

  ## Examples

  ```elixir
  {:ok, summary} =
    AurumFinance.Classification.classify_transactions(%{
      entity_id: entity.id,
      date_from: ~D[2026-03-01],
      date_to: ~D[2026-03-31]
    })

  summary
  #=> %{
  #=>   classified: 15,
  #=>   fields_applied: 23,
  #=>   fields_skipped_manual: 4,
  #=>   no_match: 5,
  #=>   failed: 0,
  #=>   failures: []
  #=> }
  ```
  """
  @spec classify_transactions(map()) ::
          {:ok,
           %{
             classified: non_neg_integer(),
             fields_applied: non_neg_integer(),
             fields_skipped_manual: non_neg_integer(),
             no_match: non_neg_integer(),
             failed: non_neg_integer(),
             failures: [map()]
           }}
  def classify_transactions(
        %{entity_id: entity_id, date_from: date_from, date_to: date_to} = attrs
      ) do
    opts = Map.drop(attrs, [:entity_id, :date_from, :date_to]) |> Enum.to_list()
    transactions = load_preview_transactions(entity_id, date_from, date_to)

    case transactions do
      [] -> {:ok, empty_classify_summary()}
      _ -> {:ok, run_bulk_classification(transactions, entity_id, opts)}
    end
  end

  defp empty_classify_summary do
    %{
      classified: 0,
      fields_applied: 0,
      fields_skipped_manual: 0,
      no_match: 0,
      failed: 0,
      failures: []
    }
  end

  # Batch-loads classification records and rule groups once for the entire run,
  # runs the engine over all transactions, then applies each result individually.
  defp run_bulk_classification(transactions, entity_id, opts) do
    {records_by_tid, results_by_tid} = bulk_evaluate(transactions, entity_id)

    Enum.reduce(transactions, empty_classify_summary(), fn transaction, acc ->
      existing_record = Map.get(records_by_tid, transaction.id)
      engine_result = Map.fetch!(results_by_tid, transaction.id)
      merge_bulk_result(acc, transaction, existing_record, engine_result, opts)
    end)
  end

  defp bulk_evaluate(transactions, entity_id) do
    classification_records =
      transactions |> Enum.map(& &1.id) |> list_classification_records()

    account_ids = extract_posting_account_ids(transactions)
    rule_groups = load_preview_rule_groups(entity_id, account_ids)
    current_classifications = build_current_classifications(transactions, classification_records)

    engine_results =
      Engine.evaluate(transactions, rule_groups, current_classifications: current_classifications)

    records_by_tid = Map.new(classification_records, &{&1.transaction_id, &1})
    results_by_tid = Map.new(engine_results, &{&1.transaction.id, &1})

    {records_by_tid, results_by_tid}
  end

  defp merge_bulk_result(acc, transaction, existing_record, engine_result, opts) do
    case do_apply_engine_result(transaction, existing_record, engine_result, opts) do
      {:ok, result} ->
        %{
          acc
          | classified: acc.classified + if(result.classified?, do: 1, else: 0),
            fields_applied: acc.fields_applied + result.fields_applied,
            fields_skipped_manual: acc.fields_skipped_manual + result.fields_skipped_manual,
            no_match: acc.no_match + if(result.no_match?, do: 1, else: 0)
        }

      {:error, reason} ->
        %{
          acc
          | failed: acc.failed + 1,
            failures: acc.failures ++ [%{transaction_id: transaction.id, reason: inspect(reason)}]
        }
    end
  end

  @doc """
  Manually sets one classification field and locks it from future automation.

  The value is stored together with user provenance and the field-specific manual
  override flag.

  ## Examples

  Setting notes manually:

  ```elixir
  {:ok, record} =
    AurumFinance.Classification.set_manual_field(
      transaction.id,
      :notes,
      "review manually",
      entity_id: entity.id
    )

  record.notes
  #=> "review manually"

  record.notes_manually_overridden
  #=> true

  record.notes_classified_by["source"]
  #=> "user"
  ```

  Setting category manually uses a same-entity category account id:

  ```elixir
  {:ok, record} =
    AurumFinance.Classification.set_manual_field(
      transaction.id,
      :category,
      category_account.id,
      entity_id: entity.id
    )
  ```
  """
  @spec set_manual_field(Ecto.UUID.t(), classification_field() | String.t(), term(), [
          audit_opt() | {:entity_id, Ecto.UUID.t()}
        ]) ::
          {:ok, ClassificationRecord.t() | nil} | {:error, term()}
  def set_manual_field(transaction_id, field, value, opts \\ []) do
    with {:ok, normalized_field} <- normalize_classification_field(field),
         {:ok, transaction} <- fetch_transaction_for_write(transaction_id, opts),
         {:ok, normalized_value} <-
           normalize_manual_value(transaction.entity_id, normalized_field, value) do
      existing_record = get_classification_record(transaction.id)
      current_value = record_value(existing_record, normalized_field)
      current_lock? = record_locked?(existing_record, normalized_field)
      timestamp = utc_now()

      attrs =
        %{
          field_column(normalized_field) => normalized_value,
          classified_by_column(normalized_field) => user_provenance(timestamp),
          manually_overridden_column(normalized_field) => true
        }
        |> maybe_put_new_record_identity(existing_record, transaction)

      audit_entries = [
        %{
          step_name: {:audit, normalized_field, :manual_override},
          action: "manual_override",
          field: normalized_field,
          metadata: %{
            "field" => Atom.to_string(normalized_field),
            "old_value" => serialize_field_value(normalized_field, current_value),
            "new_value" => serialize_field_value(normalized_field, normalized_value)
          }
        }
      ]

      if current_value == normalized_value and current_lock? do
        {:ok, existing_record}
      else
        persist_classification_record(existing_record, transaction, attrs, audit_entries, opts)
      end
    end
  end

  @doc """
  Clears the manual override flag for one field without clearing its value.

  ## Examples

  ```elixir
  {:ok, record} =
    AurumFinance.Classification.clear_manual_override(
      transaction.id,
      :notes,
      entity_id: entity.id
    )

  record.notes
  #=> "review manually"

  record.notes_manually_overridden
  #=> false
  ```
  """
  @spec clear_manual_override(Ecto.UUID.t(), classification_field() | String.t(), [
          audit_opt() | {:entity_id, Ecto.UUID.t()}
        ]) ::
          {:ok, ClassificationRecord.t() | nil} | {:error, term()}
  def clear_manual_override(transaction_id, field, opts \\ []) do
    with {:ok, normalized_field} <- normalize_classification_field(field),
         {:ok, transaction} <- fetch_transaction_for_write(transaction_id, opts) do
      existing_record = get_classification_record(transaction.id)

      cond do
        is_nil(existing_record) ->
          {:ok, nil}

        not record_locked?(existing_record, normalized_field) ->
          {:ok, existing_record}

        true ->
          attrs = %{manually_overridden_column(normalized_field) => false}

          audit_entries = [
            %{
              step_name: {:audit, normalized_field, :override_cleared},
              action: "override_cleared",
              field: normalized_field,
              metadata: %{"field" => Atom.to_string(normalized_field)}
            }
          ]

          persist_classification_record(existing_record, transaction, attrs, audit_entries, opts)
      end
    end
  end

  @doc """
  Lists rule groups using public filters such as scope, ownership, visibility,
  and active state.

  Results are ordered deterministically by scope precedence, priority, and name.

  ## Examples

      iex> AurumFinance.Classification.list_rule_groups(scope_type: :global)
      []
  """
  @spec list_rule_groups([rule_group_list_opt()]) :: [RuleGroup.t()]
  def list_rule_groups(opts \\ []) do
    opts = normalize_rule_group_filters(opts)

    RuleGroup
    |> preload([:entity, :account, :rules])
    |> filter_query(opts)
    |> order_by(
      [rule_group],
      asc:
        fragment(
          "CASE WHEN ? = 'account' THEN 0 WHEN ? = 'entity' THEN 1 ELSE 2 END",
          rule_group.scope_type,
          rule_group.scope_type
        ),
      asc: rule_group.priority,
      asc: rule_group.name
    )
    |> Repo.all()
  end

  @doc """
  Lists rule groups visible to one entity/account set.

  ## Examples

      iex> AurumFinance.Classification.list_visible_rule_groups(Ecto.UUID.generate(), [])
      []
  """
  @spec list_visible_rule_groups(Ecto.UUID.t(), [Ecto.UUID.t()], [rule_group_list_opt()]) :: [
          RuleGroup.t()
        ]
  def list_visible_rule_groups(entity_id, account_ids, opts \\ []) do
    visible_rule_groups_query(entity_id, account_ids, opts)
    |> preload([:entity, :account, :rules])
    |> order_by(
      [rule_group],
      asc:
        fragment(
          "CASE WHEN ? = 'account' THEN 0 WHEN ? = 'entity' THEN 1 ELSE 2 END",
          rule_group.scope_type,
          rule_group.scope_type
        ),
      asc: rule_group.priority,
      asc: rule_group.name
    )
    |> Repo.all()
  end

  @doc """
  Fetches one rule group by id.

  ## Examples

      iex> AurumFinance.Classification.get_rule_group!(Ecto.UUID.generate())
      ** (Ecto.NoResultsError)
  """
  @spec get_rule_group!(Ecto.UUID.t()) :: RuleGroup.t()
  def get_rule_group!(rule_group_id) do
    RuleGroup
    |> Repo.get!(rule_group_id)
    |> Repo.preload([:entity, :account, :rules])
  end

  @doc """
  Creates a rule group and emits an audit event.

  ## Examples

      iex> AurumFinance.Classification.create_rule_group(%{
      ...>   scope_type: :global,
      ...>   name: "Global rules",
      ...>   priority: 1,
      ...>   target_fields: ["category"]
      ...> })
      {:error, %Ecto.Changeset{}}
  """
  @spec create_rule_group(map()) :: {:ok, RuleGroup.t()} | {:error, Ecto.Changeset.t()}
  @spec create_rule_group(map(), [audit_opt()]) ::
          {:ok, RuleGroup.t()} | {:error, Ecto.Changeset.t()} | {:error, {:audit_failed, term()}}
  def create_rule_group(attrs, opts \\ []) do
    %RuleGroup{}
    |> RuleGroup.changeset(attrs)
    |> Audit.insert_and_log(rule_group_audit_meta(opts))
  end

  @doc """
  Updates a rule group and emits an audit event.

  ## Examples

      iex> group = %AurumFinance.Classification.RuleGroup{}
      iex> AurumFinance.Classification.update_rule_group(group, %{name: "Updated"})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_rule_group(RuleGroup.t(), map()) ::
          {:ok, RuleGroup.t()} | {:error, Ecto.Changeset.t()}
  @spec update_rule_group(RuleGroup.t(), map(), [audit_opt()]) ::
          {:ok, RuleGroup.t()} | {:error, Ecto.Changeset.t()} | {:error, {:audit_failed, term()}}
  def update_rule_group(rule_group, attrs, opts \\ [])

  def update_rule_group(%RuleGroup{} = rule_group, attrs, opts) do
    changeset = RuleGroup.changeset(rule_group, attrs)

    Audit.update_and_log(rule_group, changeset, rule_group_audit_meta(opts, action: "updated"))
  end

  def update_rule_group(%{id: rule_group_id}, attrs, opts)
      when is_binary(rule_group_id) do
    rule_group_id
    |> get_rule_group!()
    |> update_rule_group(attrs, opts)
  end

  @doc """
  Deletes a rule group and emits an audit event.

  ## Examples

      iex> group = %AurumFinance.Classification.RuleGroup{}
      iex> AurumFinance.Classification.delete_rule_group(group)
      {:error, %Ecto.StaleEntryError{}}
  """
  @spec delete_rule_group(RuleGroup.t()) :: {:ok, RuleGroup.t()} | {:error, term()}
  @spec delete_rule_group(RuleGroup.t(), [audit_opt()]) :: {:ok, RuleGroup.t()} | {:error, term()}
  def delete_rule_group(rule_group, opts \\ [])

  def delete_rule_group(%RuleGroup{} = rule_group, opts) do
    before_snapshot = rule_group_snapshot(rule_group)

    new_multi()
    |> multi_delete(:rule_group, rule_group)
    |> AuditMulti.append_event(
      :rule_group,
      before_snapshot,
      rule_group_audit_meta(opts, action: "deleted")
    )
    |> Repo.transaction()
    |> normalize_delete_result(:rule_group)
  end

  def delete_rule_group(%{id: rule_group_id}, opts)
      when is_binary(rule_group_id) do
    rule_group_id
    |> get_rule_group!()
    |> delete_rule_group(opts)
  end

  @doc """
  Returns a changeset for rule group form handling.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Classification.change_rule_group(
      ...>     %AurumFinance.Classification.RuleGroup{},
      ...>     %{scope_type: :global, name: "Rules", priority: 1}
      ...>   )
      iex> changeset.valid?
      true
  """
  @spec change_rule_group(RuleGroup.t(), map()) :: Ecto.Changeset.t()
  def change_rule_group(%RuleGroup{} = rule_group, attrs \\ %{}) do
    RuleGroup.changeset(rule_group, attrs)
  end

  @doc """
  Lists rules ordered by position and name.

  ## Examples

      iex> AurumFinance.Classification.list_rules(rule_group_id: Ecto.UUID.generate())
      []
  """
  @spec list_rules([rule_list_opt()]) :: [Rule.t()]
  def list_rules(opts \\ []) do
    opts = require_rule_group_scope!(opts, "list_rules/1")

    Rule
    |> preload(:rule_group)
    |> filter_rule_query(opts)
    |> order_by([rule], asc: rule.position, asc: rule.name)
    |> Repo.all()
  end

  @doc """
  Fetches one rule by id.

  ## Examples

      iex> AurumFinance.Classification.get_rule!(Ecto.UUID.generate())
      ** (Ecto.NoResultsError)
  """
  @spec get_rule!(Ecto.UUID.t()) :: Rule.t()
  def get_rule!(rule_id) do
    Rule
    |> Repo.get!(rule_id)
    |> Repo.preload(:rule_group)
  end

  @doc """
  Creates a rule from either structured conditions or a direct expression.

  ## Examples

      iex> AurumFinance.Classification.create_rule(%{
      ...>   rule_group_id: Ecto.UUID.generate(),
      ...>   name: "Uber",
      ...>   position: 1,
      ...>   conditions: [
      ...>     %{field: :description, operator: :contains, value: "Uber", negate: false}
      ...>   ],
      ...>   actions: [%{field: :tags, operation: :add, value: "ride"}]
      ...> })
      {:error, %Ecto.Changeset{}}
  """
  @spec create_rule(map()) :: {:ok, Rule.t()} | {:error, Ecto.Changeset.t()}
  @spec create_rule(map(), [audit_opt()]) ::
          {:ok, Rule.t()} | {:error, Ecto.Changeset.t()} | {:error, {:audit_failed, term()}}
  def create_rule(attrs, opts \\ []) do
    with {:ok, prepared_attrs} <- prepare_rule_attrs(attrs),
         {:ok, rule_group} <- fetch_rule_group_for_write(prepared_attrs) do
      %Rule{}
      |> Rule.changeset(prepared_attrs)
      |> validate_target_fields(rule_group)
      |> validate_category_action_values(rule_group)
      |> Audit.insert_and_log(rule_audit_meta(opts))
    end
    |> normalize_rule_write_result(%Rule{}, attrs)
  end

  @doc """
  Updates a rule from either structured conditions or a direct expression.

  ## Examples

      iex> rule = %AurumFinance.Classification.Rule{}
      iex> AurumFinance.Classification.update_rule(rule, %{expression: ~s|description contains "Uber"|})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_rule(Rule.t(), map()) :: {:ok, Rule.t()} | {:error, Ecto.Changeset.t()}
  @spec update_rule(Rule.t(), map(), [audit_opt()]) ::
          {:ok, Rule.t()} | {:error, Ecto.Changeset.t()} | {:error, {:audit_failed, term()}}
  def update_rule(%Rule{} = rule, attrs, opts \\ []) do
    with {:ok, prepared_attrs} <- prepare_rule_attrs(attrs, rule),
         {:ok, rule_group} <- fetch_rule_group_for_write(prepared_attrs, rule) do
      changeset =
        rule
        |> Rule.changeset(prepared_attrs)
        |> validate_target_fields(rule_group)
        |> validate_category_action_values(rule_group)

      Audit.update_and_log(rule, changeset, rule_audit_meta(opts, action: "updated"))
    end
    |> normalize_rule_write_result(rule, attrs)
  end

  @doc """
  Deletes a rule and emits an audit event.

  ## Examples

      iex> rule = %AurumFinance.Classification.Rule{}
      iex> AurumFinance.Classification.delete_rule(rule)
      {:error, %Ecto.StaleEntryError{}}
  """
  @spec delete_rule(Rule.t()) :: {:ok, Rule.t()} | {:error, term()}
  @spec delete_rule(Rule.t(), [audit_opt()]) :: {:ok, Rule.t()} | {:error, term()}
  def delete_rule(%Rule{} = rule, opts \\ []) do
    before_snapshot = rule_snapshot(rule)

    new_multi()
    |> multi_delete(:rule, rule)
    |> AuditMulti.append_event(:rule, before_snapshot, rule_audit_meta(opts, action: "deleted"))
    |> Repo.transaction()
    |> normalize_delete_result(:rule)
  end

  @doc """
  Returns a changeset for rule form handling.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Classification.change_rule(
      ...>     %AurumFinance.Classification.Rule{},
      ...>     %{
      ...>       rule_group_id: Ecto.UUID.generate(),
      ...>       name: "Uber",
      ...>       position: 1,
      ...>       expression: ~s|description contains "Uber"|,
      ...>       actions: [%{field: :tags, operation: :add, value: "ride"}]
      ...>     }
      ...>   )
      iex> changeset.valid?
      true
  """
  @spec change_rule(Rule.t(), map()) :: Ecto.Changeset.t()
  def change_rule(%Rule{} = rule, attrs \\ %{}) do
    Rule.changeset(rule, attrs)
  end

  @doc """
  Compiles structured condition rows into the AurumFinance expression DSL.

  ## Examples

      iex> AurumFinance.Classification.compile_conditions([
      ...>   %{field: :description, operator: :contains, value: "Uber", negate: false},
      ...>   %{field: :amount, operator: :less_than, value: "-10", negate: false}
      ...> ])
      {:ok, "(description contains \\"Uber\\") AND (amount < -10)"}
  """
  @spec compile_conditions([map()]) :: {:ok, String.t()} | {:error, atom()}
  def compile_conditions(conditions), do: ExpressionCompiler.compile(conditions)

  @doc """
  Validates one AurumFinance expression string.

  ## Examples

      iex> AurumFinance.Classification.validate_expression(~s|description contains "Uber"|)
      {:ok, "description contains \\"Uber\\""}

      iex> AurumFinance.Classification.validate_expression("memo contains \\"Uber\\"")
      {:error, :invalid_expression}
  """
  @spec validate_expression(String.t() | nil) :: {:ok, String.t()} | {:error, atom()}
  def validate_expression(expression), do: ExpressionValidator.validate_expression(expression)

  defp prepare_rule_attrs(attrs, rule \\ %Rule{}) do
    attrs = normalize_attrs(attrs)

    with {:ok, expression} <- resolve_expression(attrs, rule) do
      {:ok, Map.put(attrs, :expression, expression)}
    end
  end

  defp resolve_expression(attrs, rule) do
    case normalize_expression(Map.get(attrs, :expression)) do
      expression when is_binary(expression) and expression != "" ->
        ExpressionValidator.validate_expression(expression)

      _ ->
        resolve_expression_from_conditions(attrs, rule)
    end
  end

  defp resolve_expression_from_conditions(attrs, %Rule{} = rule) do
    case Map.get(attrs, :conditions) do
      conditions when is_list(conditions) and conditions != [] ->
        ExpressionCompiler.compile(conditions)

      _ ->
        case normalize_expression(rule.expression) do
          expression when is_binary(expression) and expression != "" ->
            ExpressionValidator.validate_expression(expression)

          _ ->
            {:error, :empty_expression}
        end
    end
  end

  defp fetch_rule_group_for_write(attrs, rule \\ %Rule{}) do
    rule_group_id = Map.get(attrs, :rule_group_id) || rule.rule_group_id

    case rule_group_id do
      nil ->
        {:error, :missing_rule_group}

      id ->
        try do
          {:ok, get_rule_group!(id)}
        rescue
          Ecto.NoResultsError -> {:error, :missing_rule_group}
        end
    end
  end

  # Validates that every `category` action in the changeset references an existing
  # category account that belongs to the rule group's entity scope.
  #
  # Entity-scoped: validates UUID against the group's own entity.
  # Account-scoped: derives entity_id from the linked account, then validates.
  # Global-scoped:  no entity context exists — category UUIDs are entity-specific by
  #                 definition and would silently fail at apply time for all other
  #                 entities.  We block them at write time with a clear error.
  defp validate_category_action_values(changeset, %RuleGroup{} = rule_group) do
    entity_id = category_validation_entity_id(rule_group)

    changeset
    |> Ecto.Changeset.get_field(:actions, [])
    |> Enum.filter(&(&1.field == :category and &1.operation == :set))
    |> Enum.reduce(changeset, fn action, acc ->
      validate_one_category_action(acc, action, entity_id)
    end)
  end

  defp validate_one_category_action(changeset, _action, nil) do
    Ecto.Changeset.add_error(
      changeset,
      :actions,
      Gettext.dgettext(
        AurumFinance.Gettext,
        "errors",
        "error_rule_action_category_global_not_allowed"
      )
    )
  end

  defp validate_one_category_action(changeset, action, entity_id) do
    with {:ok, uuid} <- Ecto.UUID.cast(action.value || ""),
         %Account{} = account <- Ledger.get_account(entity_id, uuid),
         true <- Account.category_account?(account) do
      changeset
    else
      _ -> add_category_account_error(changeset)
    end
  end

  defp add_category_account_error(changeset) do
    Ecto.Changeset.add_error(
      changeset,
      :actions,
      Gettext.dgettext(
        AurumFinance.Gettext,
        "errors",
        "error_rule_action_category_account_not_found"
      )
    )
  end

  defp category_validation_entity_id(%RuleGroup{scope_type: :entity, entity_id: entity_id}),
    do: entity_id

  defp category_validation_entity_id(%RuleGroup{scope_type: :account, account_id: account_id}) do
    case Repo.get(Account, account_id) do
      %Account{entity_id: entity_id} -> entity_id
      nil -> nil
    end
  end

  defp category_validation_entity_id(%RuleGroup{scope_type: :global}), do: nil

  defp validate_target_fields(changeset, %RuleGroup{target_fields: []}), do: changeset

  defp validate_target_fields(changeset, %RuleGroup{target_fields: target_fields}) do
    changeset
    |> Ecto.Changeset.get_field(:actions, [])
    |> Enum.map(& &1.field)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Atom.to_string/1)
    |> Enum.reject(&(&1 in target_fields))
    |> Enum.uniq()
    |> Enum.reduce(changeset, fn field, acc ->
      Ecto.Changeset.add_error(
        acc,
        :actions,
        Gettext.dgettext(
          AurumFinance.Gettext,
          "errors",
          "error_rule_action_field_not_allowed",
          field: field
        )
      )
    end)
  end

  defp rule_changeset_error(rule, attrs, :empty_expression) do
    rule
    |> Rule.changeset(normalize_attrs(attrs))
    |> Ecto.Changeset.add_error(
      :expression,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_rule_expression_required")
    )
  end

  defp rule_changeset_error(rule, attrs, :invalid_regex) do
    rule
    |> Rule.changeset(normalize_attrs(attrs))
    |> Ecto.Changeset.add_error(
      :expression,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_rule_expression_invalid_regex")
    )
  end

  defp rule_changeset_error(rule, attrs, _reason) do
    rule
    |> Rule.changeset(normalize_attrs(attrs))
    |> Ecto.Changeset.add_error(
      :expression,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_rule_expression_invalid")
    )
  end

  defp normalize_delete_result({:ok, changes}, key), do: {:ok, Map.fetch!(changes, key)}
  defp normalize_delete_result({:error, _step, reason, _changes}, _key), do: {:error, reason}

  defp normalize_rule_write_result({:ok, %Rule{} = rule}, _original_rule, _attrs), do: {:ok, rule}

  defp normalize_rule_write_result(
         {:error, %Ecto.Changeset{} = changeset},
         _original_rule,
         _attrs
       ) do
    {:error, changeset}
  end

  defp normalize_rule_write_result({:error, reason}, original_rule, attrs) do
    {:error, rule_changeset_error(original_rule, attrs, reason)}
  end

  defp normalize_rule_group_filters(opts) do
    visible_to_entity_id = Keyword.get(opts, :visible_to_entity_id)
    visible_to_account_ids = Keyword.get(opts, :visible_to_account_ids)

    rest =
      opts
      |> Keyword.delete(:visible_to_entity_id)
      |> Keyword.delete(:visible_to_account_ids)

    []
    |> maybe_prepend_visibility_filter(visible_to_entity_id, visible_to_account_ids)
    |> Kernel.++(rest)
  end

  defp maybe_prepend_visibility_filter(filters, nil, nil), do: filters

  defp maybe_prepend_visibility_filter(filters, visible_to_entity_id, visible_to_account_ids) do
    [{:visible_to_scope, {visible_to_entity_id, visible_to_account_ids || []}} | filters]
  end

  defp visible_rule_groups_query(entity_id, account_ids, opts) do
    opts =
      Keyword.merge(opts,
        visible_to_entity_id: entity_id,
        visible_to_account_ids: account_ids
      )

    RuleGroup
    |> preload([:entity, :account])
    |> filter_query(normalize_rule_group_filters(opts))
  end

  defp require_rule_group_scope!(opts, function_name) do
    case Keyword.fetch(opts, :rule_group_id) do
      {:ok, rule_group_id} when not is_nil(rule_group_id) -> opts
      _ -> raise ArgumentError, "#{function_name} requires :rule_group_id"
    end
  end

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:visible_to_scope, {entity_id, account_ids}} | rest]) do
    visibility_filter = visible_scope_dynamic(entity_id, List.wrap(account_ids))

    query
    |> where(^visibility_filter)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:scope_type, scope_type} | rest]) do
    query
    |> where([rule_group], rule_group.scope_type == ^scope_type)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:entity_id, entity_id} | rest]) do
    query
    |> where([rule_group], rule_group.entity_id == ^entity_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where([rule_group], rule_group.account_id == ^account_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:is_active, is_active} | rest]) when is_boolean(is_active) do
    query
    |> where([rule_group], rule_group.is_active == ^is_active)
    |> filter_query(rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end

  defp filter_rule_query(query, []), do: query

  defp filter_rule_query(query, [{:rule_group_id, rule_group_id} | rest]) do
    query
    |> where([rule], rule.rule_group_id == ^rule_group_id)
    |> filter_rule_query(rest)
  end

  defp filter_rule_query(query, [{:is_active, is_active} | rest]) when is_boolean(is_active) do
    query
    |> where([rule], rule.is_active == ^is_active)
    |> filter_rule_query(rest)
  end

  defp filter_rule_query(query, [_unknown_filter | rest]) do
    filter_rule_query(query, rest)
  end

  defp rule_group_audit_meta(opts, overrides \\ []) do
    base = %{
      actor: audit_actor(opts),
      channel: audit_channel(opts),
      entity_type: @rule_group_entity_type,
      serializer: &rule_group_snapshot/1
    }

    Enum.reduce(overrides, base, fn {key, value}, acc -> Map.put(acc, key, value) end)
  end

  defp rule_audit_meta(opts, overrides \\ []) do
    base = %{
      actor: audit_actor(opts),
      channel: audit_channel(opts),
      entity_type: @rule_entity_type,
      serializer: &rule_snapshot/1
    }

    Enum.reduce(overrides, base, fn {key, value}, acc -> Map.put(acc, key, value) end)
  end

  defp audit_actor(opts) do
    opts
    |> Keyword.get(:actor, @default_actor)
    |> Audit.normalize_actor()
  end

  defp audit_channel(opts) do
    opts
    |> Keyword.get(:channel, :system)
    |> Audit.normalize_channel()
  end

  defp rule_group_snapshot(%RuleGroup{} = rule_group) do
    %{
      "id" => rule_group.id,
      "scope_type" => rule_group.scope_type,
      "entity_id" => rule_group.entity_id,
      "account_id" => rule_group.account_id,
      "name" => rule_group.name,
      "description" => rule_group.description,
      "priority" => rule_group.priority,
      "target_fields" => rule_group.target_fields,
      "is_active" => rule_group.is_active,
      "inserted_at" => maybe_datetime_to_iso8601(rule_group.inserted_at),
      "updated_at" => maybe_datetime_to_iso8601(rule_group.updated_at)
    }
  end

  defp rule_snapshot(%Rule{} = rule) do
    %{
      "id" => rule.id,
      "rule_group_id" => rule.rule_group_id,
      "name" => rule.name,
      "description" => rule.description,
      "position" => rule.position,
      "is_active" => rule.is_active,
      "stop_processing" => rule.stop_processing,
      "expression" => rule.expression,
      "actions" => Enum.map(rule.actions, &Map.take(&1, [:field, :operation, :value])),
      "inserted_at" => maybe_datetime_to_iso8601(rule.inserted_at),
      "updated_at" => maybe_datetime_to_iso8601(rule.updated_at)
    }
  end

  defp maybe_datetime_to_iso8601(nil), do: nil
  defp maybe_datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  @spec new_multi() :: any()
  defp new_multi, do: Ecto.Multi.new()

  @spec multi_delete(any(), atom(), struct()) :: any()
  defp multi_delete(multi, name, struct), do: Ecto.Multi.delete(multi, name, struct)

  defp normalize_attrs(attrs) when is_list(attrs), do: attrs |> Map.new() |> normalize_attrs()

  defp normalize_attrs(attrs) when is_map(attrs) do
    Enum.reduce(attrs, %{}, fn {key, value}, acc ->
      Map.put(acc, normalize_attr_key(key), value)
    end)
  end

  defp normalize_expression(value) when is_binary(value), do: String.trim(value)
  defp normalize_expression(value), do: value

  defp visible_scope_dynamic(entity_id, account_ids) do
    dynamic([rule_group], rule_group.scope_type == ^:global)
    |> maybe_add_entity_visibility(entity_id)
    |> maybe_add_account_visibility(account_ids)
  end

  defp maybe_add_entity_visibility(dynamic_query, nil), do: dynamic_query

  defp maybe_add_entity_visibility(dynamic_query, entity_id) do
    dynamic(
      [rule_group],
      ^dynamic_query or
        (rule_group.scope_type == ^:entity and rule_group.entity_id == ^entity_id)
    )
  end

  defp maybe_add_account_visibility(dynamic_query, []), do: dynamic_query

  defp maybe_add_account_visibility(dynamic_query, account_ids) do
    dynamic(
      [rule_group],
      ^dynamic_query or
        (rule_group.scope_type == ^:account and rule_group.account_id in ^account_ids)
    )
  end

  defp normalize_attr_key(key) when is_atom(key), do: key

  defp normalize_attr_key(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end

  defp normalize_attr_key(key), do: key

  # ---------------------------------------------------------------------------
  # Classification record helpers
  # ---------------------------------------------------------------------------

  defp do_apply_engine_result(transaction, existing_record, result, opts) do
    proposed_changes = Enum.filter(result.proposed_changes, &(&1.status == :proposed))
    fields_skipped_manual = Enum.count(result.proposed_changes, &(&1.status == :protected))

    {attrs, audit_entries, applied_fields} =
      build_rule_application(existing_record, transaction, proposed_changes)

    case {map_size(attrs), existing_record} do
      {0, nil} ->
        {:ok,
         %{
           classification_record: nil,
           classified?: false,
           fields_applied: 0,
           fields_skipped_manual: fields_skipped_manual,
           no_match?: result.no_match?
         }}

      {0, %ClassificationRecord{} = record} ->
        {:ok,
         %{
           classification_record: record,
           classified?: false,
           fields_applied: 0,
           fields_skipped_manual: fields_skipped_manual,
           no_match?: result.no_match?
         }}

      _ ->
        case persist_classification_record(
               existing_record,
               transaction,
               attrs,
               audit_entries,
               opts
             ) do
          {:ok, classification_record} ->
            {:ok,
             %{
               classification_record: classification_record,
               classified?: applied_fields > 0,
               fields_applied: applied_fields,
               fields_skipped_manual: fields_skipped_manual,
               no_match?: result.no_match?
             }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp build_rule_application(existing_record, transaction, proposed_changes) do
    timestamp = utc_now()

    Enum.reduce(proposed_changes, {%{}, [], 0}, fn change,
                                                   {attrs, audit_entries, applied_fields} ->
      case normalize_proposed_value(transaction.entity_id, change.field, change.proposed_value) do
        {:ok, normalized_value} ->
          apply_rule_change(
            existing_record,
            change,
            normalized_value,
            attrs,
            audit_entries,
            applied_fields,
            timestamp
          )

        {:error, :invalid_category_account} ->
          {attrs, audit_entries, applied_fields}
      end
    end)
    |> then(fn {attrs, audit_entries, applied_fields} ->
      {maybe_put_new_record_identity(attrs, existing_record, transaction), audit_entries,
       applied_fields}
    end)
  end

  defp apply_rule_change(
         existing_record,
         change,
         normalized_value,
         attrs,
         audit_entries,
         applied_fields,
         timestamp
       ) do
    current_value = record_value(existing_record, change.field)

    if current_value == normalized_value do
      {attrs, audit_entries, applied_fields}
    else
      field_attrs = %{
        field_column(change.field) => normalized_value,
        classified_by_column(change.field) =>
          rule_provenance(change.rule_group.id, change.rule.id, timestamp)
      }

      audit_entry = %{
        step_name: {:audit, change.field, change.rule.id},
        action: "rule_applied",
        field: change.field,
        metadata: %{
          "field" => Atom.to_string(change.field),
          "old_value" => serialize_field_value(change.field, current_value),
          "new_value" => serialize_field_value(change.field, normalized_value),
          "rule_group_id" => change.rule_group.id,
          "rule_id" => change.rule.id
        }
      }

      {Map.merge(attrs, field_attrs), audit_entries ++ [audit_entry], applied_fields + 1}
    end
  end

  defp persist_classification_record(existing_record, _transaction, attrs, audit_entries, opts) do
    record = existing_record || %ClassificationRecord{}
    before_snapshot = existing_record && classification_record_snapshot(existing_record)
    changeset = ClassificationRecord.changeset(record, attrs)

    multi =
      new_multi()
      |> put_classification_record_step(changeset, existing_record)
      |> append_classification_audits(before_snapshot, audit_entries, opts)

    case Repo.transaction(multi) do
      {:ok, %{classification_record: classification_record}} ->
        {:ok, Repo.preload(classification_record, [:transaction, :category_account])}

      {:error, :classification_record, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  @spec put_classification_record_step(any(), Ecto.Changeset.t(), ClassificationRecord.t() | nil) ::
          any()
  defp put_classification_record_step(multi, changeset, nil) do
    Ecto.Multi.insert(multi, :classification_record, changeset)
  end

  defp put_classification_record_step(multi, changeset, _existing_record) do
    Ecto.Multi.update(multi, :classification_record, changeset)
  end

  @spec append_classification_audits(any(), map() | nil, [map()], [
          audit_opt() | {:entity_id, Ecto.UUID.t()}
        ]) ::
          any()
  defp append_classification_audits(multi, before_snapshot, audit_entries, opts) do
    Enum.reduce(audit_entries, multi, fn audit_entry, acc ->
      Ecto.Multi.insert(acc, audit_entry.step_name, fn %{
                                                         classification_record:
                                                           classification_record
                                                       } ->
        AuditEvent.changeset(
          %AuditEvent{},
          %{
            entity_type: @classification_record_entity_type,
            entity_id: classification_record.id,
            action: audit_entry.action,
            actor: audit_actor(opts),
            channel: audit_channel(opts),
            before: before_snapshot,
            after: classification_record_snapshot(classification_record),
            metadata: audit_entry.metadata,
            occurred_at: utc_now()
          }
        )
      end)
    end)
  end

  defp fetch_transaction_for_write(transaction_id, opts) do
    entity_id = Keyword.fetch!(opts, :entity_id)

    try do
      {:ok, Ledger.get_transaction!(entity_id, transaction_id)}
    rescue
      Ecto.NoResultsError -> {:error, :not_found}
    end
  end

  defp load_classification_records(transaction_ids) do
    ClassificationRecord
    |> where([classification_record], classification_record.transaction_id in ^transaction_ids)
    |> Repo.all()
  end

  defp load_current_classifications(transactions) do
    transaction_ids = Enum.map(transactions, & &1.id)
    classification_records = load_classification_records(transaction_ids)

    build_current_classifications(transactions, classification_records)
  end

  defp build_current_classifications(transactions, classification_records) do
    records_by_transaction_id =
      classification_records
      |> Enum.reject(&is_nil/1)
      |> Map.new(&{&1.transaction_id, &1})

    Enum.reduce(transactions, %{}, fn transaction, acc ->
      case Map.get(records_by_transaction_id, transaction.id) do
        nil ->
          acc

        record ->
          Map.put(acc, transaction.id, current_classification(record))
      end
    end)
  end

  defp current_classification(record) do
    %{
      category: record.category_account_id,
      tags: record.tags || [],
      investment_type: record.investment_type,
      notes: record.notes,
      protected_fields: protected_fields(record)
    }
  end

  defp protected_fields(record) do
    @classification_fields
    |> Enum.filter(&record_locked?(record, &1))
  end

  defp record_locked?(nil, _field), do: false

  defp record_locked?(record, field) do
    Map.get(record, manually_overridden_column(field), false)
  end

  defp record_value(nil, :tags), do: []
  defp record_value(nil, _field), do: nil

  defp record_value(record, field) do
    Map.get(record, field_column(field), default_field_value(field))
  end

  defp field_column(:category), do: :category_account_id
  defp field_column(:tags), do: :tags
  defp field_column(:investment_type), do: :investment_type
  defp field_column(:notes), do: :notes

  defp classified_by_column(:category), do: :category_classified_by
  defp classified_by_column(:tags), do: :tags_classified_by
  defp classified_by_column(:investment_type), do: :investment_type_classified_by
  defp classified_by_column(:notes), do: :notes_classified_by

  defp manually_overridden_column(:category), do: :category_manually_overridden
  defp manually_overridden_column(:tags), do: :tags_manually_overridden
  defp manually_overridden_column(:investment_type), do: :investment_type_manually_overridden
  defp manually_overridden_column(:notes), do: :notes_manually_overridden

  defp default_field_value(:tags), do: []
  defp default_field_value(_field), do: nil

  defp normalize_classification_field(field) when field in @classification_fields,
    do: {:ok, field}

  defp normalize_classification_field("category"), do: {:ok, :category}
  defp normalize_classification_field("tags"), do: {:ok, :tags}
  defp normalize_classification_field("investment_type"), do: {:ok, :investment_type}
  defp normalize_classification_field("notes"), do: {:ok, :notes}
  defp normalize_classification_field(_field), do: {:error, :invalid_field}

  defp normalize_manual_value(entity_id, :category, value),
    do: normalize_category_value(entity_id, value)

  defp normalize_manual_value(_entity_id, :tags, value), do: {:ok, normalize_tags_value(value)}

  defp normalize_manual_value(_entity_id, :investment_type, value),
    do: {:ok, normalize_optional_string(value)}

  defp normalize_manual_value(_entity_id, :notes, value),
    do: {:ok, normalize_optional_string(value)}

  defp normalize_proposed_value(entity_id, :category, value),
    do: normalize_category_value(entity_id, value)

  defp normalize_proposed_value(_entity_id, :tags, value), do: {:ok, normalize_tags_value(value)}

  defp normalize_proposed_value(_entity_id, :investment_type, value),
    do: {:ok, normalize_optional_string(value)}

  defp normalize_proposed_value(_entity_id, :notes, value),
    do: {:ok, normalize_optional_string(value)}

  defp normalize_category_value(_entity_id, nil), do: {:ok, nil}
  defp normalize_category_value(_entity_id, ""), do: {:ok, nil}

  defp normalize_category_value(entity_id, value) when is_binary(value) do
    case Ledger.get_account(entity_id, value) do
      %Account{} = account ->
        if Account.category_account?(account),
          do: {:ok, account.id},
          else: {:error, :invalid_category_account}

      nil ->
        {:error, :invalid_category_account}
    end
  end

  defp normalize_category_value(_entity_id, _value), do: {:error, :invalid_category_account}

  defp normalize_tags_value(nil), do: []

  defp normalize_tags_value(values) when is_list(values) do
    values
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.reduce([], fn value, acc ->
      if value in acc, do: acc, else: acc ++ [value]
    end)
  end

  defp normalize_tags_value(value) when is_binary(value) do
    value
    |> String.split(",")
    |> normalize_tags_value()
  end

  defp normalize_tags_value(_value), do: []

  defp normalize_optional_string(nil), do: nil
  defp normalize_optional_string(""), do: nil

  defp normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized_value -> normalized_value
    end
  end

  defp normalize_optional_string(value), do: value

  defp maybe_put_new_record_identity(attrs, nil, transaction) do
    attrs
    |> Map.put_new(:transaction_id, transaction.id)
    |> Map.put_new(:entity_id, transaction.entity_id)
  end

  defp maybe_put_new_record_identity(attrs, _existing_record, _transaction), do: attrs

  defp user_provenance(timestamp) do
    %{
      "source" => "user",
      "classified_at" => DateTime.to_iso8601(timestamp)
    }
  end

  defp rule_provenance(rule_group_id, rule_id, timestamp) do
    %{
      "source" => "rule",
      "rule_group_id" => rule_group_id,
      "rule_id" => rule_id,
      "classified_at" => DateTime.to_iso8601(timestamp)
    }
  end

  defp serialize_field_value(:tags, nil), do: Jason.encode!([])
  defp serialize_field_value(:tags, value) when is_list(value), do: Jason.encode!(value)
  defp serialize_field_value(_field, nil), do: nil
  defp serialize_field_value(_field, value), do: to_string(value)

  defp classification_record_snapshot(%ClassificationRecord{} = classification_record) do
    %{
      "id" => classification_record.id,
      "transaction_id" => classification_record.transaction_id,
      "entity_id" => classification_record.entity_id,
      "category_account_id" => classification_record.category_account_id,
      "category_classified_by" => classification_record.category_classified_by,
      "category_manually_overridden" => classification_record.category_manually_overridden,
      "tags" => classification_record.tags || [],
      "tags_classified_by" => classification_record.tags_classified_by,
      "tags_manually_overridden" => classification_record.tags_manually_overridden,
      "investment_type" => classification_record.investment_type,
      "investment_type_classified_by" => classification_record.investment_type_classified_by,
      "investment_type_manually_overridden" =>
        classification_record.investment_type_manually_overridden,
      "notes" => classification_record.notes,
      "notes_classified_by" => classification_record.notes_classified_by,
      "notes_manually_overridden" => classification_record.notes_manually_overridden,
      "inserted_at" => maybe_datetime_to_iso8601(classification_record.inserted_at),
      "updated_at" => maybe_datetime_to_iso8601(classification_record.updated_at)
    }
  end

  defp utc_now do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end

  # ---------------------------------------------------------------------------
  # Preview helpers (read-only, no writes)
  # ---------------------------------------------------------------------------

  defp load_preview_transactions(entity_id, date_from, date_to) do
    Transaction
    |> where([t], t.entity_id == ^entity_id)
    |> where([t], t.date >= ^date_from and t.date <= ^date_to)
    |> where([t], is_nil(t.voided_at))
    |> preload(postings: :account)
    |> order_by([t], asc: t.date, asc: t.inserted_at)
    |> Repo.all()
  end

  defp load_preview_rule_groups(entity_id, account_ids) do
    list_visible_rule_groups(entity_id, account_ids, is_active: true)
  end

  defp extract_posting_account_ids(transactions) do
    transactions
    |> Enum.flat_map(fn %Transaction{} = t ->
      t
      |> Map.get(:postings, [])
      |> Enum.map(fn %Posting{} = p -> p.account_id end)
    end)
    |> Enum.uniq()
  end
end
