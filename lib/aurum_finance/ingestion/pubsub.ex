defmodule AurumFinance.Ingestion.PubSub do
  @moduledoc """
  PubSub helpers for import lifecycle notifications.

  Notifications are state-change signals only. LiveViews should re-read
  persisted state after receiving them.
  """

  alias AurumFinance.Ingestion.ImportedFile

  @type notification :: %{
          account_id: Ecto.UUID.t(),
          imported_file_id: Ecto.UUID.t(),
          status: :pending | :processing | :complete | :failed
        }

  @doc """
  Subscribes the caller to account-scoped import history updates.
  """
  @spec subscribe_account_imports(Ecto.UUID.t()) :: :ok | {:error, term()}
  def subscribe_account_imports(account_id) when is_binary(account_id) do
    Phoenix.PubSub.subscribe(AurumFinance.PubSub, account_topic(account_id))
  end

  @doc """
  Subscribes the caller to lifecycle updates for one imported file.
  """
  @spec subscribe_imported_file(Ecto.UUID.t()) :: :ok | {:error, term()}
  def subscribe_imported_file(imported_file_id) when is_binary(imported_file_id) do
    Phoenix.PubSub.subscribe(AurumFinance.PubSub, imported_file_topic(imported_file_id))
  end

  @doc """
  Broadcasts an import lifecycle notification to both the account history topic
  and the imported-file detail topic.

  ## Examples

      iex> imported_file = %AurumFinance.Ingestion.ImportedFile{
      ...>   id: Ecto.UUID.generate(),
      ...>   account_id: Ecto.UUID.generate(),
      ...>   status: :pending
      ...> }
      iex> AurumFinance.Ingestion.PubSub.broadcast_imported_file(imported_file)
      :ok
  """
  @spec broadcast_imported_file(ImportedFile.t()) :: :ok
  def broadcast_imported_file(%ImportedFile{} = imported_file) do
    notification = notification(imported_file)

    imported_file
    |> account_topic()
    |> broadcast({:import_updated, notification})

    imported_file
    |> imported_file_topic()
    |> broadcast({:import_updated, notification})
  end

  defp notification(%ImportedFile{} = imported_file) do
    %{
      account_id: imported_file.account_id,
      imported_file_id: imported_file.id,
      status: imported_file.status
    }
  end

  defp account_topic(%ImportedFile{account_id: account_id}), do: account_topic(account_id)
  defp account_topic(account_id), do: "ingestion:account_imports:#{account_id}"

  defp imported_file_topic(%ImportedFile{id: imported_file_id}),
    do: imported_file_topic(imported_file_id)

  defp imported_file_topic(imported_file_id), do: "ingestion:imported_file:#{imported_file_id}"

  defp broadcast(topic, message) do
    AurumFinance.PubSub
    |> Phoenix.PubSub.broadcast(topic, message)
    |> normalize_broadcast_result()
  end

  defp normalize_broadcast_result(:ok), do: :ok
  defp normalize_broadcast_result({:error, _reason}), do: :ok
end
