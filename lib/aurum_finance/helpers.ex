defmodule AurumFinance.Helpers do
  @moduledoc """
  Shared helper functions for AurumFinance.
  """

  @doc """
  Deeply converts map string keys to atoms when those atoms already exist.

  Unknown string keys remain as strings.
  """
  def deep_atomize(map) when is_map(map) do
    Map.new(map, fn
      {key, %Decimal{} = val} ->
        {to_atom(key), val}

      {key, %Date{} = val} ->
        {to_atom(key), val}

      {key, %DateTime{} = val} ->
        {to_atom(key), val}

      {key, value} when is_map(value) ->
        {to_atom(key), deep_atomize(value)}

      {key, value} when is_list(value) ->
        {to_atom(key), Enum.map(value, &deep_atomize/1)}

      {key, value} ->
        {to_atom(key), value}
    end)
  end

  def deep_atomize(value) when is_list(value), do: Enum.map(value, &deep_atomize/1)
  def deep_atomize(value), do: value

  @doc """
  Converts text into a URL slug.
  """
  def slugify(nil), do: nil
  def slugify(""), do: ""

  def slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/u, "")
    |> String.trim()
    |> String.split(~r/\s+/)
    |> Enum.join("-")
  end

  @doc """
  Formats an identifier-like token to human-readable text.

  ## Examples

      iex> AurumFinance.Helpers.humanize_token("legal_entity")
      "Legal entity"

      iex> AurumFinance.Helpers.humanize_token(:market_close)
      "Market close"
  """
  def humanize_token(token) when is_binary(token) do
    token
    |> String.replace("_", " ")
    |> String.trim()
    |> String.capitalize()
  end

  def humanize_token(token) when is_atom(token), do: token |> Atom.to_string() |> humanize_token()
  def humanize_token(token), do: token |> to_string() |> humanize_token()

  @doc """
  Returns true when a value is nil or blank string.
  """
  def blank?(nil), do: true
  def blank?(str) when is_binary(str), do: String.trim(str) == ""
  def blank?(_), do: false

  @doc """
  Safe indifferent map access for atom/string keys.
  """
  def map_get(map, key) when is_atom(key), do: Map.get(map, key) || Map.get(map, to_string(key))
  def map_get(map, key) when is_binary(key), do: Map.get(map, key) || Map.get(map, to_atom(key))

  defp to_atom(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end

  defp to_atom(key) when is_atom(key), do: key
end
