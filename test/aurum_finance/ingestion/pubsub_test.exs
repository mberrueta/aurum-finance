defmodule AurumFinance.Ingestion.PubSubTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.PubSub

  describe "broadcast_materialization_failed/1" do
    test "broadcasts the failure event to both account and imported-file topics" do
      account_id = Ecto.UUID.generate()
      imported_file_id = Ecto.UUID.generate()
      materialization_id = Ecto.UUID.generate()

      materialization = %ImportMaterialization{
        id: materialization_id,
        account_id: account_id,
        imported_file_id: imported_file_id,
        status: :failed
      }

      assert :ok = PubSub.subscribe_account_imports(account_id)
      assert :ok = PubSub.subscribe_imported_file(imported_file_id)

      assert :ok = PubSub.broadcast_materialization_failed(materialization)

      assert_receive {:materialization_failed,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :failed
                      }}

      assert_receive {:materialization_failed,
                      %{
                        account_id: ^account_id,
                        imported_file_id: ^imported_file_id,
                        import_materialization_id: ^materialization_id,
                        status: :failed
                      }}
    end
  end
end
