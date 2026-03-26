defmodule AurumFinance.Fx.Provider do
  @moduledoc """
  Behaviour and central registry for FX rate providers.

  Each provider implements `fetch/3` to retrieve daily exchange rates from an
  external source. The provider normalizes the API response into a flat list
  of `%{date: Date.t(), value: Decimal.t()}` maps sorted by date ascending.

  Providers do NOT apply inversion logic; that is the caller's responsibility.
  """

  alias AurumFinance.Fx.FxSeries

  @common_currency_codes ~w(USD EUR BRL GBP JPY CHF CAD AUD NZD CNY HKD SGD MXN ARS CLP COP PEN UYU)
  @provider_currency_codes %{
    "bcb_ptax" => %{
      base: ~w(USD EUR GBP JPY CHF CAD AUD),
      quote: ["BRL"]
    },
    "frankfurter_ecb" => %{
      base: @common_currency_codes,
      quote: @common_currency_codes
    }
  }

  @doc """
  Fetches daily exchange rates for the given series and date range.

  Returns a list of `%{date: Date.t(), value: Decimal.t()}` maps sorted by
  date ascending. The provider normalizes the external API response but does
  not apply any inversion. On failure, returns `{:error, reason}`.
  """
  @callback fetch(series :: FxSeries.t(), from_date :: Date.t(), to_date :: Date.t()) ::
              {:ok, [%{date: Date.t(), value: Decimal.t()}]} | {:error, term()}

  @provider_registry %{
    "bcb_ptax" => AurumFinance.Fx.Providers.BcbPtax,
    "frankfurter_ecb" => AurumFinance.Fx.Providers.FrankfurterEcb
  }

  @doc """
  Returns the central registry mapping provider identifiers to modules.

  ## Examples

      iex> providers = AurumFinance.Fx.Provider.providers()
      iex> Map.has_key?(providers, "bcb_ptax")
      true
      iex> Map.has_key?(providers, "frankfurter_ecb")
      true
  """
  @spec providers() :: %{String.t() => module()}
  def providers, do: @provider_registry

  @doc """
  Returns the curated common currency codes shown when no provider-specific
  restriction applies.
  """
  @spec common_currency_codes() :: [String.t()]
  def common_currency_codes, do: @common_currency_codes

  @doc """
  Returns the allowed base currency codes for a provider-backed series.
  """
  @spec base_currency_codes(String.t() | nil) :: [String.t()]
  def base_currency_codes(provider_identifier) do
    provider_identifier
    |> provider_currency_config()
    |> Map.get(:base, @common_currency_codes)
  end

  @doc """
  Returns the allowed quote currency codes for a provider-backed series.
  """
  @spec quote_currency_codes(String.t() | nil) :: [String.t()]
  def quote_currency_codes(provider_identifier) do
    provider_identifier
    |> provider_currency_config()
    |> Map.get(:quote, @common_currency_codes)
  end

  @doc """
  Returns whether the provider supports the given currency pair.
  """
  @spec compatible_currency_pair?(String.t(), String.t(), String.t()) :: boolean()
  def compatible_currency_pair?(provider_identifier, base_currency_code, quote_currency_code)
      when is_binary(provider_identifier) and is_binary(base_currency_code) and
             is_binary(quote_currency_code) do
    allowed_bases = base_currency_codes(provider_identifier)
    allowed_quotes = quote_currency_codes(provider_identifier)

    base_currency_code in allowed_bases and quote_currency_code in allowed_quotes and
      base_currency_code != quote_currency_code
  end

  def compatible_currency_pair?(_provider_identifier, _base_currency_code, _quote_currency_code),
    do: false

  @doc """
  Looks up the provider module from the registry and delegates to its
  `fetch/3` callback.

  Returns `{:error, :unknown_provider}` for unregistered identifiers.

  ## Examples

      iex> AurumFinance.Fx.Provider.fetch_rates("nonexistent", %AurumFinance.Fx.FxSeries{}, ~D[2024-01-01], ~D[2024-01-31])
      {:error, :unknown_provider}
  """
  @spec fetch_rates(String.t(), FxSeries.t(), Date.t(), Date.t()) ::
          {:ok, [%{date: Date.t(), value: Decimal.t()}]} | {:error, term()}
  def fetch_rates(provider_identifier, series, from_date, to_date) do
    @provider_registry
    |> Map.fetch(provider_identifier)
    |> dispatch(series, from_date, to_date)
  end

  defp provider_currency_config(provider_identifier) do
    Map.get(@provider_currency_codes, provider_identifier, %{})
  end

  defp dispatch({:ok, module}, series, from_date, to_date),
    do: module.fetch(series, from_date, to_date)

  defp dispatch(:error, _series, _from_date, _to_date), do: {:error, :unknown_provider}
end
