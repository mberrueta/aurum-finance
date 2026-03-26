defmodule AurumFinance.Fx.CsvImport do
  @moduledoc """
  Pure service module for importing FX rate data from CSV files into
  `csv_upload` FX series.

  The import flow is intentionally split into three explicit steps:

  1. `parse/1` - validates and normalizes the raw CSV binary into typed rows
  2. `check_overlap/2` - detects which dates already exist in the target series
  3. `import/2` - persists the rows via atomic upsert

  The confirmation step between `check_overlap` and `import` belongs in the
  calling layer (LiveView), not here. This module never combines parse and
  import into a single pipeline.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Fx
  alias AurumFinance.Fx.FxRateRecord
  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Repo

  require Logger

  @doc """
  Parses a raw CSV binary into validated `%{date: Date.t(), value: Decimal.t()}`
  rows.

  Accepts common date formats (`YYYY-MM-DD`, `DD/MM/YYYY`, `YYYY/MM/DD`) and
  normalizes values to positive `Decimal`. Rejects the entire file when any row
  is invalid, any date is duplicated within the file, or the file is
  empty/malformed.

  ## Examples

  ```elixir
  {:ok, rows} = AurumFinance.Fx.CsvImport.parse("date,value\\n2024-01-02,5.50\\n")
  # rows == [%{date: ~D[2024-01-02], value: Decimal.new("5.50")}]

  {:error, :empty_file} = AurumFinance.Fx.CsvImport.parse("")
  {:error, :no_data_rows} = AurumFinance.Fx.CsvImport.parse("date,value\\n")
  ```
  """
  @spec parse(binary()) ::
          {:ok, [%{date: Date.t(), value: Decimal.t()}]}
          | {:error, :empty_file}
          | {:error, :no_data_rows}
          | {:error, :malformed_csv}
          | {:error, {:invalid_rows, [%{row: integer(), reason: atom()}]}}
          | {:error, {:duplicate_dates_in_file, [Date.t()]}}
  def parse(content) when is_binary(content) do
    with {:ok, lines} <- split_lines(content),
         {:ok, _header, data_lines} <- extract_header_and_data(lines),
         {:ok, rows} <- validate_all_rows(data_lines),
         {:ok, rows} <- check_duplicate_dates(rows) do
      {:ok, Enum.sort_by(rows, & &1.date, Date)}
    end
  end

  @doc """
  Queries existing `fx_rate_records` for the given series and returns which
  dates from the provided rows already exist.

  ## Examples

  ```elixir
  {:ok, :no_overlap} =
    AurumFinance.Fx.CsvImport.check_overlap(series_id, rows)

  {:ok, {:overlap, [~D[2024-01-05], ~D[2024-01-06]]}} =
    AurumFinance.Fx.CsvImport.check_overlap(series_id, overlapping_rows)
  ```
  """
  @spec check_overlap(Ecto.UUID.t(), [%{date: Date.t(), value: Decimal.t()}]) ::
          {:ok, :no_overlap}
          | {:ok, {:overlap, [Date.t()]}}
  def check_overlap(fx_series_id, rows) when is_list(rows) do
    dates = Enum.map(rows, & &1.date)

    existing_dates =
      FxRateRecord
      |> where([r], r.fx_series_id == ^fx_series_id)
      |> where([r], r.effective_date in ^dates)
      |> select([r], r.effective_date)
      |> order_by([r], asc: r.effective_date)
      |> Repo.all()

    build_overlap_result(existing_dates)
  end

  @doc """
  Imports parsed rows into a `csv_upload` FX series via atomic upsert.

  Returns `{:error, :not_a_csv_series}` when the series uses a
  `provider_module` source kind. Delegates to `Fx.upsert_rate_records/2` for
  persistence.

  The returned map distinguishes `inserted` from `updated` counts based on
  pre-import overlap detection.

  ## Examples

  ```elixir
  {:ok, %{inserted: 5, updated: 2}} =
    AurumFinance.Fx.CsvImport.import(csv_series, rows)

  {:error, :not_a_csv_series} =
    AurumFinance.Fx.CsvImport.import(provider_series, rows)
  ```
  """
  @spec import(FxSeries.t(), [%{date: Date.t(), value: Decimal.t()}]) ::
          {:ok, %{inserted: non_neg_integer(), updated: non_neg_integer()}}
          | {:error, :not_a_csv_series}
  def import(%FxSeries{source_kind: :provider_module}, _rows) do
    Logger.warning(
      "fx.csv_import.failure series_id=#{series_id_string(nil)} reason=not_a_csv_series",
      event: "fx.csv_import.failure",
      series_id: nil,
      reason: "not_a_csv_series"
    )

    {:error, :not_a_csv_series}
  end

  def import(%FxSeries{source_kind: :csv_upload} = series, rows) when is_list(rows) do
    {:ok, overlap_result} = check_overlap(series.id, rows)
    overlap_count = count_overlapping(overlap_result)
    oldest_imported_date = oldest_imported_date(rows)

    case run_import_transaction(series, rows, oldest_imported_date) do
      {:ok, _} ->
        Logger.info(
          "fx.csv_import.success series_id=#{series_id_string(series.id)} inserted=#{length(rows) - overlap_count} updated=#{overlap_count}",
          event: "fx.csv_import.success",
          series_id: series.id,
          inserted: length(rows) - overlap_count,
          updated: overlap_count
        )

        {:ok, %{inserted: length(rows) - overlap_count, updated: overlap_count}}

      {:error, reason} ->
        Logger.warning(
          "fx.csv_import.failure series_id=#{series_id_string(series.id)} reason=#{format_import_log_reason(reason)}",
          event: "fx.csv_import.failure",
          series_id: series.id,
          reason: format_import_log_reason(reason)
        )

        {:error, reason}
    end
  end

  defp count_overlapping(:no_overlap), do: 0
  defp count_overlapping({:overlap, dates}), do: length(dates)

  defp build_overlap_result([]), do: {:ok, :no_overlap}
  defp build_overlap_result(overlap), do: {:ok, {:overlap, overlap}}

  defp oldest_imported_date([]), do: nil
  defp oldest_imported_date(rows), do: Enum.min_by(rows, & &1.date, Date).date

  defp maybe_update_series_from_date(_series, nil), do: :ok

  defp maybe_update_series_from_date(%FxSeries{} = series, oldest_date) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    FxSeries
    |> where([s], s.id == ^series.id)
    |> where([s], s.from_date > ^oldest_date)
    |> Repo.update_all(set: [from_date: oldest_date, updated_at: now])

    :ok
  end

  defp run_import_transaction(series, rows, oldest_imported_date) do
    try do
      Repo.transaction(fn ->
        {:ok, _count} = Fx.upsert_rate_records(series.id, rows)
        maybe_update_series_from_date(series, oldest_imported_date)
      end)
    rescue
      exception ->
        {:error, exception}
    catch
      :exit, reason ->
        {:error, reason}
    end
  end

  defp format_import_log_reason(reason) do
    inspect(reason)
  end

  defp series_id_string(nil), do: "nil"
  defp series_id_string(series_id), do: series_id

  defp split_lines(content) do
    content
    |> String.trim()
    |> do_split_lines()
  end

  defp do_split_lines(""), do: {:error, :empty_file}

  defp do_split_lines(trimmed) do
    trimmed
    |> String.split(~r/\r\n|\r|\n/)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> lines_result()
  end

  defp lines_result([]), do: {:error, :empty_file}
  defp lines_result(lines), do: {:ok, lines}

  defp extract_header_and_data([_header]) do
    {:error, :no_data_rows}
  end

  defp extract_header_and_data([header | data_lines]) do
    {:ok, header, data_lines}
  end

  defp validate_all_rows(data_lines) do
    results =
      data_lines
      |> Enum.with_index(2)
      |> Enum.map(fn {line, row_number} -> validate_row(line, row_number) end)

    errors =
      Enum.flat_map(results, fn
        {:error, error} -> [error]
        {:ok, _row} -> []
      end)

    case errors do
      [] ->
        rows = Enum.map(results, fn {:ok, row} -> row end)
        {:ok, rows}

      errors ->
        {:error, {:invalid_rows, errors}}
    end
  end

  defp validate_row(line, row_number) do
    case split_csv_row(line) do
      {:ok, [raw_date, raw_value]} ->
        with {:ok, date} <- parse_date(String.trim(raw_date)),
             {:ok, value} <- parse_value(String.trim(raw_value)) do
          {:ok, %{date: date, value: value}}
        else
          {:error, reason} -> {:error, %{row: row_number, reason: reason}}
        end

      {:error, reason} ->
        {:error, %{row: row_number, reason: reason}}
    end
  end

  defp split_csv_row(line) do
    line
    |> split_csv_fields()
    |> to_two_column_result()
  end

  defp to_two_column_result([_col1, _col2] = fields), do: {:ok, fields}
  defp to_two_column_result(_), do: {:error, :invalid_column_count}

  # Splits a CSV line into fields, respecting double-quoted values that may
  # contain commas. Follows the same hand-rolled approach as the ingestion
  # parser but simplified for the 2-column FX format.
  defp split_csv_fields(line), do: split_fields(line, "", [], false)

  defp split_fields("", field, acc, false), do: Enum.reverse([field | acc])
  defp split_fields("", _field, _acc, true), do: [:malformed]

  defp split_fields(<<"\"\"", rest::binary>>, field, acc, true) do
    split_fields(rest, field <> "\"", acc, true)
  end

  defp split_fields(<<?", rest::binary>>, field, acc, true) do
    split_fields(rest, field, acc, false)
  end

  defp split_fields(<<?", rest::binary>>, field, acc, false) do
    split_fields(rest, field, acc, true)
  end

  defp split_fields(<<?,, rest::binary>>, field, acc, false) do
    split_fields(rest, "", [field | acc], false)
  end

  defp split_fields(<<char::utf8, rest::binary>>, field, acc, in_quotes) do
    split_fields(rest, field <> <<char::utf8>>, acc, in_quotes)
  end

  defp parse_date(raw) do
    try_date_formats(raw)
  end

  # ISO 8601: YYYY-MM-DD
  defp try_date_formats(<<y::binary-size(4), "-", m::binary-size(2), "-", d::binary-size(2)>>) do
    case Date.new(to_int(y), to_int(m), to_int(d)) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, :invalid_date}
    end
  end

  # Slash-based: YYYY/MM/DD
  defp try_date_formats(<<y::binary-size(4), "/", m::binary-size(2), "/", d::binary-size(2)>>) do
    case Date.new(to_int(y), to_int(m), to_int(d)) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, :invalid_date}
    end
  end

  # Slash-based ambiguous: DD/MM/YYYY vs MM/DD/YYYY
  # Prefer DD/MM/YYYY when day > 12 (unambiguous).
  # When both <= 12, try DD/MM/YYYY first.
  defp try_date_formats(<<a::binary-size(2), "/", b::binary-size(2), "/", y::binary-size(4)>>) do
    int_a = to_int(a)
    int_b = to_int(b)
    int_y = to_int(y)

    resolve_ambiguous_slash_date(int_a, int_b, int_y)
  end

  defp try_date_formats(_raw) do
    {:error, :invalid_date}
  end

  # First part > 12 -> must be DD/MM/YYYY (cannot be a month)
  defp resolve_ambiguous_slash_date(day, month, year) when day > 12 do
    case Date.new(year, month, day) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, :invalid_date}
    end
  end

  # Second part > 12 -> must be MM/DD/YYYY (second part is day)
  defp resolve_ambiguous_slash_date(month, day, year) when day > 12 do
    case Date.new(year, month, day) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, :invalid_date}
    end
  end

  # Both <= 12: prefer DD/MM/YYYY (a=day, b=month), fall back to MM/DD/YYYY
  defp resolve_ambiguous_slash_date(a, b, year) do
    with {:error, _} <- Date.new(year, b, a),
         {:error, _} <- Date.new(year, a, b) do
      {:error, :invalid_date}
    else
      {:ok, date} -> {:ok, date}
    end
  end

  defp to_int(binary), do: String.to_integer(binary)

  defp build_duplicate_result([], rows), do: {:ok, rows}
  defp build_duplicate_result(dups, _rows), do: {:error, {:duplicate_dates_in_file, dups}}

  defp parse_value(raw) do
    cleaned =
      raw
      |> String.replace(",", "")
      |> String.replace(" ", "")
      |> String.trim()

    case Decimal.parse(cleaned) do
      {decimal, ""} ->
        validate_positive_value(decimal)

      {_decimal, _remainder} ->
        {:error, :invalid_value}

      :error ->
        {:error, :invalid_value}
    end
  end

  defp validate_positive_value(decimal) when is_struct(decimal, Decimal) do
    case Decimal.compare(decimal, Decimal.new(0)) do
      :gt -> {:ok, decimal}
      _ -> {:error, :non_positive_value}
    end
  end

  defp check_duplicate_dates(rows) do
    duplicates =
      rows
      |> Enum.group_by(& &1.date)
      |> Enum.filter(fn {_date, entries} -> length(entries) > 1 end)
      |> Enum.map(fn {date, _entries} -> date end)
      |> Enum.sort(Date)

    build_duplicate_result(duplicates, rows)
  end
end
