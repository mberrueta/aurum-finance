defmodule AurumFinance.Ingestion.MaterializationWorker do
  @moduledoc """
  Oban worker placeholder for async import materialization.

  Task 05 introduces durable run creation and enqueueing. The actual ledger
  materialization workflow is implemented in Task 06.
  """

  use Oban.Worker, queue: :materializations, max_attempts: 5

  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.MaterializationRunner

  @doc """
  Builds a new Oban job for one import materialization run.
  """
  @spec new_job(ImportMaterialization.t()) :: Oban.Job.changeset()
  def new_job(%ImportMaterialization{} = import_materialization) do
    %{
      "account_id" => import_materialization.account_id,
      "import_materialization_id" => import_materialization.id,
      "imported_file_id" => import_materialization.imported_file_id
    }
    |> new()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "account_id" => account_id,
          "import_materialization_id" => import_materialization_id,
          "imported_file_id" => imported_file_id
        }
      }) do
    account_id
    |> MaterializationRunner.run(imported_file_id, import_materialization_id)
    |> perform_result()
  end

  def perform(%Oban.Job{}), do: {:discard, "invalid materialization job args"}

  defp perform_result(:ok), do: :ok
  defp perform_result({:error, :not_found}), do: {:discard, :not_found}
  defp perform_result({:error, reason}), do: {:error, reason}
end
