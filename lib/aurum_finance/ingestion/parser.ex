defmodule AurumFinance.Ingestion.Parser do
  @moduledoc """
  Parser boundary for imported source files.

  CSV is the only supported format in this milestone. The boundary is kept
  format-agnostic so future parsers can return the same output shape.
  """

  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ParserError
  alias AurumFinance.Ingestion.Parsers.CSV
  alias AurumFinance.Ingestion.ParsedImport

  @type parse_attrs :: %{
          required(:format) => atom(),
          optional(:content) => binary(),
          optional(:storage_path) => String.t()
        }

  @callback parse(map()) :: {:ok, ParsedImport.t()} | {:error, ParserError.t()}

  @doc """
  Parses a stored imported file through the format-specific parser.

  ## Examples

  ```elixir
  {:ok, parsed_import} = AurumFinance.Ingestion.Parser.parse_imported_file(imported_file)
  ```
  """
  @spec parse_imported_file(ImportedFile.t()) ::
          {:ok, ParsedImport.t()} | {:error, ParserError.t()}
  def parse_imported_file(%ImportedFile{} = imported_file) do
    parse(%{format: imported_file.format, storage_path: imported_file.storage_path})
  end

  @doc """
  Parses content using the configured parser for the given format.

  Unsupported formats are rejected explicitly.

  ## Examples

  ```elixir
  {:ok, parsed_import} =
    AurumFinance.Ingestion.Parser.parse(%{
      format: :csv,
      content: "date,description,amount\n2026-03-10,Coffee,-4.50\n"
    })
  ```
  """
  @spec parse(parse_attrs()) :: {:ok, ParsedImport.t()} | {:error, ParserError.t()}
  def parse(%{format: format} = attrs) do
    case parser_module(format) do
      {:ok, parser_module} -> parser_module.parse(attrs)
      {:error, error} -> {:error, error}
    end
  end

  defp parser_module(:csv), do: {:ok, CSV}

  defp parser_module(format) do
    {:error,
     %ParserError{
       reason: :unsupported_format,
       message: "Unsupported import format: #{inspect(format)}",
       details: %{format: format}
     }}
  end
end
