defmodule AurumFinance.Fx.Providers.FrankfurterEcb do
  @moduledoc """
  FX rate provider for the Frankfurter API (ECB reference rates).

  Fetches daily exchange rates from the European Central Bank via the
  Frankfurter public API. No authentication is required.

  Endpoint format:
    `https://api.frankfurter.app/{startDate}..{endDate}?from={base}&to={quote}`

  Dates use YYYY-MM-DD format. The response JSON contains a `rates` map keyed
  by date string, each mapping to a currency-code/value pair.

  No credentials required. No env vars needed.
  """

  @behaviour AurumFinance.Fx.Provider

  alias AurumFinance.Fx.FxSeries

  require Logger

  @base_url "https://api.frankfurter.app"

  @impl AurumFinance.Fx.Provider
  @spec fetch(FxSeries.t(), Date.t(), Date.t()) ::
          {:ok, [%{date: Date.t(), value: Decimal.t()}]} | {:error, term()}
  def fetch(%FxSeries{} = series, %Date{} = from_date, %Date{} = to_date) do
    url = build_url(series.base_currency_code, series.quote_currency_code, from_date, to_date)

    url
    |> do_request()
    |> parse_response(series.quote_currency_code)
  end

  defp build_url(base, quote_code, from_date, to_date) do
    start_str = Date.to_iso8601(from_date)
    end_str = Date.to_iso8601(to_date)
    "#{@base_url}/#{start_str}..#{end_str}?from=#{base}&to=#{quote_code}"
  end

  defp do_request(url) do
    Req.get(url, receive_timeout: 30_000)
  rescue
    exception ->
      Logger.warning("Frankfurter ECB request failed",
        url: url,
        error: Exception.message(exception)
      )

      {:error, {:http_error, Exception.message(exception)}}
  end

  defp parse_response({:ok, %Req.Response{status: 200, body: %{"rates" => rates}}}, quote_code)
       when is_map(rates) and map_size(rates) > 0 do
    rows =
      rates
      |> Enum.map(fn {date_str, currency_map} ->
        parse_rate_entry(date_str, currency_map, quote_code)
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.date, Date)

    {:ok, rows}
  end

  defp parse_response({:ok, %Req.Response{status: 200, body: %{"rates" => rates}}}, _quote_code)
       when is_map(rates) and map_size(rates) == 0 do
    {:error, :empty_response}
  end

  defp parse_response({:ok, %Req.Response{status: 200, body: _body}}, _quote_code) do
    {:error, :unexpected_response_format}
  end

  defp parse_response({:ok, %Req.Response{status: status}}, _quote_code) do
    {:error, {:http_status, status}}
  end

  defp parse_response({:error, reason}, _quote_code) do
    {:error, {:http_error, reason}}
  end

  defp parse_rate_entry(date_str, currency_map, quote_code) when is_map(currency_map) do
    with {:ok, date} <- Date.from_iso8601(date_str),
         value when not is_nil(value) <- Map.get(currency_map, quote_code) do
      %{date: date, value: Decimal.new(to_string(value))}
    else
      _error -> nil
    end
  end

  defp parse_rate_entry(_date_str, _currency_map, _quote_code), do: nil
end
