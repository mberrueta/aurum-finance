defmodule AurumFinance.Fx.Providers.BcbPtax do
  @moduledoc """
  FX rate provider for the BCB PTAX (Banco Central do Brasil) API.

  Fetches daily selling rates (`cotacaoVenda`) for supported `XXX/BRL` pairs.
  The BCB PTAX API is public and requires no authentication.

  Endpoint format:
    `https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata/CotacaoMoedaPeriodo(...)`

  The API uses MM-DD-YYYY date format in query parameters and returns JSON with
  a `value` array containing `cotacaoVenda`, `dataHoraCotacao`, and
  `tipoBoletim` fields. We keep only `Fechamento` quotes to persist one daily
  row per date.

  No credentials required. No env vars needed.
  """

  @behaviour AurumFinance.Fx.Provider

  alias AurumFinance.Fx.FxSeries

  require Logger

  @default_base_url "https://olinda.bcb.gov.br/olinda/servico/PTAX/versao/v1/odata"
  @closing_bulletin "Fechamento"

  @impl AurumFinance.Fx.Provider
  @spec fetch(FxSeries.t(), Date.t(), Date.t()) ::
          {:ok, [%{date: Date.t(), value: Decimal.t()}]} | {:error, term()}
  def fetch(
        %FxSeries{quote_currency_code: "BRL"} = series,
        %Date{} = from_date,
        %Date{} = to_date
      ) do
    currency_code = series.base_currency_code
    url = build_url(currency_code, from_date, to_date)

    url
    |> do_request()
    |> parse_response()
  end

  def fetch(%FxSeries{}, %Date{}, %Date{}), do: {:error, :unsupported_currency_pair}

  defp build_url(currency_code, from_date, to_date) do
    start_str = format_date_mmddyyyy(from_date)
    end_str = format_date_mmddyyyy(to_date)

    query =
      URI.encode_query(%{
        "@moeda" => "'#{currency_code}'",
        "@dataInicial" => "'#{start_str}'",
        "@dataFinalCotacao" => "'#{end_str}'",
        "$top" => "10000",
        "$format" => "json",
        "$select" => "cotacaoVenda,dataHoraCotacao,tipoBoletim"
      })

    "#{base_url()}/CotacaoMoedaPeriodo(moeda=@moeda,dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)?#{query}"
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

    build_rows_result(rows)
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

  defp parse_rate_entry(%{
         "cotacaoVenda" => venda,
         "dataHoraCotacao" => timestamp,
         "tipoBoletim" => @closing_bulletin
       })
       when not is_nil(venda) do
    case parse_bcb_timestamp(timestamp) do
      {:ok, date} ->
        %{date: date, value: Decimal.new(to_string(venda))}

      _error ->
        nil
    end
  end

  defp parse_rate_entry(_entry), do: nil

  defp build_rows_result([]), do: {:error, :empty_response}
  defp build_rows_result(rows), do: {:ok, rows}

  defp parse_bcb_timestamp(timestamp) when is_binary(timestamp) do
    # BCB format: "YYYY-MM-DD HH:MM:SS.mmm"
    timestamp
    |> String.split(" ")
    |> List.first()
    |> Date.from_iso8601()
  end

  defp parse_bcb_timestamp(_), do: {:error, :invalid_timestamp}

  defp base_url do
    :aurum_finance
    |> Application.get_env(:fx_provider_base_urls, %{})
    |> Map.get("bcb_ptax", @default_base_url)
  end
end
