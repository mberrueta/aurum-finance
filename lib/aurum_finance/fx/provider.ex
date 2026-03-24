defmodule AurumFinance.Fx.Provider do
  @moduledoc """
  Behaviour and central registry for FX rate providers.

  Each provider implements `fetch/3` to retrieve daily exchange rates from an
  external source. The provider normalizes the API response into a flat list
  of `%{date: Date.t(), value: Decimal.t()}` maps sorted by date ascending.

  Providers do NOT apply inversion logic; that is the caller's responsibility.
  """

  alias AurumFinance.Fx.FxSeries

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

  defp dispatch({:ok, module}, series, from_date, to_date), do: module.fetch(series, from_date, to_date)
  defp dispatch(:error, _series, _from_date, _to_date), do: {:error, :unknown_provider}
end
