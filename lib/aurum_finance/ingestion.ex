defmodule AurumFinance.Ingestion do
  @moduledoc """
  The Ingestion context, responsible for uploaded source files and import-run state.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ImportRowMaterialization
  alias AurumFinance.Ingestion.ImportWorker
  alias AurumFinance.Ingestion.LocalFileStorage
  alias AurumFinance.Ingestion.MaterializationWorker
  alias AurumFinance.Ingestion.Parser
  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ingestion.PubSub
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

  @type materialization_list_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:imported_file_id, Ecto.UUID.t()}
          | {:status, :pending | :processing | :completed | :completed_with_errors | :failed}

  @type row_materialization_list_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:imported_file_id, Ecto.UUID.t()}
          | {:import_materialization_id, Ecto.UUID.t()}
          | {:imported_row_id, Ecto.UUID.t()}

  @type request_materialization_opt :: {:requested_by, String.t()}

  @type normalize_opt ::
          {:account, AurumFinance.Ledger.Account.t()}
          | {:default_currency, String.t()}
          | {:source_locale, String.t()}

  @type duplicate_lookup_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:fingerprints, [String.t()]}

  @audit_actor "system"
  @audit_channel :system
  @audit_entity_type "imported_file"
  @upload_audit_action "uploaded"

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
    |> preload(account: [:entity])
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
    attrs
    |> imported_file_changeset()
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

      case create_audited_imported_file(imported_file_attrs) do
        {:ok, imported_file} ->
          :ok = PubSub.broadcast_imported_file(imported_file)
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

  @doc """
  Lists currently materializable imported rows.

  Only returns rows that are:

  - `ready`
  - not already committed
  - currency-safe for the imported account

  ## Examples

  ```elixir
  rows =
    AurumFinance.Ingestion.list_materializable_imported_rows(
      account_id: account.id,
      imported_file_id: imported_file.id
    )
  ```

  Error path:

      iex> AurumFinance.Ingestion.list_materializable_imported_rows()
      ** (ArgumentError) list_materializable_imported_rows/1 requires :account_id
  """
  @spec list_materializable_imported_rows([row_list_opt()]) :: [ImportedRow.t()]
  def list_materializable_imported_rows(opts \\ []) do
    opts = require_account_scope!(opts, "list_materializable_imported_rows/1")

    opts
    |> list_materializable_imported_rows_query()
    |> Repo.all()
  end

  @doc """
  Lists materialization runs within one account scope.

  ## Examples

  ```elixir
  materializations =
    AurumFinance.Ingestion.list_import_materializations(
      account_id: account.id,
      imported_file_id: imported_file.id
    )
  ```

  Error path:

      iex> AurumFinance.Ingestion.list_import_materializations()
      ** (ArgumentError) list_import_materializations/1 requires :account_id
  """
  @spec list_import_materializations([materialization_list_opt()]) :: [ImportMaterialization.t()]
  def list_import_materializations(opts \\ []) do
    opts = require_account_scope!(opts, "list_import_materializations/1")

    opts
    |> list_import_materializations_query()
    |> Repo.all()
  end

  @doc """
  Lists durable row-level materialization outcomes within one account scope.

  The returned rows are preloaded with their imported-row evidence and any
  committed transaction traceability.

  ## Examples

  ```elixir
  row_materializations =
    AurumFinance.Ingestion.list_import_row_materializations(
      account_id: account.id,
      imported_file_id: imported_file.id
    )
  ```

  Error path:

      iex> AurumFinance.Ingestion.list_import_row_materializations()
      ** (ArgumentError) list_import_row_materializations/1 requires :account_id
  """
  @spec list_import_row_materializations([row_materialization_list_opt()]) :: [
          ImportRowMaterialization.t()
        ]
  def list_import_row_materializations(opts \\ []) do
    opts = require_account_scope!(opts, "list_import_row_materializations/1")

    opts
    |> list_import_row_materializations_query()
    |> Repo.all()
  end

  @doc """
  Persists a pending materialization run and enqueues the async worker.

  ## Examples

  ```elixir
  {:ok, materialization} =
    AurumFinance.Ingestion.request_materialization(account.id, imported_file.id,
      requested_by: "reviewer@example.com"
    )
  ```

  Error path:

      iex> AurumFinance.Ingestion.request_materialization(Ecto.UUID.generate(), Ecto.UUID.generate())
      {:error, :not_found}
  """
  @spec request_materialization(Ecto.UUID.t(), Ecto.UUID.t(), [request_materialization_opt()]) ::
          {:ok, ImportMaterialization.t()} | {:error, term()}
  def request_materialization(account_id, imported_file_id, opts \\ []) do
    requested_by = Keyword.get(opts, :requested_by, @audit_actor)

    with {:ok, imported_file} <- fetch_imported_file(account_id, imported_file_id),
         :ok <- ensure_no_active_materialization(imported_file),
         {:ok, rows_considered} <-
           build_materialization_request_rows(account_id, imported_file.id) do
      imported_file
      |> materialization_request_attrs(account_id, requested_by, rows_considered)
      |> insert_materialization_request()
    end
  end

  @doc """
  Hard-deletes one imported CSV and its imported rows before any materialization
  workflow state exists for that file.

  This is the supported v1 recovery path when a CSV import was wrong and needs
  to be re-imported correctly.

  ## Examples

  ```elixir
  {:ok, imported_file} =
    AurumFinance.Ingestion.delete_imported_file(account.id, imported_file.id)
  ```

  Error path:

      iex> AurumFinance.Ingestion.delete_imported_file(Ecto.UUID.generate(), Ecto.UUID.generate())
      {:error, :not_found}
  """
  @spec delete_imported_file(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, ImportedFile.t()} | {:error, term()}
  def delete_imported_file(account_id, imported_file_id) do
    with {:ok, imported_file} <- fetch_imported_file(account_id, imported_file_id),
         :ok <- ensure_imported_file_deletable(imported_file) do
      delete_imported_file_record(imported_file)
    end
  end

  defp list_imported_files_query(opts) do
    opts = require_account_scope!(opts, "list_imported_files_query/1")

    ImportedFile
    |> filter_query(opts)
    |> order_by([imported_file], desc: imported_file.inserted_at)
  end

  defp imported_file_changeset(attrs) do
    %ImportedFile{}
    |> ImportedFile.changeset(attrs)
  end

  defp create_audited_imported_file(attrs) do
    attrs
    |> imported_file_changeset()
    |> Audit.insert_and_log(%{
      actor: @audit_actor,
      channel: @audit_channel,
      entity_type: @audit_entity_type,
      action: @upload_audit_action,
      metadata: %{account_id: Map.fetch!(attrs, :account_id)}
    })
  end

  defp list_imported_rows_query(opts) do
    opts = require_account_scope!(opts, "list_imported_rows_query/1")

    ImportedRow
    |> row_filter_query(opts)
    |> order_by([imported_row], asc: imported_row.row_index, asc: imported_row.inserted_at)
  end

  defp list_materializable_imported_rows_query(opts) do
    opts = require_account_scope!(opts, "list_materializable_imported_rows_query/1")

    from(imported_row in ImportedRow, as: :imported_row)
    |> join(:inner, [imported_row], account in assoc(imported_row, :account), as: :account)
    |> join(
      :left,
      [imported_row],
      committed in assoc(imported_row, :row_materializations),
      on: committed.status == :committed,
      as: :committed_materialization
    )
    |> preload([account: account], account: account)
    |> materializable_row_filter_query(opts)
    |> where([committed_materialization: committed], is_nil(committed.id))
    |> where(
      [account: account, imported_row: imported_row],
      is_nil(imported_row.currency) or imported_row.currency == account.currency_code
    )
    |> where([imported_row: imported_row], imported_row.status == :ready)
    |> order_by([imported_row: imported_row],
      asc: imported_row.row_index,
      asc: imported_row.inserted_at
    )
  end

  defp list_import_materializations_query(opts) do
    opts = require_account_scope!(opts, "list_import_materializations_query/1")

    ImportMaterialization
    |> materialization_filter_query(opts)
    |> order_by([materialization], desc: materialization.inserted_at)
  end

  defp require_account_scope!(opts, function_name) do
    opts
    |> Keyword.fetch(:account_id)
    |> require_account_scope_result(opts, function_name)
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
    opts
    |> Keyword.fetch(:fingerprints)
    |> require_fingerprints_result(opts)
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

  defp materializable_row_filter_query(query, []), do: query

  defp materializable_row_filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where([imported_row: imported_row], imported_row.account_id == ^account_id)
    |> materializable_row_filter_query(rest)
  end

  defp materializable_row_filter_query(query, [{:imported_file_id, imported_file_id} | rest]) do
    query
    |> where([imported_row: imported_row], imported_row.imported_file_id == ^imported_file_id)
    |> materializable_row_filter_query(rest)
  end

  defp materializable_row_filter_query(query, [_unknown_filter | rest]) do
    materializable_row_filter_query(query, rest)
  end

  defp materialization_filter_query(query, []), do: query

  defp materialization_filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where([materialization], materialization.account_id == ^account_id)
    |> materialization_filter_query(rest)
  end

  defp materialization_filter_query(query, [{:imported_file_id, imported_file_id} | rest]) do
    query
    |> where([materialization], materialization.imported_file_id == ^imported_file_id)
    |> materialization_filter_query(rest)
  end

  defp materialization_filter_query(query, [{:status, status} | rest]) do
    query
    |> where([materialization], materialization.status == ^status)
    |> materialization_filter_query(rest)
  end

  defp materialization_filter_query(query, [_unknown_filter | rest]) do
    materialization_filter_query(query, rest)
  end

  defp row_materialization_filter_query(query, []), do: query

  defp row_materialization_filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where(
      [row_materialization, imported_row: imported_row],
      imported_row.account_id == ^account_id
    )
    |> row_materialization_filter_query(rest)
  end

  defp row_materialization_filter_query(
         query,
         [{:imported_file_id, imported_file_id} | rest]
       ) do
    query
    |> where(
      [row_materialization, imported_row: imported_row],
      imported_row.imported_file_id == ^imported_file_id
    )
    |> row_materialization_filter_query(rest)
  end

  defp row_materialization_filter_query(
         query,
         [{:import_materialization_id, import_materialization_id} | rest]
       ) do
    query
    |> where(
      [row_materialization],
      row_materialization.import_materialization_id == ^import_materialization_id
    )
    |> row_materialization_filter_query(rest)
  end

  defp row_materialization_filter_query(query, [{:imported_row_id, imported_row_id} | rest]) do
    query
    |> where([row_materialization], row_materialization.imported_row_id == ^imported_row_id)
    |> row_materialization_filter_query(rest)
  end

  defp row_materialization_filter_query(query, [_unknown_filter | rest]) do
    row_materialization_filter_query(query, rest)
  end

  defp fetch_imported_file(account_id, imported_file_id) do
    account_id
    |> get_imported_file(imported_file_id)
    |> fetch_imported_file_result()
  end

  defp build_materialization_request_rows(account_id, imported_file_id) do
    [account_id: account_id, imported_file_id: imported_file_id]
    |> list_materializable_imported_rows_query()
    |> Repo.all()
    |> maybe_return_materialization_request_rows()
  end

  defp materialization_request_attrs(
         %ImportedFile{} = imported_file,
         account_id,
         requested_by,
         rows_considered
       ) do
    %{
      imported_file_id: imported_file.id,
      account_id: account_id,
      status: :pending,
      requested_by: requested_by,
      rows_considered: length(rows_considered),
      rows_skipped_duplicate: count_skipped_duplicate_rows(account_id, imported_file.id)
    }
  end

  defp insert_materialization_request(attrs) do
    Repo.transaction(fn ->
      with {:ok, materialization} <- insert_import_materialization(attrs),
           {:ok, _job} <- enqueue_materialization_request(materialization) do
        materialization
      else
        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
    |> insert_materialization_request_result()
  end

  defp insert_import_materialization(attrs) do
    %ImportMaterialization{}
    |> ImportMaterialization.changeset(attrs)
    |> Repo.insert()
  end

  defp enqueue_materialization_request(%ImportMaterialization{} = materialization) do
    materialization
    |> MaterializationWorker.new_job()
    |> Oban.insert()
  end

  defp maybe_return_materialization_request_rows([]),
    do:
      {:error,
       Gettext.dgettext(
         AurumFinanceWeb.Gettext,
         "errors",
         "error_import_materialization_no_rows_to_materialize"
       )}

  defp maybe_return_materialization_request_rows(rows), do: {:ok, rows}

  defp ensure_no_active_materialization(%ImportedFile{} = imported_file) do
    imported_file
    |> imported_file_has_active_materialization?()
    |> ensure_no_active_materialization_result()
  end

  defp ensure_imported_file_deletable(%ImportedFile{} = imported_file) do
    imported_file
    |> imported_file_has_materializations?()
    |> ensure_imported_file_deletable_result()
  end

  defp delete_imported_file_record(%ImportedFile{} = imported_file) do
    Repo.transaction(fn ->
      imported_file
      |> delete_imported_rows()
      |> delete_imported_file_step(imported_file)
      |> delete_imported_file_storage_step(imported_file)
    end)
    |> delete_imported_file_record_result()
  end

  defp delete_imported_rows(%ImportedFile{} = imported_file) do
    from(imported_row in ImportedRow, where: imported_row.imported_file_id == ^imported_file.id)
    |> Repo.delete_all()
  end

  defp delete_imported_file_step({_count, nil}, %ImportedFile{} = imported_file) do
    case Repo.delete(imported_file) do
      {:ok, deleted_imported_file} -> deleted_imported_file
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp delete_imported_file_storage_step(
         %ImportedFile{} = deleted_imported_file,
         %ImportedFile{} = imported_file
       ) do
    case LocalFileStorage.delete(imported_file.storage_path) do
      :ok -> deleted_imported_file
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp require_account_scope_result({:ok, account_id}, opts, _function_name)
       when not is_nil(account_id),
       do: opts

  defp require_account_scope_result(_result, _opts, function_name) do
    raise ArgumentError, "#{function_name} requires :account_id"
  end

  defp require_fingerprints_result({:ok, fingerprints}, opts) when is_list(fingerprints), do: opts

  defp require_fingerprints_result(_result, _opts) do
    raise ArgumentError, "list_duplicate_fingerprints/1 requires :fingerprints"
  end

  defp fetch_imported_file_result(%ImportedFile{} = imported_file), do: {:ok, imported_file}
  defp fetch_imported_file_result(nil), do: {:error, :not_found}

  defp insert_materialization_request_result({:ok, %ImportMaterialization{} = materialization}) do
    :ok = PubSub.broadcast_materialization_requested(materialization)
    {:ok, materialization}
  end

  defp insert_materialization_request_result({:error, reason}), do: {:error, reason}

  defp ensure_imported_file_deletable_result(false), do: :ok

  defp ensure_imported_file_deletable_result(true) do
    {:error,
     Gettext.dgettext(
       AurumFinanceWeb.Gettext,
       "import",
       "error_import_delete_blocked_by_materialization"
     )}
  end

  defp ensure_no_active_materialization_result(false), do: :ok

  defp ensure_no_active_materialization_result(true) do
    {:error,
     Gettext.dgettext(
       AurumFinanceWeb.Gettext,
       "errors",
       "error_import_materialization_already_in_progress"
     )}
  end

  defp imported_file_has_materializations?(%ImportedFile{} = imported_file) do
    from(materialization in ImportMaterialization,
      where: materialization.imported_file_id == ^imported_file.id,
      select: 1
    )
    |> Repo.exists?()
  end

  defp imported_file_has_active_materialization?(%ImportedFile{} = imported_file) do
    from(materialization in ImportMaterialization,
      where:
        materialization.imported_file_id == ^imported_file.id and
          materialization.status in [:pending, :processing],
      select: 1
    )
    |> Repo.exists?()
  end

  defp delete_imported_file_record_result({:ok, %ImportedFile{} = imported_file}) do
    {:ok, imported_file}
  end

  defp delete_imported_file_record_result({:error, reason}), do: {:error, reason}

  defp count_skipped_duplicate_rows(account_id, imported_file_id) do
    from(imported_row in ImportedRow, as: :imported_row)
    |> join(
      :left,
      [imported_row],
      committed in assoc(imported_row, :row_materializations),
      on: committed.status == :committed,
      as: :committed_materialization
    )
    |> where(
      [imported_row: imported_row, committed_materialization: committed],
      imported_row.account_id == ^account_id and
        imported_row.imported_file_id == ^imported_file_id and
        imported_row.status == :duplicate and
        is_nil(committed.id)
    )
    |> Repo.aggregate(:count)
  end

  defp list_import_row_materializations_query(opts) do
    opts = require_account_scope!(opts, "list_import_row_materializations_query/1")

    ImportRowMaterialization
    |> join(
      :inner,
      [row_materialization],
      imported_row in assoc(row_materialization, :imported_row),
      as: :imported_row
    )
    |> preload([_row_materialization, imported_row: imported_row], [
      :transaction,
      imported_row: imported_row
    ])
    |> row_materialization_filter_query(opts)
    |> order_by(
      [row_materialization, imported_row: imported_row],
      desc: row_materialization.inserted_at,
      asc: imported_row.row_index
    )
  end
end
