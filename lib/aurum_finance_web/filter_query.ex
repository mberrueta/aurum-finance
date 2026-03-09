defmodule AurumFinanceWeb.FilterQuery do
  @moduledoc """
  Encodes and decodes the project's compact `?q=key:value&key:value` URL filter format.

  This module is intentionally pure and stateless so LiveViews can share the same
  URL filter behavior without duplicating parsing or encoding logic.
  """

  @type clause_key :: String.t() | atom()
  @type clause_value :: term()

  @doc """
  Decodes a raw URI query string into a `%{key => value}` map.

  Returns an empty map for `nil`, empty input, or malformed clauses.

  ## Examples

      iex> AurumFinanceWeb.FilterQuery.decode(nil)
      %{}

      iex> AurumFinanceWeb.FilterQuery.decode("q=entity:123&source:manual")
      %{"entity" => "123", "source" => "manual"}
  """
  @spec decode(String.t() | nil) :: %{String.t() => String.t()}
  def decode(nil), do: %{}
  def decode(""), do: %{}

  def decode(query_string) do
    query_string
    |> extract_q_payload()
    |> URI.decode()
    |> String.split("&", trim: true)
    |> Enum.reduce(%{}, fn clause, acc ->
      case String.split(clause, ":", parts: 2) do
        [key, value] when key != "" and value != "" -> Map.put(acc, key, value)
        _parts -> acc
      end
    end)
  end

  @doc """
  Encodes a list of `{key, value}` pairs into the compact `?q=` query string.

  Pairs with `nil`, `false`, or empty-string values are omitted. Returns `nil`
  when no clauses survive filtering.

  ## Examples

      iex> AurumFinanceWeb.FilterQuery.encode(entity: "123", source: "manual")
      "?q=entity:123&source:manual"

      iex> AurumFinanceWeb.FilterQuery.encode(entity: nil, source: "")
      nil
  """
  @spec encode(keyword() | [{clause_key(), clause_value()}]) :: String.t() | nil
  def encode(clauses) do
    encoded_clauses =
      Enum.reduce(clauses, [], fn {key, value}, acc ->
        maybe_add_clause(acc, key, value)
      end)

    case encoded_clauses do
      [] -> nil
      _clauses -> "?q=" <> Enum.join(encoded_clauses, "&")
    end
  end

  @doc """
  Builds a path with the encoded compact query string appended when needed.

  ## Examples

      iex> AurumFinanceWeb.FilterQuery.build_path("/transactions", entity: "123", source: "manual")
      "/transactions?q=entity:123&source:manual"

      iex> AurumFinanceWeb.FilterQuery.build_path("/transactions", entity: nil, source: "")
      "/transactions"
  """
  @spec build_path(String.t(), keyword() | [{clause_key(), clause_value()}]) :: String.t()
  def build_path(base_path, clauses) do
    case encode(clauses) do
      nil -> base_path
      query -> base_path <> query
    end
  end

  @doc """
  Returns `nil` when the value matches the default, otherwise returns the value.

  ## Examples

      iex> AurumFinanceWeb.FilterQuery.skip_default("all", "all")
      nil

      iex> AurumFinanceWeb.FilterQuery.skip_default("this_month", "all")
      "this_month"
  """
  @spec skip_default(term(), term()) :: term() | nil
  def skip_default(value, default) when value == default, do: nil
  def skip_default(value, _default), do: value

  defp maybe_add_clause(clauses, _key, nil), do: clauses
  defp maybe_add_clause(clauses, _key, false), do: clauses
  defp maybe_add_clause(clauses, _key, ""), do: clauses
  defp maybe_add_clause(clauses, key, value), do: clauses ++ ["#{key}:#{value}"]

  defp extract_q_payload("q=" <> payload), do: payload

  defp extract_q_payload(query_string) do
    case URI.decode_query(query_string) do
      %{"q" => payload} -> payload
      _params -> ""
    end
  end
end
