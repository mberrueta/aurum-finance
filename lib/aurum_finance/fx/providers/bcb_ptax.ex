defmodule AurumFinance.Fx.Providers.BcbPtax do
  @moduledoc """
  FX rate provider for the BCB PTAX (Banco Central do Brasil) API.

  Fetches daily selling rates (`cotacaoVenda`) for a currency pair where one
  side is BRL. The BCB PTAX API is public and requires no authentication.

  Endpoint format:
    `https://ptax.bcb.gov.br/ptax_internet/api/v1/cotacaoMoedaPeriodo/{currencyCode}/{startDate}/{endDate}`

  The API uses MM-DD-YYYY date format in the URL and returns JSON with a
  `value` array containing `cotacaoVenda` and `dataHoraCotacao` fields.

  No credentials required. No env vars needed.
  """

  @behaviour AurumFinance.Fx.Provider

  alias AurumFinance.Fx.FxSeries

  require Logger

  @base_url "https://ptax.bcb.gov.br/ptax_internet/api/v1/cotacaoMoedaPeriodo"

  @impl AurumFinance.Fx.Provider
  @spec fetch(FxSeries.t(), Date.t(), Date.t()) ::
          {:ok, [%{date: Date.t(), value: Decimal.t()}]} | {:error, term()}
  def fetch(%FxSeries{} = series, %Date{} = from_date, %Date{} = to_date) do
    currency_code = non_brl_currency(series)
    url = build_url(currency_code, from_date, to_date)

    url
    |> do_request()
    |> parse_response()
  end

  defp non_brl_currency(%FxSeries{base_currency_code: "BRL", quote_currency_code: code}), do: code
  defp non_brl_currency(%FxSeries{base_currency_code: code, quote_currency_code: "BRL"}), do: code
  defp non_brl_currency(%FxSeries{base_currency_code: base}), do: base

  defp build_url(currency_code, from_date, to_date) do
    start_str = format_date_mmddyyyy(from_date)
    end_str = format_date_mmddyyyy(to_date)
    "#{@base_url}/#{currency_code}/#{start_str}/#{end_str}"
  end

  defp format_date_mmddyyyy(%Date{year: y, month: m, day: d}) do
    month = String.pad_leading(Integer.to_string(m), 2, "0")
    day = String.pad_leading(Integer.to_string(d), 2, "0")
    year = Integer.to_string(y)
    "#{month}-#{day}-#{year}"
  end

  defp do_request(url) do
    Req.get(url, receive_timeout: 30_000)
  rescue
    exception ->
      Logger.warning("BCB PTAX request failed",
        url: url,
        error: Exception.message(exception)
      )

      {:error, {:http_error, Exception.message(exception)}}
  end

  defp parse_response({:ok, %Req.Response{status: 200, body: %{"value" => values}}})
       when is_list(values) and values != [] do
    rows =
      values
      |> Enum.map(&parse_rate_entry/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.date, Date)

    {:ok, rows}
  end

  defp parse_response({:ok, %Req.Response{status: 200, body: %{"value" => []}}}) do
    {:error, :empty_response}
  end

  defp parse_response({:ok, %Req.Response{status: 200, body: _body}}) do
    {:error, :unexpected_response_format}
  end

  defp parse_response({:ok, %Req.Response{status: status}}) do
    {:error, {:http_status, status}}
  end

  defp parse_response({:error, reason}) do
    {:error, {:http_error, reason}}
  end

  defp parse_rate_entry(%{"cotacaoVenda" => venda, "dataHoraCotacao" => timestamp})
       when not is_nil(venda) do
    with {:ok, date} <- parse_bcb_timestamp(timestamp) do
      %{date: date, value: Decimal.new(to_string(venda))}
    else
      _error -> nil
    end
  end

  defp parse_rate_entry(_entry), do: nil

  defp parse_bcb_timestamp(timestamp) when is_binary(timestamp) do
    # BCB format: "YYYY-MM-DD HH:MM:SS.mmm"
    timestamp
    |> String.split(" ")
    |> List.first()
    |> Date.from_iso8601()
  end

  defp parse_bcb_timestamp(_), do: {:error, :invalid_timestamp}
end
