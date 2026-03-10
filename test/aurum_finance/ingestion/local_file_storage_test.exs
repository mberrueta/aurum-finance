defmodule AurumFinance.Ingestion.LocalFileStorageTest do
  use ExUnit.Case, async: false

  alias AurumFinance.Ingestion.LocalFileStorage

  setup do
    original_config = Application.get_env(:aurum_finance, LocalFileStorage)

    base_path =
      Path.join(
        System.tmp_dir!(),
        "aurum_finance_local_storage_test_#{System.unique_integer([:positive])}"
      )

    Application.put_env(:aurum_finance, LocalFileStorage, base_path: base_path)

    on_exit(fn ->
      _ = File.rm_rf(base_path)

      if original_config do
        Application.put_env(:aurum_finance, LocalFileStorage, original_config)
      else
        Application.delete_env(:aurum_finance, LocalFileStorage)
      end
    end)

    {:ok, base_path: base_path}
  end

  describe "store/1" do
    test "stores file content under the configured base path and captures metadata", %{
      base_path: base_path
    } do
      content = "date,amount\n2026-03-10,10.00\n"

      assert {:ok, metadata} =
               LocalFileStorage.store(%{
                 account_id: Ecto.UUID.generate(),
                 filename: "statement march.csv",
                 content: content,
                 content_type: "text/csv"
               })

      assert metadata.filename == "statement march.csv"
      assert metadata.content_type == "text/csv"
      assert metadata.byte_size == byte_size(content)
      assert metadata.sha256 == :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      assert String.starts_with?(metadata.storage_path, base_path)
      assert File.read!(metadata.storage_path) == content
    end

    test "supports reading from a source path", %{base_path: base_path} do
      source_path = Path.join(base_path, "source.csv")
      content = "date,amount\n2026-03-10,12.00\n"
      File.mkdir_p!(Path.dirname(source_path))
      File.write!(source_path, content)

      assert {:ok, metadata} =
               LocalFileStorage.store(%{
                 account_id: Ecto.UUID.generate(),
                 filename: "source.csv",
                 source_path: source_path
               })

      assert metadata.byte_size == byte_size(content)
      assert File.read!(metadata.storage_path) == content
    end

    test "allows repeated identical payloads without blocking" do
      payload = "date,amount\n2026-03-10,9.99\n"
      account_id = Ecto.UUID.generate()

      assert {:ok, first} =
               LocalFileStorage.store(%{
                 account_id: account_id,
                 filename: "repeat.csv",
                 content: payload
               })

      assert {:ok, second} =
               LocalFileStorage.store(%{
                 account_id: account_id,
                 filename: "repeat.csv",
                 content: payload
               })

      assert first.sha256 == second.sha256
      refute first.storage_path == second.storage_path
    end
  end

  describe "delete/1" do
    test "removes a stored file when it exists" do
      assert {:ok, metadata} =
               LocalFileStorage.store(%{
                 account_id: Ecto.UUID.generate(),
                 filename: "delete.csv",
                 content: "a,b\n1,2\n"
               })

      assert :ok = LocalFileStorage.delete(metadata.storage_path)
      refute File.exists?(metadata.storage_path)
    end
  end
end
