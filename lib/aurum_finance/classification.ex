defmodule AurumFinance.Classification do
  @moduledoc """
  Classification context for scoped rule groups, ordered rules, and DSL-backed
  rule authoring.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Audit.Multi, as: AuditMulti
  alias AurumFinance.Classification.ExpressionCompiler
  alias AurumFinance.Classification.ExpressionValidator
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Repo

  @default_actor "system"
  @rule_group_entity_type "rule_group"
  @rule_entity_type "rule"

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
             delete_rule_group: 2, delete_rule: 2, new_multi: 0, multi_delete: 3}

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
    |> preload([:entity, :account])
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
  def update_rule_group(%RuleGroup{} = rule_group, attrs, opts \\ []) do
    changeset = RuleGroup.changeset(rule_group, attrs)

    Audit.update_and_log(rule_group, changeset, rule_group_audit_meta(opts, action: "updated"))
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
  def delete_rule_group(%RuleGroup{} = rule_group, opts \\ []) do
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
          AurumFinanceWeb.Gettext,
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
      Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_expression_required")
    )
  end

  defp rule_changeset_error(rule, attrs, :invalid_regex) do
    rule
    |> Rule.changeset(normalize_attrs(attrs))
    |> Ecto.Changeset.add_error(
      :expression,
      Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_expression_invalid_regex")
    )
  end

  defp rule_changeset_error(rule, attrs, _reason) do
    rule
    |> Rule.changeset(normalize_attrs(attrs))
    |> Ecto.Changeset.add_error(
      :expression,
      Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_expression_invalid")
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
end
