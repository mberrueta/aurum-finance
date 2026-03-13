defmodule AurumFinance.Classification.Engine do
  @moduledoc """
  Pure-function classification engine for rules preview and apply workflows.

  The engine:

  - selects visible rule groups for each transaction
  - evaluates active rules through an AurumFinance-owned expression adapter
  - applies actions in deterministic merge order
  - returns explainable proposals without DB access or side effects

  Group precedence is `account > entity > global`, then `priority ASC`, then
  `name ASC`. Rules inside a group are ordered by `position ASC`, then `name ASC`.
  Field conflicts are resolved with first-writer-wins.
  """

  alias AurumFinance.Classification.Engine.DslEvaluator
  alias AurumFinance.Classification.Engine.ProposedChange
  alias AurumFinance.Classification.Engine.Result
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleAction
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias Decimal, as: D

  @classification_fields [:category, :tags, :investment_type, :notes]

  @type field :: ProposedChange.field()
  @type current_classification :: %{
          optional(:category) => String.t() | nil,
          optional(:tags) => [String.t()],
          optional(:investment_type) => String.t() | nil,
          optional(:notes) => String.t() | nil,
          optional(:protected_fields) => [field()] | MapSet.t(field())
        }

  @type opt ::
          {:evaluator, module()}
          | {:current_classifications, %{optional(Ecto.UUID.t()) => current_classification()}}

  @doc """
  Evaluates rule groups against transactions with no side effects.

  `current_classifications` is optional and lets callers surface protected/manual
  override states during preview. Each entry is keyed by `transaction.id` and may
  contain current field values plus a `:protected_fields` list or `MapSet`.

  ## Examples

      iex> AurumFinance.Classification.Engine.evaluate([], [])
      []
  """
  @spec evaluate([Transaction.t()], [RuleGroup.t()], [opt()]) :: [Result.t()]
  def evaluate(transactions, rule_groups, opts \\ [])
      when is_list(transactions) and is_list(rule_groups) do
    evaluator = Keyword.get(opts, :evaluator, DslEvaluator)
    current_classifications = Keyword.get(opts, :current_classifications, %{})

    ordered_rule_groups = order_rule_groups(rule_groups)

    Enum.map(transactions, fn transaction ->
      evaluate_transaction(transaction, ordered_rule_groups, evaluator, current_classifications)
    end)
  end

  defp evaluate_transaction(transaction, rule_groups, evaluator, current_classifications) do
    current_classification = Map.get(current_classifications, transaction.id, %{})
    protected_fields = normalize_protected_fields(current_classification)

    initial = %{
      result: %Result{transaction: transaction},
      claims: MapSet.new()
    }

    %{result: %Result{} = result, claims: claims} =
      transaction
      |> matching_rule_groups(rule_groups)
      |> Enum.reduce(initial, fn rule_group, acc ->
        evaluate_rule_group(
          acc,
          transaction,
          rule_group,
          evaluator,
          current_classification,
          protected_fields
        )
      end)

    %Result{
      result
      | claimed_fields: claims,
        no_match?: result.matched_rules == []
    }
  end

  defp evaluate_rule_group(
         acc,
         transaction,
         rule_group,
         evaluator,
         current_classification,
         protected_fields
       ) do
    {acc, matched_rules} =
      rule_group
      |> active_sorted_rules()
      |> Enum.reduce_while({acc, []}, fn rule, {inner_acc, matched_rules} ->
        case rule_matches?(transaction, rule, evaluator) do
          true ->
            advance_group_evaluation(
              inner_acc,
              matched_rules,
              transaction,
              rule_group,
              rule,
              current_classification,
              protected_fields
            )

          false ->
            {:cont, {inner_acc, matched_rules}}
        end
      end)

    case matched_rules do
      [] ->
        acc

      _ ->
        append_matched_group(acc, rule_group, matched_rules)
    end
  end

  defp advance_group_evaluation(
         acc,
         matched_rules,
         transaction,
         rule_group,
         rule,
         current_classification,
         protected_fields
       ) do
    next_acc =
      apply_rule_actions(
        acc,
        transaction,
        rule_group,
        rule,
        current_classification,
        protected_fields
      )

    next_matched_rules = matched_rules ++ [rule]

    if rule.stop_processing,
      do: {:halt, {next_acc, next_matched_rules}},
      else: {:cont, {next_acc, next_matched_rules}}
  end

  defp append_matched_group(acc, rule_group, matched_rules) do
    %Result{} = result = acc.result

    %{
      acc
      | result: %Result{
          result
          | matched_groups:
              result.matched_groups ++ [%{rule_group: rule_group, matched_rules: matched_rules}],
            matched_rules: result.matched_rules ++ matched_rules
        }
    }
  end

  defp rule_matches?(_transaction, %Rule{is_active: false}, _evaluator), do: false

  defp rule_matches?(transaction, %Rule{} = rule, evaluator) do
    case evaluator.compile(rule.expression) do
      {:ok, compiled} ->
        rule_matches_facts?(facts_for_transaction(transaction), compiled, evaluator)

      {:error, _reason} ->
        false
    end
  end

  defp rule_matches_facts?(facts_list, compiled, evaluator) do
    Enum.any?(facts_list, fn facts ->
      case evaluator.evaluate(compiled, facts) do
        {:ok, true} -> true
        _ -> false
      end
    end)
  end

  defp apply_rule_actions(
         acc,
         _transaction,
         rule_group,
         rule,
         current_classification,
         protected_fields
       ) do
    grouped_actions = group_actions_by_field(rule.actions)

    Enum.reduce(grouped_actions, acc, fn {field, actions}, inner_acc ->
      current_value = classification_value(current_classification, field)

      change =
        build_field_change(
          field,
          actions,
          current_value,
          inner_acc,
          rule_group,
          rule,
          protected_fields
        )

      claims =
        if change.status == :proposed do
          MapSet.put(inner_acc.claims, field)
        else
          inner_acc.claims
        end

      %{
        inner_acc
        | claims: claims,
          result:
            (
              %Result{} = result = inner_acc.result

              %Result{
                result
                | proposed_changes: result.proposed_changes ++ [change]
              }
            )
      }
    end)
  end

  defp build_field_change(
         field,
         actions,
         current_value,
         inner_acc,
         rule_group,
         rule,
         protected_fields
       ) do
    value_result = apply_actions(field, actions, current_value)

    cond do
      field in protected_fields ->
        build_change(
          field,
          :protected,
          current_value,
          value_result,
          rule_group,
          rule,
          actions,
          :protected
        )

      MapSet.member?(inner_acc.claims, field) ->
        build_change(
          field,
          :skipped_claimed,
          current_value,
          value_result,
          rule_group,
          rule,
          actions,
          :field_claimed
        )

      true ->
        build_proposed_or_invalid_change(
          field,
          current_value,
          value_result,
          rule_group,
          rule,
          actions
        )
    end
  end

  defp build_proposed_or_invalid_change(
         field,
         current_value,
         {:ok, proposed_value},
         rule_group,
         rule,
         actions
       ) do
    build_change(
      field,
      :proposed,
      current_value,
      {:ok, proposed_value},
      rule_group,
      rule,
      actions,
      nil
    )
  end

  defp build_proposed_or_invalid_change(
         field,
         current_value,
         {:error, reason},
         rule_group,
         rule,
         actions
       ) do
    build_change(
      field,
      :invalid,
      current_value,
      {:error, reason},
      rule_group,
      rule,
      actions,
      reason
    )
  end

  defp build_change(field, status, current_value, value_result, rule_group, rule, actions, reason) do
    {proposed_value, normalized_reason} =
      case value_result do
        {:ok, proposed_value} -> {proposed_value, reason}
        {:error, error_reason} -> {nil, error_reason}
      end

    %ProposedChange{
      field: field,
      status: status,
      current_value: current_value,
      proposed_value: proposed_value,
      currently_overridden?: status == :protected,
      rule_group: rule_group,
      rule: rule,
      actions: actions,
      reason: normalized_reason
    }
  end

  defp matching_rule_groups(%Transaction{} = transaction, rule_groups) do
    posting_account_ids =
      transaction
      |> postings()
      |> Enum.map(& &1.account_id)
      |> MapSet.new()

    Enum.filter(rule_groups, fn
      %RuleGroup{is_active: false} ->
        false

      %RuleGroup{scope_type: :global} ->
        true

      %RuleGroup{scope_type: :entity, entity_id: entity_id} ->
        entity_id == transaction.entity_id

      %RuleGroup{scope_type: :account, account_id: account_id} ->
        MapSet.member?(posting_account_ids, account_id)

      _rule_group ->
        false
    end)
  end

  defp order_rule_groups(rule_groups) do
    Enum.sort_by(rule_groups, fn rule_group ->
      {scope_precedence(rule_group.scope_type), rule_group.priority || 0, rule_group.name || ""}
    end)
  end

  defp active_sorted_rules(%RuleGroup{} = rule_group) do
    rule_group
    |> Map.get(:rules, [])
    |> Enum.filter(& &1.is_active)
    |> Enum.sort_by(fn rule -> {rule.position || 0, rule.name || ""} end)
  end

  defp scope_precedence(:account), do: 0
  defp scope_precedence(:entity), do: 1
  defp scope_precedence(:global), do: 2
  defp scope_precedence(_scope_type), do: 3

  defp facts_for_transaction(%Transaction{} = transaction) do
    transaction_facts = %{
      description: transaction.description,
      date: transaction.date,
      source_type: transaction.source_type
    }

    case postings(transaction) do
      [] ->
        [Map.merge(transaction_facts, posting_facts(nil))]

      postings ->
        Enum.map(postings, &Map.merge(transaction_facts, posting_facts(&1)))
    end
  end

  defp postings(%Transaction{} = transaction), do: Map.get(transaction, :postings, [])

  defp posting_facts(nil) do
    %{
      amount: nil,
      abs_amount: nil,
      currency_code: nil,
      account_name: nil,
      account_type: nil,
      institution_name: nil
    }
  end

  defp posting_facts(%Posting{} = posting) do
    account = Map.get(posting, :account)

    %{
      amount: posting.amount,
      abs_amount: absolute_decimal(posting.amount),
      currency_code: account_value(account, :currency_code),
      account_name: account_value(account, :name),
      account_type: account_value(account, :account_type),
      institution_name: account_value(account, :institution_name)
    }
  end

  defp absolute_decimal(nil), do: nil
  defp absolute_decimal(%D{} = amount), do: D.abs(amount)

  defp account_value(%Account{} = account, field), do: Map.get(account, field)
  defp account_value(_account, _field), do: nil

  defp group_actions_by_field(actions) do
    {field_order, grouped} =
      Enum.reduce(actions, {[], %{}}, fn action, {field_order, grouped} ->
        field = normalize_action_field(action.field)

        cond do
          is_nil(field) ->
            {field_order, grouped}

          Map.has_key?(grouped, field) ->
            {field_order, Map.update!(grouped, field, &(&1 ++ [action]))}

          true ->
            {field_order ++ [field], Map.put(grouped, field, [action])}
        end
      end)

    Enum.map(field_order, &{&1, Map.fetch!(grouped, &1)})
  end

  defp normalize_action_field(field) when field in @classification_fields, do: field

  defp normalize_action_field(field) when is_binary(field) do
    case field do
      "category" -> :category
      "tags" -> :tags
      "investment_type" -> :investment_type
      "notes" -> :notes
      _ -> nil
    end
  end

  defp normalize_action_field(_field), do: nil

  defp apply_actions(field, actions, current_value) do
    Enum.reduce_while(actions, {:ok, current_value}, fn action, {:ok, value} ->
      case apply_action(field, action, value) do
        {:ok, next_value} -> {:cont, {:ok, next_value}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp apply_action(:category, %RuleAction{operation: :set, value: value}, _current_value) do
    if valid_uuid?(value), do: {:ok, value}, else: {:error, :invalid_category_value}
  end

  defp apply_action(:tags, %RuleAction{operation: :add, value: value}, current_value) do
    with {:ok, tag} <- normalize_tag(value) do
      tags =
        current_value
        |> normalize_tags()
        |> add_unique(tag)

      {:ok, tags}
    end
  end

  defp apply_action(:tags, %RuleAction{operation: :remove, value: value}, current_value) do
    with {:ok, tag} <- normalize_tag(value) do
      tags =
        current_value
        |> normalize_tags()
        |> Enum.reject(&(&1 == tag))

      {:ok, tags}
    end
  end

  defp apply_action(:investment_type, %RuleAction{operation: :set, value: value}, _current_value) do
    if is_binary(value) and String.trim(value) != "" do
      {:ok, value}
    else
      {:error, :invalid_investment_type_value}
    end
  end

  defp apply_action(:notes, %RuleAction{operation: :set, value: value}, _current_value) do
    if is_binary(value), do: {:ok, value}, else: {:error, :invalid_notes_value}
  end

  defp apply_action(:notes, %RuleAction{operation: :append, value: value}, current_value)
       when is_binary(value) do
    notes = if is_binary(current_value), do: current_value, else: ""

    case {notes, value} do
      {"", appended} -> {:ok, appended}
      {existing, appended} -> {:ok, existing <> "\n" <> appended}
    end
  end

  defp apply_action(_field, _action, _current_value), do: {:error, :invalid_action}

  defp normalize_tag(value) when is_binary(value) do
    case String.trim(value) do
      "" -> {:error, :invalid_tag_value}
      tag -> {:ok, tag}
    end
  end

  defp normalize_tag(_value), do: {:error, :invalid_tag_value}

  defp normalize_tags(tags) when is_list(tags) do
    tags
    |> Enum.filter(&is_binary/1)
    |> Enum.reduce([], &add_unique(&2, &1))
  end

  defp normalize_tags(_tags), do: []

  defp add_unique(list, value) do
    if value in list, do: list, else: list ++ [value]
  end

  defp classification_value(classification, field) do
    Map.get(classification, field, default_value(field))
  end

  defp default_value(:tags), do: []
  defp default_value(_field), do: nil

  defp normalize_protected_fields(classification) do
    classification
    |> Map.get(:protected_fields, [])
    |> case do
      %MapSet{} = protected_fields -> protected_fields
      protected_fields when is_list(protected_fields) -> MapSet.new(protected_fields)
      _other -> MapSet.new()
    end
  end

  defp valid_uuid?(value) when is_binary(value) do
    match?({:ok, _uuid}, Ecto.UUID.cast(value))
  end

  defp valid_uuid?(_value), do: false
end
