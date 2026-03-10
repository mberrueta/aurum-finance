defmodule AurumFinance.IngestionTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ImportedRow

  describe "change_imported_file/2" do
    test "requires account-scoped persisted file fields" do
      changeset = Ingestion.change_imported_file(%ImportedFile{}, %{})

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).account_id
      assert "error_field_required" in errors_on(changeset).filename
      assert "error_field_required" in errors_on(changeset).sha256
      assert "error_field_required" in errors_on(changeset).format
      assert "error_field_required" in errors_on(changeset).status
      assert "error_field_required" in errors_on(changeset).storage_path
    end

    test "rejects invalid sha256 length and negative counters" do
      changeset =
        Ingestion.change_imported_file(%ImportedFile{}, %{
          account_id: Ecto.UUID.generate(),
          filename: "statement.csv",
          sha256: "short",
          format: :csv,
          status: :pending,
          storage_path: "/tmp/imports/statement.csv",
          row_count: -1,
          byte_size: -4
        })

      refute changeset.valid?
      assert "SHA256 must be exactly 64 characters." in errors_on(changeset).sha256
      assert "Count must be zero or greater." in errors_on(changeset).row_count
      assert "Byte size must be zero or greater." in errors_on(changeset).byte_size
    end
  end

  describe "imported file lifecycle" do
    test "list_imported_files/1 requires account scope" do
      assert_raise ArgumentError, "list_imported_files/1 requires :account_id", fn ->
        Ingestion.list_imported_files()
      end
    end

    test "creates imported files and allows repeated sha256 values" do
      entity = entity_fixture(%{name: "Import entity"})
      account = account_fixture(entity, %{name: "Import checking"})

      sha256 = String.duplicate("a", 64)

      assert {:ok, first} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "march.csv",
                 sha256: sha256,
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/march.csv"
               })

      assert {:ok, second} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "march-overlap.csv",
                 sha256: sha256,
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/march-overlap.csv"
               })

      assert first.sha256 == sha256
      assert second.sha256 == sha256
      refute first.id == second.id
    end

    test "list_imported_files/1 is account-scoped and filterable by status" do
      entity = entity_fixture(%{name: "Scoped imports"})
      other_entity = entity_fixture(%{name: "Other scoped imports"})

      account = account_fixture(entity, %{name: "Primary import account"})
      other_account = account_fixture(other_entity, %{name: "Foreign import account"})

      assert {:ok, pending} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "pending.csv",
                 sha256: String.duplicate("a", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/pending.csv"
               })

      assert {:ok, complete} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "complete.csv",
                 sha256: String.duplicate("b", 64),
                 format: :csv,
                 status: :complete,
                 storage_path: "/tmp/imports/complete.csv"
               })

      assert {:ok, _foreign} =
               Ingestion.create_imported_file(%{
                 account_id: other_account.id,
                 filename: "foreign.csv",
                 sha256: String.duplicate("c", 64),
                 format: :csv,
                 status: :complete,
                 storage_path: "/tmp/imports/foreign.csv"
               })

      assert Enum.map(Ingestion.list_imported_files(account_id: account.id), & &1.id) == [
               complete.id,
               pending.id
             ]

      assert Enum.map(
               Ingestion.list_imported_files(account_id: account.id, status: :complete),
               & &1.id
             ) == [complete.id]
    end

    test "get_imported_file!/2 enforces the account boundary" do
      entity = entity_fixture(%{name: "Owner entity"})
      other_entity = entity_fixture(%{name: "Other owner entity"})
      account = account_fixture(entity, %{name: "Owner account"})
      other_account = account_fixture(other_entity, %{name: "Other account"})

      assert {:ok, imported_file} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "statement.csv",
                 sha256: String.duplicate("d", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/statement.csv"
               })

      assert Ingestion.get_imported_file!(account.id, imported_file.id).id == imported_file.id

      assert_raise Ecto.NoResultsError, fn ->
        Ingestion.get_imported_file!(other_account.id, imported_file.id)
      end
    end

    test "update_imported_file/2 persists summary counts and processed_at" do
      entity = entity_fixture(%{name: "Summary entity"})
      account = account_fixture(entity, %{name: "Summary account"})

      assert {:ok, imported_file} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "summary.csv",
                 sha256: String.duplicate("e", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/summary.csv",
                 warnings: %{"header" => "normalized"}
               })

      processed_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)

      assert {:ok, updated} =
               Ingestion.update_imported_file(imported_file, %{
                 status: :complete,
                 row_count: 12,
                 imported_row_count: 8,
                 skipped_row_count: 3,
                 invalid_row_count: 1,
                 processed_at: processed_at
               })

      assert updated.status == :complete
      assert updated.row_count == 12
      assert updated.imported_row_count == 8
      assert updated.skipped_row_count == 3
      assert updated.invalid_row_count == 1
      assert updated.warnings == %{"header" => "normalized"}
      assert updated.processed_at == processed_at
    end
  end

  describe "change_imported_row/2" do
    test "requires row evidence fields" do
      changeset = Ingestion.change_imported_row(%ImportedRow{}, %{})

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).imported_file_id
      assert "error_field_required" in errors_on(changeset).account_id
      assert "error_field_required" in errors_on(changeset).row_index
      assert "error_field_required" in errors_on(changeset).raw_data
      assert "error_field_required" in errors_on(changeset).status
    end

    test "requires fingerprint for ready and duplicate rows but not invalid rows" do
      ready_changeset =
        Ingestion.change_imported_row(%ImportedRow{}, %{
          imported_file_id: Ecto.UUID.generate(),
          account_id: Ecto.UUID.generate(),
          row_index: 0,
          raw_data: %{"description" => "Coffee"},
          status: :ready
        })

      duplicate_changeset =
        Ingestion.change_imported_row(%ImportedRow{}, %{
          imported_file_id: Ecto.UUID.generate(),
          account_id: Ecto.UUID.generate(),
          row_index: 1,
          raw_data: %{"description" => "Coffee"},
          status: :duplicate
        })

      invalid_changeset =
        Ingestion.change_imported_row(%ImportedRow{}, %{
          imported_file_id: Ecto.UUID.generate(),
          account_id: Ecto.UUID.generate(),
          row_index: 2,
          raw_data: %{"description" => "Broken row"},
          status: :invalid,
          validation_error: "missing date"
        })

      refute ready_changeset.valid?
      refute duplicate_changeset.valid?

      assert "Fingerprint is required for ready and duplicate rows." in errors_on(ready_changeset).fingerprint

      assert "Fingerprint is required for ready and duplicate rows." in errors_on(
               duplicate_changeset
             ).fingerprint

      assert invalid_changeset.valid?
    end
  end

  describe "imported row persistence" do
    test "list_imported_rows/1 requires account scope" do
      assert_raise ArgumentError, "list_imported_rows/1 requires :account_id", fn ->
        Ingestion.list_imported_rows()
      end
    end

    test "creates immutable-style row evidence and lists rows by imported file" do
      entity = entity_fixture(%{name: "Rows entity"})
      account = account_fixture(entity, %{name: "Rows account"})

      assert {:ok, imported_file} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "rows.csv",
                 sha256: String.duplicate("f", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/rows.csv"
               })

      assert {:ok, ready_row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 0,
                 raw_data: %{"description" => "Coffee", "amount" => "-4.50"},
                 description: "Coffee",
                 normalized_description: "coffee",
                 posted_on: ~D[2026-03-10],
                 amount: Decimal.new("-4.50"),
                 currency: "usd",
                 fingerprint: "fp-ready-1",
                 status: :ready
               })

      assert {:ok, invalid_row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 1,
                 raw_data: %{"description" => nil},
                 status: :invalid,
                 validation_error: "missing description"
               })

      assert ready_row.currency == "USD"
      assert is_nil(invalid_row.fingerprint)

      assert Enum.map(
               Ingestion.list_imported_rows(
                 account_id: account.id,
                 imported_file_id: imported_file.id
               ),
               & &1.id
             ) == [ready_row.id, invalid_row.id]
    end

    test "enforces the partial unique index for ready rows" do
      entity = entity_fixture(%{name: "Duplicate row entity"})
      account = account_fixture(entity, %{name: "Duplicate row account"})

      assert {:ok, imported_file} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "dedupe.csv",
                 sha256: String.duplicate("1", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/dedupe.csv"
               })

      fingerprint = "fp-duplicate-check"

      assert {:ok, _row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 0,
                 raw_data: %{"description" => "Coffee"},
                 fingerprint: fingerprint,
                 status: :ready
               })

      assert {:error, changeset} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 1,
                 raw_data: %{"description" => "Coffee again"},
                 fingerprint: fingerprint,
                 status: :ready
               })

      assert "has already been taken" in errors_on(changeset).fingerprint
    end

    test "allows duplicate and invalid rows to coexist with the same fingerprint" do
      entity = entity_fixture(%{name: "Row coexist entity"})
      account = account_fixture(entity, %{name: "Row coexist account"})

      assert {:ok, imported_file} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "coexist.csv",
                 sha256: String.duplicate("2", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/coexist.csv"
               })

      fingerprint = "fp-shared"

      assert {:ok, _ready} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 0,
                 raw_data: %{"description" => "First"},
                 fingerprint: fingerprint,
                 status: :ready
               })

      assert {:ok, duplicate} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 1,
                 raw_data: %{"description" => "Second"},
                 fingerprint: fingerprint,
                 status: :duplicate,
                 skip_reason: "already imported"
               })

      assert {:ok, invalid} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 2,
                 raw_data: %{"description" => "Third"},
                 status: :invalid,
                 validation_error: "missing date"
               })

      assert duplicate.status == :duplicate
      assert invalid.status == :invalid
    end
  end
end
