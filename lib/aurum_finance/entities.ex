defmodule AurumFinance.Entities do
  @moduledoc """
  The Entities context, responsible for the ownership boundary model.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Entities.Entity
  alias AurumFinance.Repo

  @type list_opt ::
          {:include_archived, boolean()}
          | {:type, :individual | :legal_entity | :trust | :other}
          | {:country_code, String.t()}
          | {:search, String.t()}

  @doc """
  Lists entities with optional filters.

  By default, archived entities are excluded.

  ## Examples

      iex> function_exported?(AurumFinance.Entities, :list_entities, 1)
      true
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

  ## Examples

      iex> function_exported?(AurumFinance.Entities, :get_entity!, 1)
      true
  """
  @spec get_entity!(Ecto.UUID.t()) :: Entity.t()
  def get_entity!(id), do: Repo.get!(Entity, id)

  @doc """
  Creates an entity.

  Returns `{:ok, entity}` on success or `{:error, changeset}` on validation failure.

  ## Examples

      iex> function_exported?(AurumFinance.Entities, :create_entity, 1)
      true
  """
  @spec create_entity(map()) :: {:ok, Entity.t()} | {:error, Ecto.Changeset.t()}
  def create_entity(attrs) do
    %Entity{}
    |> Entity.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing entity.

  Returns `{:ok, entity}` on success or `{:error, changeset}` on validation failure.

  ## Examples

      iex> function_exported?(AurumFinance.Entities, :update_entity, 2)
      true
  """
  @spec update_entity(Entity.t(), map()) :: {:ok, Entity.t()} | {:error, Ecto.Changeset.t()}
  def update_entity(%Entity{} = entity, attrs) do
    entity
    |> Entity.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Soft-archives an entity by setting `archived_at`.

  This context does not expose hard delete paths.

  ## Examples

      iex> function_exported?(AurumFinance.Entities, :archive_entity, 1)
      true
  """
  @spec archive_entity(Entity.t()) :: {:ok, Entity.t()} | {:error, Ecto.Changeset.t()}
  def archive_entity(%Entity{} = entity) do
    update_entity(entity, %{archived_at: DateTime.utc_now()})
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
