defmodule AurumFinance.Ingestion.MaterializationWorker do
  @moduledoc """
  Oban worker placeholder for async import materialization.

  Task 05 introduces durable run creation and enqueueing. The actual ledger
  materialization workflow is implemented in Task 06.
  """

  use Oban.Worker, queue: :materializations, max_attempts: 5

  alias AurumFinance.Ingestion.ImportMaterialization

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
  def perform(%Oban.Job{}) do
    {:error, "materialization worker not implemented yet"}
  end
end
