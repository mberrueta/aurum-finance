defmodule AurumFinance.Entities do
  @moduledoc """
  The Entities context, responsible for the ownership boundary model.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Repo

  @entity_type "entity"
  @default_actor "system"
  @audit_redact_fields [:tax_identifier]

  @type list_opt ::
          {:include_archived, boolean()}
          | {:type, :individual | :legal_entity | :trust | :other}
          | {:country_code, String.t()}
          | {:search, String.t()}

  @type audit_opt ::
          {:actor, String.t()}
          | {:channel, :web | :system | :mcp | :ai_assistant}

  @doc """
  Lists entities with optional filters.

  By default, archived entities are excluded.
  """
  @spec list_entities([list_opt()]) :: [Entity.t()]
  def list_entities(opts \\ []) do
    opts = Keyword.put_new(opts, :include_archived, false)

    Entity
    |> filter_query(opts)
    |> order_by([entity], asc: entity.name)
    |> Repo.all()
  end

  @doc """
  Fetches one entity by id.

  Raises `Ecto.NoResultsError` when the id does not exist.
  """
  @spec get_entity!(Ecto.UUID.t()) :: Entity.t()
  def get_entity!(id), do: Repo.get!(Entity, id)

  @doc """
  Creates an entity and emits an audit event.

  Optional audit metadata can be passed with `opts`:
  - `:actor` (string)
  - `:channel` (`:web | :system | :mcp | :ai_assistant`)
  """
  @spec create_entity(map()) :: {:ok, Entity.t()} | {:error, Ecto.Changeset.t()}
  @spec create_entity(map(), [audit_opt()]) ::
          {:ok, Entity.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def create_entity(attrs, opts \\ []) do
    changeset = Entity.changeset(%Entity{}, attrs)

    Audit.insert_and_log(changeset, audit_meta(opts))
  end

  @doc """
  Updates an existing entity and emits an audit event.

  Optional audit metadata can be passed with `opts`:
  - `:actor` (string)
  - `:channel` (`:web | :system | :mcp | :ai_assistant`)
  """
  @spec update_entity(Entity.t(), map()) :: {:ok, Entity.t()} | {:error, Ecto.Changeset.t()}
  @spec update_entity(Entity.t(), map(), [audit_opt()]) ::
          {:ok, Entity.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def update_entity(%Entity{} = entity, attrs, opts \\ []) do
    changeset = Entity.changeset(entity, attrs)

    Audit.update_and_log(entity, changeset, audit_meta(opts, action: "updated"))
  end

  @doc """
  Soft-archives an entity by setting `archived_at` and emits an audit event.

  This context does not expose hard delete paths.

  Optional audit metadata can be passed with `opts`:
  - `:actor` (string)
  - `:channel` (`:web | :system | :mcp | :ai_assistant`)
  """
  @spec archive_entity(Entity.t()) :: {:ok, Entity.t()} | {:error, Ecto.Changeset.t()}
  @spec archive_entity(Entity.t(), [audit_opt()]) ::
          {:ok, Entity.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def archive_entity(%Entity{} = entity, opts \\ []) do
    changeset = Entity.changeset(entity, %{archived_at: DateTime.utc_now()})

    Audit.archive_and_log(entity, changeset, audit_meta(opts))
  end

  @doc """
  Removes archive state from an entity by setting `archived_at` to `nil` and emits an audit event.

  Optional audit metadata can be passed with `opts`:
  - `:actor` (string)
  - `:channel` (`:web | :system | :mcp | :ai_assistant`)
  """
  @spec unarchive_entity(Entity.t()) :: {:ok, Entity.t()} | {:error, Ecto.Changeset.t()}
  @spec unarchive_entity(Entity.t(), [audit_opt()]) ::
          {:ok, Entity.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def unarchive_entity(%Entity{} = entity, opts \\ []) do
    changeset = Entity.changeset(entity, %{archived_at: nil})

    Audit.update_and_log(entity, changeset, audit_meta(opts, action: "unarchived"))
  end

  @doc """
  Returns a changeset for entity form handling.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Entities.change_entity(%AurumFinance.Entities.Entity{}, %{
      ...>     name: "Personal",
      ...>     type: :individual,
      ...>     country_code: "br"
      ...>   })
      iex> changeset.valid?
      true

  """
  @spec change_entity(Entity.t(), map()) :: Ecto.Changeset.t()
  def change_entity(%Entity{} = entity, attrs \\ %{}) do
    Entity.changeset(entity, attrs)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp entity_snapshot(%Entity{} = entity) do
    %{
      "id" => entity.id,
      "name" => entity.name,
      "type" => entity.type,
      "tax_identifier" => entity.tax_identifier,
      "country_code" => entity.country_code,
      "fiscal_residency_country_code" => entity.fiscal_residency_country_code,
      "default_tax_rate_type" => entity.default_tax_rate_type,
      "notes" => entity.notes,
      "archived_at" => entity.archived_at,
      "inserted_at" => entity.inserted_at,
      "updated_at" => entity.updated_at
    }
  end

  defp audit_meta(opts, overrides \\ []) do
    actor =
      opts
      |> Keyword.get(:actor, @default_actor)
      |> Audit.normalize_actor()

    channel =
      opts
      |> Keyword.get(:channel, :system)
      |> Audit.normalize_channel()

    base = %{
      actor: actor,
      channel: channel,
      entity_type: @entity_type,
      redact_fields: @audit_redact_fields,
      serializer: &entity_snapshot/1
    }

    Enum.reduce(overrides, base, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:include_archived, true} | rest]) do
    filter_query(query, rest)
  end

  defp filter_query(query, [{:include_archived, false} | rest]) do
    query
    |> where([entity], is_nil(entity.archived_at))
    |> filter_query(rest)
  end

  defp filter_query(query, [{:type, type} | rest]) do
    query
    |> where([entity], entity.type == ^type)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:country_code, country_code} | rest]) do
    normalized_country_code = normalize_to_upper(country_code)

    query
    |> where([entity], entity.country_code == ^normalized_country_code)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:search, search} | rest]) do
    pattern = "%#{String.trim(search)}%"

    query
    |> where([entity], ilike(entity.name, ^pattern))
    |> filter_query(rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end

  defp normalize_to_upper(value) when is_binary(value), do: String.upcase(value)
  defp normalize_to_upper(value), do: value
end
