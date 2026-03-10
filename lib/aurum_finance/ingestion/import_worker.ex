defmodule AurumFinance.Ingestion.ImportWorker do
  @moduledoc """
  Oban worker responsible for triggering asynchronous import processing.
  """

  use Oban.Worker, queue: :imports, max_attempts: 5

  alias AurumFinance.Ingestion.ImportProcessor
  alias AurumFinance.Ingestion.ImportedFile

  @doc """
  Builds a new Oban job for one imported file.

  ## Examples

      iex> imported_file = %AurumFinance.Ingestion.ImportedFile{
      ...>   id: Ecto.UUID.generate(),
      ...>   account_id: Ecto.UUID.generate()
      ...> }
      iex> %Oban.Job{args: %{"account_id" => _, "imported_file_id" => _}} =
      ...>   AurumFinance.Ingestion.ImportWorker.new_job(imported_file)
  """
  @spec new_job(ImportedFile.t()) :: Oban.Job.changeset()
  def new_job(%ImportedFile{} = imported_file) do
    %{
      "account_id" => imported_file.account_id,
      "imported_file_id" => imported_file.id
    }
    |> new()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"account_id" => account_id, "imported_file_id" => imported_file_id}
      }) do
    %ImportedFile{id: imported_file_id, account_id: account_id}
    |> ImportProcessor.run()
    |> case do
      {:ok, _imported_file} -> :ok
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
