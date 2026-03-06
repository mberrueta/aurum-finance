defmodule AurumFinance.Audit do
  @moduledoc """
  The Audit context, responsible for generic audit event tracking.
  """

  import Ecto.Query, warn: false

  require Logger

  alias AurumFinance.Audit.AuditEvent
  alias AurumFinance.Repo

  @redacted_value "[REDACTED]"

  @type audit_channel :: :web | :system | :mcp | :ai_assistant

  @type list_opt ::
          {:entity_type, String.t()}
          | {:entity_id, Ecto.UUID.t()}
          | {:channel, audit_channel()}
          | {:action, String.t()}
          | {:limit, pos_integer()}

  @type with_event_meta :: %{
          required(:event) => String.t(),
          optional(:target) => term(),
          optional(:entity_type) => String.t(),
          optional(:actor) => String.t(),
          optional(:channel) => audit_channel(),
          optional(:redact_fields) => [atom() | String.t()]
        }

  @doc """
  Executes an operation and synchronously logs a generic audit event.

  The wrapped operation must return `{:ok, result}` or `{:error, changeset}`.

  If audit persistence fails, this function returns
  `{:error, {:audit_failed, changeset, result}}` and logs a strong error entry.

  ## Parameters
  - `meta`: metadata used to build the audit event.
    - required: `:event` (`"entity.updated"`, `"entity.created"`, etc.)
    - optional: `:target` (pre-operation struct/map for `before` snapshot)
    - optional: `:entity_type` (explicit type override)
    - optional: `:actor` (string describing who triggered the change, e.g. `"system"`, `"person"`, `"scheduler"`)
      Single-user note: actor is intentionally a plain string, not a structured map.
    - optional: `:channel` (`:web | :system | :mcp | :ai_assistant`)
    - optional: `:redact_fields` (keys to redact in `before`/`after`)
  - `operation_fun`: zero-arity function that performs the domain operation.
  - `opts`: optional settings.
    - `:serializer` - function to serialize snapshots (default: map conversion)

  ## Examples

  Happy path usage:

  ```elixir
  Audit.with_event(
    %{
      event: "entity.updated",
      target: entity,
      actor: "person",
      channel: :web
    },
    fn -> Repo.update(Entity.changeset(entity, attrs)) end,
    serializer: &MyApp.Entities.snapshot/1
  )
  ```

  Error passthrough (doctest-safe):

      iex> changeset =
      ...>   Ecto.Changeset.change(%{})
      ...>   |> Ecto.Changeset.add_error(:base, "operation failed")
      iex> {:error, returned} =
      ...>   AurumFinance.Audit.with_event(
      ...>     %{event: "entity.updated"},
      ...>     fn -> {:error, changeset} end
      ...>   )
      iex> returned.errors[:base] |> elem(0)
      "operation failed"
  """
  @spec with_event(
          with_event_meta(),
          (-> {:ok, term()} | {:error, Ecto.Changeset.t()}),
          keyword()
        ) ::
          {:ok, term()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, Ecto.Changeset.t(), term()}}
  def with_event(meta, operation_fun, opts \\ [])
      when is_map(meta) and is_function(operation_fun, 0) do
    serializer = Keyword.get(opts, :serializer, &default_snapshot/1)
    before_state = snapshot(meta[:target], serializer, meta[:redact_fields] || [])

    with {:ok, result} <- operation_fun.(),
         attrs <- build_event_attrs(meta, result, before_state, serializer),
         :ok <- ensure_audit_logged(attrs, result) do
      {:ok, result}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:audit_failed, %Ecto.Changeset{} = changeset, result, attrs} ->
        Logger.error(
          "AUDIT_WRITE_FAILED event=#{meta[:event]} entity_type=#{attrs.entity_type} entity_id=#{attrs.entity_id} channel=#{attrs.channel} actor=#{inspect(attrs.actor)} errors=#{inspect(changeset.errors)}"
        )

        {:error, {:audit_failed, changeset, result}}
    end
  end

  @doc """
  Creates an audit event and returns the inserted record.
  """
  @spec create_audit_event(map()) :: {:ok, AuditEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_audit_event(attrs) do
    %AuditEvent{}
    |> AuditEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Logs an audit event synchronously.

  Returns `:ok` when persistence succeeds and `{:error, changeset}` when it fails.
  """
  @spec log_event(map()) :: :ok | {:error, Ecto.Changeset.t()}
  def log_event(attrs) do
    attrs = Map.put_new(attrs, :occurred_at, DateTime.utc_now())

    case create_audit_event(attrs) do
      {:ok, _audit_event} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Lists audit events with optional filters.

  Results are ordered by `occurred_at` descending.
  """
  @spec list_audit_events([list_opt()]) :: [AuditEvent.t()]
  def list_audit_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)

    AuditEvent
    |> filter_query(opts)
    |> order_by([audit_event], desc: audit_event.occurred_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Returns a changeset for audit event form or pipeline handling.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Audit.change_audit_event(%AurumFinance.Audit.AuditEvent{}, %{
      ...>     entity_type: "entity",
      ...>     entity_id: Ecto.UUID.generate(),
      ...>     action: "created",
      ...>     actor: "root",
      ...>     channel: :web,
      ...>     occurred_at: DateTime.utc_now()
      ...>   })
      iex> changeset.valid?
      true
  """
  @spec change_audit_event(AuditEvent.t(), map()) :: Ecto.Changeset.t()
  def change_audit_event(%AuditEvent{} = audit_event, attrs \\ %{}) do
    AuditEvent.changeset(audit_event, attrs)
  end

  defp build_event_attrs(meta, result, before_state, serializer) do
    after_state = snapshot(result, serializer, meta[:redact_fields] || [])

    %{
      entity_type: meta[:entity_type] || infer_entity_type(result, meta[:target]),
      entity_id: infer_entity_id(result, meta[:target]),
      action: meta[:event],
      actor: normalize_actor(meta[:actor]),
      channel: normalize_channel(meta[:channel]),
      before: before_state,
      after: after_state,
      occurred_at: DateTime.utc_now()
    }
  end

  defp ensure_audit_logged(attrs, result) do
    case log_event(attrs) do
      :ok -> :ok
      {:error, %Ecto.Changeset{} = changeset} -> {:audit_failed, changeset, result, attrs}
    end
  end

  defp snapshot(nil, _serializer, _redact_fields), do: nil

  defp snapshot(value, serializer, redact_fields) do
    value
    |> serializer.()
    |> redact_snapshot(redact_fields)
  end

  defp default_snapshot(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> stringify_keys()
  end

  defp default_snapshot(map) when is_map(map), do: stringify_keys(map)
  defp default_snapshot(other), do: %{"value" => inspect(other)}

  defp redact_snapshot(snapshot, []), do: snapshot

  defp redact_snapshot(snapshot, redact_fields) do
    redact_keys = MapSet.new(Enum.map(redact_fields, &to_string/1))
    do_redact(snapshot, redact_keys)
  end

  defp do_redact(map, redact_keys) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      key_string = to_string(key)

      redacted_value =
        if MapSet.member?(redact_keys, key_string) do
          @redacted_value
        else
          do_redact(value, redact_keys)
        end

      Map.put(acc, key_string, redacted_value)
    end)
  end

  defp do_redact(list, redact_keys) when is_list(list),
    do: Enum.map(list, &do_redact(&1, redact_keys))

  defp do_redact(value, _redact_keys), do: value

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), stringify_value(value))
    end)
  end

  defp stringify_value(%_{} = struct), do: default_snapshot(struct)
  defp stringify_value(map) when is_map(map), do: stringify_keys(map)
  defp stringify_value(list) when is_list(list), do: Enum.map(list, &stringify_value/1)
  defp stringify_value(value), do: value

  defp infer_entity_type(%{__struct__: module}, _target),
    do: module |> Module.split() |> List.last() |> Macro.underscore()

  defp infer_entity_type(_result, %{__struct__: module}),
    do: module |> Module.split() |> List.last() |> Macro.underscore()

  defp infer_entity_type(_result, _target), do: "unknown"

  defp infer_entity_id(%{id: id}, _target) when not is_nil(id), do: id
  defp infer_entity_id(_result, %{id: id}) when not is_nil(id), do: id
  defp infer_entity_id(_result, _target), do: nil

  defp normalize_actor(actor) when is_binary(actor) do
    actor
    |> String.trim()
    |> case do
      "" -> "system"
      value -> value
    end
  end

  defp normalize_actor(_actor), do: "system"

  defp normalize_channel(channel) when channel in [:web, :system, :mcp, :ai_assistant],
    do: channel

  defp normalize_channel(_channel), do: :system

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:entity_type, entity_type} | rest]) do
    query
    |> where([audit_event], audit_event.entity_type == ^entity_type)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:entity_id, entity_id} | rest]) do
    query
    |> where([audit_event], audit_event.entity_id == ^entity_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:channel, channel} | rest]) do
    query
    |> where([audit_event], audit_event.channel == ^channel)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:action, action} | rest]) do
    query
    |> where([audit_event], audit_event.action == ^action)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:limit, _limit} | rest]) do
    filter_query(query, rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end
end
