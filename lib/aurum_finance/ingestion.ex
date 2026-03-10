defmodule AurumFinance.Ingestion do
  @moduledoc """
  The Ingestion context, responsible for uploaded source files and import-run state.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ImportWorker
  alias AurumFinance.Ingestion.LocalFileStorage
  alias AurumFinance.Ingestion.Parser
  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ingestion.RowNormalizer
  alias AurumFinance.Repo

  @type list_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:status, :pending | :processing | :complete | :failed}
          | {:format, :csv}

  @type row_list_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:imported_file_id, Ecto.UUID.t()}
          | {:status, :ready | :duplicate | :invalid}
          | {:fingerprint, String.t()}

  @type normalize_opt ::
          {:account, AurumFinance.Ledger.Account.t()}
          | {:default_currency, String.t()}
          | {:source_locale, String.t()}

  @type duplicate_lookup_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:fingerprints, [String.t()]}

  @doc """
  Returns a composable query for imported files within one account scope.

  ## Examples

  ```elixir
  query = AurumFinance.Ingestion.list_imported_files_query(account_id: account.id, status: :complete)
  Repo.all(query)
  ```

  Error path:

      iex> AurumFinance.Ingestion.list_imported_files_query()
      ** (ArgumentError) list_imported_files_query/1 requires :account_id
  """
  @spec list_imported_files_query([list_opt()]) :: Ecto.Query.t()
  def list_imported_files_query(opts \\ []) do
    opts = require_account_scope!(opts, "list_imported_files_query/1")

    ImportedFile
    |> filter_query(opts)
    |> order_by([imported_file], desc: imported_file.inserted_at)
  end

  @doc """
  Lists imported files within one account scope with optional filters.

  ## Examples

  ```elixir
  imported_files = AurumFinance.Ingestion.list_imported_files(account_id: account.id)
  ```

  Error path:

      iex> AurumFinance.Ingestion.list_imported_files()
      ** (ArgumentError) list_imported_files/1 requires :account_id
  """
  @spec list_imported_files([list_opt()]) :: [ImportedFile.t()]
  def list_imported_files(opts \\ []) do
    opts = require_account_scope!(opts, "list_imported_files/1")

    opts
    |> list_imported_files_query()
    |> Repo.all()
  end

  @doc """
  Fetches one imported file by id within an explicit account scope.

  Raises `Ecto.NoResultsError` when the imported file does not exist inside that
  account boundary.

  ## Examples

  ```elixir
  imported_file = AurumFinance.Ingestion.get_imported_file!(account.id, imported_file.id)
  ```
  """
  @spec get_imported_file!(Ecto.UUID.t(), Ecto.UUID.t()) :: ImportedFile.t()
  def get_imported_file!(account_id, imported_file_id) do
    get_imported_file(account_id, imported_file_id) ||
      raise Ecto.NoResultsError, queryable: ImportedFile
  end

  @doc false
  @spec get_imported_file(Ecto.UUID.t(), Ecto.UUID.t()) :: ImportedFile.t() | nil
  def get_imported_file(account_id, imported_file_id) do
    ImportedFile
    |> where(
      [imported_file],
      imported_file.id == ^imported_file_id and imported_file.account_id == ^account_id
    )
    |> Repo.one()
  end

  @doc """
  Creates an imported file record.

  ## Examples

  ```elixir
  {:ok, imported_file} =
    AurumFinance.Ingestion.create_imported_file(%{
      account_id: account.id,
      filename: "statement.csv",
      sha256: String.duplicate("a", 64),
      format: :csv,
      status: :pending,
      storage_path: "/tmp/imports/statement.csv"
    })
  ```
  """
  @spec create_imported_file(map()) :: {:ok, ImportedFile.t()} | {:error, Ecto.Changeset.t()}
  def create_imported_file(attrs) do
    %ImportedFile{}
    |> ImportedFile.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Stores an uploaded file on local disk and persists its metadata in
  `imported_files`.

  This function does not reject repeated `sha256` values. File-level duplicate
  handling remains out of scope.

  ## Examples

  ```elixir
  {:ok, imported_file} =
    AurumFinance.Ingestion.store_imported_file(%{
      account_id: account.id,
      filename: "statement.csv",
      content: "date,amount\\n2026-03-10,10.00\\n",
      content_type: "text/csv"
    })
  ```
  """
  @spec store_imported_file(map()) :: {:ok, ImportedFile.t()} | {:error, term()}
  def store_imported_file(attrs) when is_map(attrs) do
    with {:ok, storage_metadata} <- LocalFileStorage.store(attrs) do
      imported_file_attrs =
        attrs
        |> Map.take([:account_id])
        |> Map.merge(storage_metadata)
        |> Map.put_new(:format, :csv)
        |> Map.put_new(:status, :pending)

      case create_imported_file(imported_file_attrs) do
        {:ok, imported_file} ->
          {:ok, imported_file}

        {:error, reason} ->
          _ = LocalFileStorage.delete(storage_metadata.storage_path)
          {:error, reason}
      end
    end
  end

  @doc """
  Enqueues asynchronous processing for one imported file through Oban.

  ## Examples

      iex> imported_file = %AurumFinance.Ingestion.ImportedFile{
      ...>   id: Ecto.UUID.generate(),
      ...>   account_id: Ecto.UUID.generate()
      ...> }
      iex> {:ok, %Oban.Job{worker: worker}} =
      ...>   AurumFinance.Ingestion.enqueue_import_processing(imported_file)
      iex> worker
      "Elixir.AurumFinance.Ingestion.ImportWorker"
  """
  @spec enqueue_import_processing(ImportedFile.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue_import_processing(%ImportedFile{} = imported_file) do
    imported_file
    |> ImportWorker.new_job()
    |> Oban.insert()
  end

  @doc """
  Updates an imported file record.

  ## Examples

  ```elixir
  {:ok, imported_file} =
    AurumFinance.Ingestion.update_imported_file(imported_file, %{status: :processing})
  ```
  """
  @spec update_imported_file(ImportedFile.t(), map()) ::
          {:ok, ImportedFile.t()} | {:error, Ecto.Changeset.t()}
  def update_imported_file(%ImportedFile{} = imported_file, attrs) do
    imported_file
    |> ImportedFile.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Parses a stored imported file into canonical row candidates.

  ## Examples

  ```elixir
  {:ok, parsed_import} = AurumFinance.Ingestion.parse_imported_file(imported_file)
  ```
  """
  @spec parse_imported_file(ImportedFile.t()) ::
          {:ok, AurumFinance.Ingestion.ParsedImport.t()}
          | {:error, AurumFinance.Ingestion.ParserError.t()}
  def parse_imported_file(%ImportedFile{} = imported_file) do
    Parser.parse_imported_file(imported_file)
  end

  @doc """
  Returns a lazy stream that normalizes canonical row candidates one by one.

  This is the preferred normalization entry point for async jobs processing
  large imports.

  ## Examples

  ```elixir
  normalized_rows =
    AurumFinance.Ingestion.normalize_rows(parsed_import.rows, account: account)
  ```
  """
  @spec normalize_rows(Enumerable.t(), [normalize_opt()]) :: Enumerable.t()
  def normalize_rows(rows, opts \\ []) do
    RowNormalizer.normalize_rows(rows, opts)
  end

  @doc """
  Returns the subset of a fingerprint batch that already exists as `ready`
  imported rows for the given account.

  This is the batch duplicate lookup entry point for exact-match import dedupe.
  The intended flow is:

  1. build fingerprints for a chunk of normalized rows
  2. pass the chunk fingerprints to this function in one query
  3. mark rows as duplicate when their fingerprint is present in the returned `MapSet`

  This avoids one query per row during import processing.

  ## Examples

      iex> AurumFinance.Ingestion.list_duplicate_fingerprints(
      ...>   account_id: Ecto.UUID.generate(),
      ...>   fingerprints: ["abc123", "def456"]
      ...> )
      MapSet.new()
  """
  @spec list_duplicate_fingerprints([duplicate_lookup_opt()]) :: MapSet.t(String.t())
  def list_duplicate_fingerprints(opts) do
    opts = require_account_scope!(opts, "list_duplicate_fingerprints/1")

    opts
    |> duplicate_fingerprints_query()
    |> Repo.all()
    |> MapSet.new()
  end

  @doc """
  Returns a changeset for imported file form handling.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Ingestion.change_imported_file(%AurumFinance.Ingestion.ImportedFile{}, %{
      ...>     account_id: Ecto.UUID.generate(),
      ...>     filename: "statement.csv",
      ...>     sha256: String.duplicate("a", 64),
      ...>     format: :csv,
      ...>     status: :pending,
      ...>     storage_path: "/tmp/imports/statement.csv"
      ...>   })
      iex> changeset.valid?
      true
  """
  @spec change_imported_file(ImportedFile.t(), map()) :: Ecto.Changeset.t()
  def change_imported_file(%ImportedFile{} = imported_file, attrs \\ %{}) do
    ImportedFile.changeset(imported_file, attrs)
  end

  @doc """
  Returns a composable query for imported rows within one account scope.

  ## Examples

  ```elixir
  query =
    AurumFinance.Ingestion.list_imported_rows_query(
      account_id: account.id,
      imported_file_id: imported_file.id
    )

  Repo.all(query)
  ```
  """
  @spec list_imported_rows_query([row_list_opt()]) :: Ecto.Query.t()
  def list_imported_rows_query(opts \\ []) do
    opts = require_account_scope!(opts, "list_imported_rows_query/1")

    ImportedRow
    |> row_filter_query(opts)
    |> order_by([imported_row], asc: imported_row.row_index, asc: imported_row.inserted_at)
  end

  @doc """
  Lists imported rows within one account scope with optional filters.

  ## Examples

  ```elixir
  rows =
    AurumFinance.Ingestion.list_imported_rows(
      account_id: account.id,
      imported_file_id: imported_file.id
    )
  ```
  """
  @spec list_imported_rows([row_list_opt()]) :: [ImportedRow.t()]
  def list_imported_rows(opts \\ []) do
    opts = require_account_scope!(opts, "list_imported_rows/1")

    opts
    |> list_imported_rows_query()
    |> Repo.all()
  end

  @doc """
  Creates one immutable imported row evidence record.

  ## Examples

  ```elixir
  {:ok, imported_row} =
    AurumFinance.Ingestion.create_imported_row(%{
      imported_file_id: imported_file.id,
      account_id: account.id,
      row_index: 0,
      raw_data: %{"description" => "Coffee"},
      fingerprint: "fp-1",
      status: :ready
    })
  ```
  """
  @spec create_imported_row(map()) :: {:ok, ImportedRow.t()} | {:error, Ecto.Changeset.t()}
  def create_imported_row(attrs) do
    %ImportedRow{}
    |> ImportedRow.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates many immutable imported row evidence records.

  Returns the inserted rows ordered by the input order when all rows are valid.

  ## Examples

  ```elixir
  {:ok, rows} =
    AurumFinance.Ingestion.create_imported_rows([
      %{
        imported_file_id: imported_file.id,
        account_id: account.id,
        row_index: 0,
        raw_data: %{"description" => "Coffee"},
        fingerprint: "fp-1",
        status: :ready
      }
    ])
  ```
  """
  @spec create_imported_rows([map()]) :: {:ok, [ImportedRow.t()]} | {:error, Ecto.Changeset.t()}
  def create_imported_rows(attrs_list) when is_list(attrs_list) do
    Enum.reduce_while(attrs_list, {:ok, []}, fn attrs, {:ok, rows} ->
      case create_imported_row(attrs) do
        {:ok, row} -> {:cont, {:ok, [row | rows]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      error -> error
    end
  end

  @doc """
  Returns a changeset for imported row form handling and validation.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Ingestion.change_imported_row(%AurumFinance.Ingestion.ImportedRow{}, %{
      ...>     imported_file_id: Ecto.UUID.generate(),
      ...>     account_id: Ecto.UUID.generate(),
      ...>     row_index: 0,
      ...>     raw_data: %{"description" => "Coffee"},
      ...>     fingerprint: "fp-1",
      ...>     status: :ready
      ...>   })
      iex> changeset.valid?
      true
  """
  @spec change_imported_row(ImportedRow.t(), map()) :: Ecto.Changeset.t()
  def change_imported_row(%ImportedRow{} = imported_row, attrs \\ %{}) do
    ImportedRow.changeset(imported_row, attrs)
  end

  defp require_account_scope!(opts, function_name) do
    case Keyword.fetch(opts, :account_id) do
      {:ok, account_id} when not is_nil(account_id) -> opts
      _ -> raise ArgumentError, "#{function_name} requires :account_id"
    end
  end

  defp duplicate_fingerprints_query(opts) do
    opts = require_fingerprints!(opts)

    ImportedRow
    |> where(
      [imported_row],
      imported_row.account_id == ^Keyword.fetch!(opts, :account_id) and
        imported_row.status == :ready and
        imported_row.fingerprint in ^Keyword.fetch!(opts, :fingerprints)
    )
    |> select([imported_row], imported_row.fingerprint)
  end

  defp require_fingerprints!(opts) do
    case Keyword.fetch(opts, :fingerprints) do
      {:ok, fingerprints} when is_list(fingerprints) -> opts
      _ -> raise ArgumentError, "list_duplicate_fingerprints/1 requires :fingerprints"
    end
  end

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where([imported_file], imported_file.account_id == ^account_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:status, status} | rest]) do
    query
    |> where([imported_file], imported_file.status == ^status)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:format, format} | rest]) do
    query
    |> where([imported_file], imported_file.format == ^format)
    |> filter_query(rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end

  defp row_filter_query(query, []), do: query

  defp row_filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where([imported_row], imported_row.account_id == ^account_id)
    |> row_filter_query(rest)
  end

  defp row_filter_query(query, [{:imported_file_id, imported_file_id} | rest]) do
    query
    |> where([imported_row], imported_row.imported_file_id == ^imported_file_id)
    |> row_filter_query(rest)
  end

  defp row_filter_query(query, [{:status, status} | rest]) do
    query
    |> where([imported_row], imported_row.status == ^status)
    |> row_filter_query(rest)
  end

  defp row_filter_query(query, [{:fingerprint, fingerprint} | rest]) do
    query
    |> where([imported_row], imported_row.fingerprint == ^fingerprint)
    |> row_filter_query(rest)
  end

  defp row_filter_query(query, [_unknown_filter | rest]) do
    row_filter_query(query, rest)
  end
end
