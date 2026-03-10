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
  Formats a price based on country code.

  Defaults to BR-style formatting for unknown countries.

  ## Examples

      iex> AurumFinance.Helpers.format_price("BR", Decimal.new("123.45"))
      "R$ 123,45"

      iex> AurumFinance.Helpers.format_price("US", Decimal.new("123.45"))
      "U$D 123.45"
  """
  @spec format_price(String.t(), Decimal.t() | number() | String.t()) :: String.t()
  def format_price(country_code, price) do
    country_code
    |> normalize_country_code()
    |> do_format_price(normalize_price(price))
  end

  @doc """
  Backward-compatible formatter that assumes Brazil (`"BR"`).
  """
  @spec format_price(Decimal.t() | number() | String.t()) :: String.t()
  def format_price(price), do: format_price("BR", price)

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
  Converts blank strings to nil while preserving non-blank values.

  ## Examples

      iex> AurumFinance.Helpers.blank_to_nil("  ")
      nil

      iex> AurumFinance.Helpers.blank_to_nil("USD")
      "USD"
  """
  def blank_to_nil(value) when is_binary(value) do
    if String.trim(value) == "", do: nil, else: value
  end

  def blank_to_nil(value), do: value

  @doc """
  Normalizes binary values to trimmed uppercase, preserving non-binaries.

  ## Examples

      iex> AurumFinance.Helpers.normalize_to_upper(" usd ")
      "USD"

      iex> AurumFinance.Helpers.normalize_to_upper(nil)
      nil
  """
  @spec normalize_to_upper(term()) :: term()
  def normalize_to_upper(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.upcase()
  end

  def normalize_to_upper(value), do: value

  @doc """
  Safe indifferent map access for atom/string keys.
  """
  def map_get(map, key) when is_atom(key), do: Map.get(map, key) || Map.get(map, to_string(key))
  def map_get(map, key) when is_binary(key), do: Map.get(map, key) || Map.get(map, to_atom(key))

  @doc """
  Generates a URL-safe random token.
  """
  @spec generate_urlsafe_token(pos_integer()) :: String.t()
  def generate_urlsafe_token(num_bytes \\ 7) do
    :crypto.strong_rand_bytes(num_bytes)
    |> Base.url_encode64(padding: false)
  end

  defp to_atom(key) when is_binary(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> key
    end
  end

  defp to_atom(key) when is_atom(key), do: key

  defp do_format_price("BR", price) do
    "R$ #{Decimal.round(price, 2)}"
    |> String.replace(".", ",")
  end

  defp do_format_price("US", price), do: "U$D #{Decimal.round(price, 2)}"
  defp do_format_price(_country_code, price), do: "$ #{Decimal.round(price, 2)}"

  defp normalize_country_code(country_code) when is_binary(country_code),
    do: country_code |> String.trim() |> String.upcase()

  defp normalize_country_code(_country_code), do: ""

  defp normalize_price(%Decimal{} = price), do: price
  defp normalize_price(price) when is_integer(price), do: Decimal.new(price)
  defp normalize_price(price) when is_float(price), do: price |> to_string() |> Decimal.new()
  defp normalize_price(price) when is_binary(price), do: Decimal.new(price)
end
