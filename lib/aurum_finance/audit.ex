defmodule AurumFinance.Audit do
  @moduledoc """
  The Audit context, responsible for generic audit event tracking.

  Provides atomic helpers that wrap domain writes with audit event appends
  in a single database transaction. All domain contexts should use these
  helpers rather than managing audit persistence directly.

  ## Helpers

    - `insert_and_log/2` - insert a new record and log a "created" event
    - `update_and_log/3` - update a record and log an event (action from meta)
    - `archive_and_log/3` - archive a record and log an "archived" event

  For complex multi-step operations, use `AurumFinance.Audit.Multi.append_event/4`.
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
          | {:offset, non_neg_integer()}
          | {:occurred_after, DateTime.t()}
          | {:occurred_before, DateTime.t()}

  @type meta :: %{
          required(:actor) => String.t(),
          required(:channel) => audit_channel(),
          required(:entity_type) => String.t(),
          optional(:action) => String.t(),
          optional(:redact_fields) => [atom() | String.t()],
          optional(:metadata) => map(),
          optional(:serializer) => (term() -> map())
        }

  # ---------------------------------------------------------------------------
  # Atomic helpers
  # ---------------------------------------------------------------------------

  @doc """
  Inserts a record via the given changeset and appends a "created" audit event
  atomically in a single database transaction.

  ## Parameters

    - `changeset` - an `Ecto.Changeset` for the new record
    - `meta` - audit metadata (see `t:meta/0`)

  ## Returns

    - `{:ok, struct}` on success
    - `{:error, changeset}` if the domain insert fails
    - `{:error, {:audit_failed, reason}}` if the audit insert fails

  ## Examples

      changeset = Entity.changeset(%Entity{}, %{name: "Acme Corp"})
      meta = %{actor: "root", channel: :web, entity_type: "entity"}

      {:ok, entity} = Audit.insert_and_log(changeset, meta)

  With optional redaction and custom action:

      meta = %{
        actor: "root",
        channel: :web,
        entity_type: "entity",
        action: "onboarded",
        redact_fields: [:tax_identifier]
      }

      {:ok, entity} = Audit.insert_and_log(changeset, meta)
  """
  @spec insert_and_log(Ecto.Changeset.t(), meta()) ::
          {:ok, term()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def insert_and_log(changeset, meta) do
    serializer = Map.get(meta, :serializer, &default_snapshot/1)
    redact_fields = Map.get(meta, :redact_fields, [])
    action = Map.get(meta, :action, "created")

    Repo.transaction(fn ->
      with {:domain, {:ok, record}} <- {:domain, Repo.insert(changeset)},
           after_snapshot = record |> serializer.() |> redact_snapshot(redact_fields),
           audit_attrs = build_audit_attrs(meta, record.id, action, nil, after_snapshot),
           {:audit, {:ok, _event}} <- {:audit, create_audit_event(audit_attrs)} do
        record
      else
        {:domain, {:error, cs}} -> Repo.rollback(cs)
        {:audit, {:error, reason}} -> Repo.rollback({:audit_failed, reason})
      end
    end)
    |> normalize_transaction_result()
  end

  @doc """
  Updates an existing record and appends an audit event atomically in a single
  database transaction.

  ## Parameters

    - `struct` - the pre-update struct (used for the `before` snapshot)
    - `changeset` - an `Ecto.Changeset` for the update
    - `meta` - audit metadata (see `t:meta/0`); `:action` defaults to `"updated"`

  ## Returns

    - `{:ok, struct}` on success
    - `{:error, changeset}` if the domain update fails
    - `{:error, {:audit_failed, reason}}` if the audit insert fails

  ## Examples

      changeset = Entity.changeset(entity, %{name: "Acme Corp Ltd"})
      meta = %{actor: "root", channel: :web, entity_type: "entity"}

      {:ok, updated_entity} = Audit.update_and_log(entity, changeset, meta)

  The `before` snapshot is captured from `entity` before the update; the `after`
  snapshot is captured from the returned updated struct.
  """
  @spec update_and_log(struct(), Ecto.Changeset.t(), meta()) ::
          {:ok, term()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def update_and_log(struct, changeset, meta) do
    serializer = Map.get(meta, :serializer, &default_snapshot/1)
    redact_fields = Map.get(meta, :redact_fields, [])
    action = Map.get(meta, :action, "updated")

    before_snapshot =
      struct
      |> serializer.()
      |> redact_snapshot(redact_fields)

    Repo.transaction(fn ->
      with {:domain, {:ok, updated}} <- {:domain, Repo.update(changeset)},
           after_snapshot = updated |> serializer.() |> redact_snapshot(redact_fields),
           audit_attrs =
             build_audit_attrs(meta, updated.id, action, before_snapshot, after_snapshot),
           {:audit, {:ok, _event}} <- {:audit, create_audit_event(audit_attrs)} do
        updated
      else
        {:domain, {:error, cs}} -> Repo.rollback(cs)
        {:audit, {:error, reason}} -> Repo.rollback({:audit_failed, reason})
      end
    end)
    |> normalize_transaction_result()
  end

  @doc """
  Archives (soft-deletes) a record and appends an "archived" audit event
  atomically. Semantic alias for `update_and_log/3` with action `"archived"`.

  ## Parameters

    - `struct` - the pre-archive struct (used for the `before` snapshot)
    - `changeset` - an `Ecto.Changeset` that sets `archived_at`
    - `meta` - audit metadata (see `t:meta/0`); `:action` defaults to `"archived"`

  ## Returns

  Same as `update_and_log/3`.

  ## Examples

      changeset = Entity.archive_changeset(entity)
      meta = %{actor: "root", channel: :web, entity_type: "entity"}

      {:ok, archived_entity} = Audit.archive_and_log(entity, changeset, meta)
  """
  @spec archive_and_log(struct(), Ecto.Changeset.t(), meta()) ::
          {:ok, term()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def archive_and_log(struct, changeset, meta) do
    meta = Map.put_new(meta, :action, "archived")
    update_and_log(struct, changeset, meta)
  end

  # ---------------------------------------------------------------------------
  # Query / Read API
  # ---------------------------------------------------------------------------

  @doc """
  Creates an audit event and returns the inserted record.

  Prefer the atomic helpers (`insert_and_log/2`, `update_and_log/3`,
  `archive_and_log/3`) which apply redaction and wrap domain writes in a
  single transaction. Call this directly only when building a custom pipeline
  that already manages its own transaction.

  ## Examples

      attrs = %{
        entity_type: "entity",
        entity_id: Ecto.UUID.generate(),
        action: "created",
        actor: "root",
        channel: :web,
        occurred_at: DateTime.utc_now()
      }

      {:ok, %AuditEvent{}} = Audit.create_audit_event(attrs)
  """
  @spec create_audit_event(map()) :: {:ok, AuditEvent.t()} | {:error, Ecto.Changeset.t()}
  def create_audit_event(attrs) do
    %AuditEvent{}
    |> AuditEvent.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists audit events with optional filters.

  Results are ordered by `occurred_at` descending.

  ## Supported filters

    - `{:entity_type, String.t()}`
    - `{:entity_id, Ecto.UUID.t()}`
    - `{:channel, audit_channel()}`
    - `{:action, String.t()}`
    - `{:occurred_after, DateTime.t()}`
    - `{:occurred_before, DateTime.t()}`
    - `{:limit, pos_integer()}` (default 100)
    - `{:offset, non_neg_integer()}`

  ## Examples

      # All events, newest first (default limit 100)
      events = Audit.list_audit_events()

      # Events for a specific entity
      events = Audit.list_audit_events(entity_type: "account", entity_id: account.id)

      # Events filtered by channel and time range, paginated
      events =
        Audit.list_audit_events(
          channel: :web,
          occurred_after: ~U[2026-01-01 00:00:00Z],
          limit: 25,
          offset: 50
        )
  """
  @spec list_audit_events([list_opt()]) :: [AuditEvent.t()]
  def list_audit_events(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    AuditEvent
    |> filter_query(opts)
    |> order_by([audit_event], desc: audit_event.occurred_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc """
  Returns distinct `entity_type` values from the audit_events table.

  Used to populate filter dropdowns in the audit log viewer.

  ## Examples

      # Returns sorted list of entity types present in the log
      ["account", "entity", "transaction"] = Audit.distinct_entity_types()
  """
  @spec distinct_entity_types() :: [String.t()]
  def distinct_entity_types do
    AuditEvent
    |> distinct(true)
    |> select([ae], ae.entity_type)
    |> order_by([ae], asc: ae.entity_type)
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

  # ---------------------------------------------------------------------------
  # Snapshot & Redaction (public for use by Audit.Multi)
  # ---------------------------------------------------------------------------

  @doc false
  @spec default_snapshot(term()) :: map()
  def default_snapshot(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
    |> stringify_keys()
  end

  def default_snapshot(map) when is_map(map), do: stringify_keys(map)
  def default_snapshot(other), do: %{"value" => inspect(other)}

  @doc false
  @spec redact_snapshot(map() | nil, [atom() | String.t()]) :: map() | nil
  def redact_snapshot(nil, _redact_fields), do: nil
  def redact_snapshot(snapshot, []), do: snapshot

  def redact_snapshot(snapshot, redact_fields) do
    redact_keys = MapSet.new(Enum.map(redact_fields, &to_string/1))
    do_redact(snapshot, redact_keys)
  end

  @doc false
  @spec normalize_actor(term()) :: String.t()
  def normalize_actor(actor) when is_binary(actor) do
    case String.trim(actor) do
      "" -> "system"
      trimmed -> trimmed
    end
  end

  def normalize_actor(_actor), do: "system"

  @doc false
  @spec normalize_channel(term()) :: audit_channel()
  def normalize_channel(channel) when channel in [:web, :system, :mcp, :ai_assistant],
    do: channel

  def normalize_channel(_channel), do: :system

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_audit_attrs(meta, entity_id, action, before_snapshot, after_snapshot) do
    %{
      entity_type: meta.entity_type,
      entity_id: entity_id,
      action: action,
      actor: normalize_actor(meta[:actor]),
      channel: normalize_channel(meta[:channel]),
      before: before_snapshot,
      after: after_snapshot,
      metadata: Map.get(meta, :metadata),
      occurred_at: DateTime.utc_now()
    }
  end

  defp normalize_transaction_result({:ok, result}), do: {:ok, result}

  defp normalize_transaction_result({:error, {:audit_failed, reason}}),
    do: {:error, {:audit_failed, reason}}

  defp normalize_transaction_result({:error, %Ecto.Changeset{} = changeset}),
    do: {:error, changeset}

  defp do_redact(%_{} = struct, redact_keys) do
    do_redact_struct(struct, redact_keys)
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

  defp do_redact_struct(%DateTime{} = value, _redact_keys), do: value
  defp do_redact_struct(%NaiveDateTime{} = value, _redact_keys), do: value
  defp do_redact_struct(%Date{} = value, _redact_keys), do: value
  defp do_redact_struct(%Time{} = value, _redact_keys), do: value
  defp do_redact_struct(%Decimal{} = value, _redact_keys), do: value
  defp do_redact_struct(struct, _redact_keys), do: struct

  defp stringify_keys(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), stringify_value(value))
    end)
  end

  defp stringify_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp stringify_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp stringify_value(%Date{} = value), do: Date.to_iso8601(value)
  defp stringify_value(%Time{} = value), do: Time.to_iso8601(value)
  defp stringify_value(%Decimal{} = value), do: Decimal.to_string(value)
  defp stringify_value(%_{} = struct), do: default_snapshot(struct)
  defp stringify_value(map) when is_map(map), do: stringify_keys(map)
  defp stringify_value(list) when is_list(list), do: Enum.map(list, &stringify_value/1)
  defp stringify_value(value), do: value

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

  defp filter_query(query, [{:occurred_after, %DateTime{} = dt} | rest]) do
    query
    |> where([audit_event], audit_event.occurred_at >= ^dt)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:occurred_before, %DateTime{} = dt} | rest]) do
    query
    |> where([audit_event], audit_event.occurred_at <= ^dt)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:limit, _limit} | rest]) do
    filter_query(query, rest)
  end

  defp filter_query(query, [{:offset, _offset} | rest]) do
    filter_query(query, rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end
end
