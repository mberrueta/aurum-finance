defmodule AurumFinance.Ingestion.LocalFileStorage do
  @moduledoc """
  Local filesystem storage for uploaded import source files.
  """

  alias AurumFinance.Helpers

  @type store_attrs :: %{
          required(:account_id) => Ecto.UUID.t(),
          required(:filename) => String.t(),
          optional(:content) => binary(),
          optional(:source_path) => String.t(),
          optional(:content_type) => String.t() | nil,
          optional(:storage_id) => Ecto.UUID.t()
        }

  @type stored_metadata :: %{
          filename: String.t(),
          content_type: String.t() | nil,
          byte_size: non_neg_integer(),
          sha256: String.t(),
          storage_path: String.t()
        }

  @doc """
  Stores an uploaded file payload on local disk and returns captured metadata.

  The same payload may be stored multiple times. Identical `sha256` values do
  not block storage.

  ## Examples

  ```elixir
  {:ok, metadata} =
    AurumFinance.Ingestion.LocalFileStorage.store(%{
      account_id: Ecto.UUID.generate(),
      filename: "statement.csv",
      content: "date,amount\\n2026-03-10,10.00\\n"
    })

  metadata.sha256
  #=> "..."
  ```
  """
  @spec store(store_attrs()) :: {:ok, stored_metadata()} | {:error, term()}
  def store(attrs) when is_map(attrs) do
    with {:ok, content} <- extract_content(attrs),
         {:ok, metadata} <- build_metadata(attrs, content),
         :ok <- File.mkdir_p(Path.dirname(metadata.storage_path)),
         :ok <- File.write(metadata.storage_path, content) do
      {:ok, metadata}
    end
  end

  @doc """
  Deletes a previously stored file if it exists.

  ## Examples

  ```elixir
  :ok = AurumFinance.Ingestion.LocalFileStorage.delete("/tmp/aurum/import.csv")
  ```
  """
  @spec delete(String.t() | nil) :: :ok | {:error, term()}
  def delete(nil), do: :ok

  def delete(storage_path) when is_binary(storage_path) do
    case File.rm(storage_path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns the configured base path used for import storage.
  """
  @spec base_path() :: String.t()
  def base_path do
    Application.fetch_env!(:aurum_finance, __MODULE__)[:base_path]
  end

  defp extract_content(%{content: content}) when is_binary(content), do: {:ok, content}

  defp extract_content(%{source_path: source_path}) when is_binary(source_path) do
    File.read(source_path)
  end

  defp extract_content(_attrs), do: {:error, :missing_content}

  defp build_metadata(%{account_id: account_id, filename: filename} = attrs, content)
       when is_binary(filename) do
    filename = Path.basename(filename)
    sha256 = sha256(content)
    byte_size = byte_size(content)
    storage_id = Map.get(attrs, :storage_id, Ecto.UUID.generate())
    storage_path = build_storage_path(account_id, sha256, storage_id, filename)

    {:ok,
     %{
       filename: filename,
       content_type: attrs |> Map.get(:content_type) |> Helpers.blank_to_nil(),
       byte_size: byte_size,
       sha256: sha256,
       storage_path: storage_path
     }}
  end

  defp build_metadata(_attrs, _content), do: {:error, :missing_metadata}

  defp build_storage_path(account_id, sha256, storage_id, filename) do
    sanitized_filename = sanitize_filename(filename)

    Path.join([
      base_path(),
      account_id,
      String.slice(sha256, 0, 2),
      String.slice(sha256, 2, 2),
      "#{storage_id}-#{sanitized_filename}"
    ])
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^A-Za-z0-9.\-_]+/u, "_")
    |> String.trim("_")
    |> case do
      "" -> "upload.bin"
      sanitized -> sanitized
    end
  end

  defp sha256(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
  end
end
