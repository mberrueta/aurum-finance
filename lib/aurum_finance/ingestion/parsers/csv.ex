defmodule AurumFinance.Ingestion.Parsers.CSV do
  @moduledoc """
  CSV parser for imported source files.

  This parser produces canonical row candidates only. It does not perform
  normalization, dedupe, or row-status decisions.
  """

  @behaviour AurumFinance.Ingestion.Parser

  alias AurumFinance.Helpers
  alias AurumFinance.Ingestion.CanonicalRowCandidate
  alias AurumFinance.Ingestion.ParserError
  alias AurumFinance.Ingestion.ParsedImport

  @posted_on_keys ~w(date posted_on posted_at posted_date transaction_date booking_date)
  @description_keys ~w(description details memo payee narrative name)
  @amount_keys ~w(amount transaction_amount value)
  @currency_keys ~w(currency currency_code currencycode)

  @doc """
  Parses CSV content from either `:content` or `:storage_path`.

  ## Examples

  ```elixir
  {:ok, parsed_import} =
    AurumFinance.Ingestion.Parsers.CSV.parse(%{
      format: :csv,
      content: "date,description,amount\n2026-03-10,Coffee,-4.50\n"
    })

  parsed_import.row_count
  #=> 1
  ```
  """
  @impl true
  @spec parse(map()) :: {:ok, ParsedImport.t()} | {:error, ParserError.t()}
  def parse(attrs) when is_map(attrs) do
    with {:ok, content} <- extract_content(attrs),
         {:ok, rows} <- decode_csv(content),
         {:ok, headers, data_rows} <- split_header_row(rows) do
      parsed_rows =
        data_rows
        |> Enum.with_index(1)
        |> Enum.map(fn {row, row_index} ->
          build_candidate(headers, row, row_index)
        end)

      {:ok,
       %ParsedImport{
         format: :csv,
         row_count: length(parsed_rows),
         rows: parsed_rows,
         warnings: []
       }}
    end
  end

  defp extract_content(%{content: content}) when is_binary(content), do: {:ok, content}

  defp extract_content(%{storage_path: storage_path}) when is_binary(storage_path) do
    File.read(storage_path)
  end

  defp extract_content(_attrs) do
    {:error,
     %ParserError{
       reason: :missing_content,
       message: "CSV parser requires :content or :storage_path",
       details: %{}
     }}
  end

  defp split_header_row([]) do
    {:error,
     %ParserError{
       reason: :empty_file,
       message: "CSV file is empty",
       details: %{}
     }}
  end

  defp split_header_row([header_row | data_rows]) do
    headers =
      header_row
      |> Enum.map(&String.trim/1)

    if Enum.any?(headers, &Helpers.blank?/1) do
      {:error,
       %ParserError{
         reason: :invalid_header_row,
         message: "CSV header row contains blank column names",
         details: %{headers: headers}
       }}
    else
      {:ok, headers, data_rows}
    end
  end

  defp build_candidate(headers, row, row_index) do
    raw_data =
      headers
      |> Enum.zip(pad_row(row, length(headers)))
      |> Map.new()

    %CanonicalRowCandidate{
      row_index: row_index,
      raw_data: raw_data,
      canonical_data: %{
        posted_on: pick_first(raw_data, @posted_on_keys),
        description: pick_first(raw_data, @description_keys),
        amount: pick_first(raw_data, @amount_keys),
        currency: pick_first(raw_data, @currency_keys)
      }
    }
  end

  defp pad_row(row, expected_length) when length(row) < expected_length do
    row ++ List.duplicate(nil, expected_length - length(row))
  end

  defp pad_row(row, expected_length), do: Enum.take(row, expected_length)

  defp pick_first(raw_data, keys) do
    normalized_lookup =
      Map.new(raw_data, fn {key, value} ->
        {normalize_header(key), value}
      end)

    Enum.find_value(keys, fn key ->
      normalized_lookup[key]
    end)
  end

  defp normalize_header(header) do
    header
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "_")
    |> String.trim("_")
  end

  defp decode_csv(content) when is_binary(content) do
    case parse_binary(content, [], [], [], false) do
      {:ok, rows} ->
        {:ok, rows |> Enum.reverse() |> reject_trailing_empty_rows()}

      {:error, reason} ->
        {:error,
         %ParserError{
           reason: :invalid_csv,
           message: "CSV parsing failed: #{reason}",
           details: %{reason: reason}
         }}
    end
  end

  defp parse_binary(<<>>, _field, _row, _rows, true), do: {:error, :unterminated_quote}

  defp parse_binary(<<>>, field, row, rows, false) do
    completed_rows =
      rows
      |> prepend_completed_row(row, field)

    {:ok, completed_rows}
  end

  defp parse_binary(<<?", ?", rest::binary>>, field, row, rows, true) do
    parse_binary(rest, [?" | field], row, rows, true)
  end

  defp parse_binary(<<?", rest::binary>>, field, row, rows, true) do
    parse_binary(rest, field, row, rows, false)
  end

  defp parse_binary(<<?", rest::binary>>, field, row, rows, false) do
    parse_binary(rest, field, row, rows, true)
  end

  defp parse_binary(<<?,, rest::binary>>, field, row, rows, false) do
    parse_binary(rest, [], [field_to_string(field) | row], rows, false)
  end

  defp parse_binary(<<?\r, ?\n, rest::binary>>, field, row, rows, false) do
    parse_binary(rest, [], [], prepend_completed_row(rows, row, field), false)
  end

  defp parse_binary(<<?\n, rest::binary>>, field, row, rows, false) do
    parse_binary(rest, [], [], prepend_completed_row(rows, row, field), false)
  end

  defp parse_binary(<<?\r, rest::binary>>, field, row, rows, false) do
    parse_binary(rest, [], [], prepend_completed_row(rows, row, field), false)
  end

  defp parse_binary(<<char::utf8, rest::binary>>, field, row, rows, in_quotes) do
    parse_binary(rest, [char | field], row, rows, in_quotes)
  end

  defp prepend_completed_row(rows, row, field) do
    [Enum.reverse([field_to_string(field) | row]) | rows]
  end

  defp field_to_string(field) do
    field
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp reject_trailing_empty_rows(rows) do
    Enum.reject(rows, fn row ->
      Enum.all?(row, &Helpers.blank?/1)
    end)
  end
end
