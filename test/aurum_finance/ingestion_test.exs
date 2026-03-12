defmodule AurumFinance.IngestionTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit
  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.CanonicalRowCandidate
  alias AurumFinance.Ingestion.Fingerprint
  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ingestion.PubSub
  alias AurumFinance.Ledger.Account

  describe "change_imported_file/2" do
    test "requires account-scoped persisted file fields" do
      changeset = Ingestion.change_imported_file(%ImportedFile{}, %{})

      refute changeset.valid?
      assert "This field is required." in errors_on(changeset).account_id
      assert "This field is required." in errors_on(changeset).filename
      assert "This field is required." in errors_on(changeset).sha256
      assert "This field is required." in errors_on(changeset).format
      assert "This field is required." in errors_on(changeset).status
      assert "This field is required." in errors_on(changeset).storage_path
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
      assert "error_imported_file_sha256_length_invalid" in errors_on(changeset).sha256
      assert "error_imported_file_count_must_be_non_negative" in errors_on(changeset).row_count

      assert "error_imported_file_byte_size_must_be_non_negative" in errors_on(changeset).byte_size
    end
  end

  describe "imported file lifecycle" do
    test "list_imported_files/1 requires account scope" do
      assert_raise ArgumentError, "list_imported_files/1 requires :account_id", fn ->
        Ingestion.list_imported_files()
      end
    end

    test "creates imported files and allows repeated sha256 values" do
      entity = insert(:entity, name: "Import entity")
      account = insert(:account, entity: entity, entity_id: entity.id, name: "Import checking")

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
      entity = insert(:entity, name: "Scoped imports")
      other_entity = insert(:entity, name: "Other scoped imports")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Primary import account")

      other_account =
        insert(
          :account,
          entity: other_entity,
          entity_id: other_entity.id,
          name: "Foreign import account"
        )

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
      entity = insert(:entity, name: "Owner entity")
      other_entity = insert(:entity, name: "Other owner entity")
      account = insert(:account, entity: entity, entity_id: entity.id, name: "Owner account")

      other_account =
        insert(:account, entity: other_entity, entity_id: other_entity.id, name: "Other account")

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
      entity = insert(:entity, name: "Summary entity")
      account = insert(:account, entity: entity, entity_id: entity.id, name: "Summary account")

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

    test "store_imported_file/1 persists storage metadata without blocking repeated sha256 values" do
      entity = insert(:entity, name: "Stored file entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Stored file account")

      payload = "date,amount\n2026-03-10,10.00\n"

      assert {:ok, first} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "statement.csv",
                 content: payload,
                 content_type: "text/csv"
               })

      assert {:ok, second} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "statement.csv",
                 content: payload,
                 content_type: "text/csv"
               })

      assert first.filename == "statement.csv"
      assert first.content_type == "text/csv"
      assert first.byte_size == byte_size(payload)
      assert first.sha256 == second.sha256
      refute first.storage_path == second.storage_path
      assert File.exists?(first.storage_path)
      assert File.exists?(second.storage_path)
    end

    test "store_imported_file/1 broadcasts a pending notification for account history" do
      entity = insert(:entity, name: "PubSub entity")
      account = insert(:account, entity: entity, entity_id: entity.id, name: "PubSub account")

      assert :ok = PubSub.subscribe_account_imports(account.id)

      assert {:ok, imported_file} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "statement.csv",
                 content: "Date,Description,Amount\n2026-03-10,Coffee,-4.50\n",
                 content_type: "text/csv"
               })

      assert_receive {:import_updated,
                      %{
                        account_id: account_id,
                        imported_file_id: imported_file_id,
                        status: :pending
                      }}

      assert account_id == account.id
      assert imported_file_id == imported_file.id
    end

    test "store_imported_file/1 logs an uploaded audit event" do
      entity = insert(:entity, name: "Audit upload entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Audit upload account")

      assert {:ok, imported_file} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "statement.csv",
                 content: "Date,Description,Amount\n2026-03-10,Coffee,-4.50\n",
                 content_type: "text/csv"
               })

      [uploaded_event] =
        Audit.list_audit_events(entity_type: "imported_file", entity_id: imported_file.id)

      assert uploaded_event.action == "uploaded"
      assert uploaded_event.actor == "system"
      assert uploaded_event.channel == :system
      assert uploaded_event.before == nil
      assert uploaded_event.after["status"] == "pending"
      assert uploaded_event.after["filename"] == "statement.csv"
      assert uploaded_event.metadata == %{"account_id" => account.id}
    end
  end

  describe "change_imported_row/2" do
    test "requires row evidence fields" do
      changeset = Ingestion.change_imported_row(%ImportedRow{}, %{})

      refute changeset.valid?
      assert "This field is required." in errors_on(changeset).imported_file_id
      assert "This field is required." in errors_on(changeset).account_id
      assert "This field is required." in errors_on(changeset).row_index
      assert "This field is required." in errors_on(changeset).raw_data
      assert "This field is required." in errors_on(changeset).status
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

      assert "error_imported_row_fingerprint_required" in errors_on(ready_changeset).fingerprint

      assert "error_imported_row_fingerprint_required" in errors_on(duplicate_changeset).fingerprint

      assert invalid_changeset.valid?
    end
  end

  describe "normalize_rows/2" do
    test "normalizes canonical row candidates through the ingestion context" do
      rows = [
        %CanonicalRowCandidate{
          row_index: 1,
          raw_data: %{"Description" => " Uber ", "Currency" => nil},
          canonical_data: %{description: " Uber ", currency: nil}
        }
      ]

      account = %Account{currency_code: "brl"}

      [normalized_row] =
        rows
        |> Ingestion.normalize_rows(account: account)
        |> Enum.to_list()

      assert normalized_row.canonical_data == %{description: "uber", currency: "BRL"}
    end
  end

  describe "fingerprint and duplicate detection" do
    test "Fingerprint.build/1 is exact-match and stable for normalized canonical data" do
      first =
        Fingerprint.build(%{
          description: "uber",
          amount: Decimal.new("-4.50"),
          currency: "USD",
          posted_on: ~D[2026-03-10]
        })

      second =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-10],
          currency: "USD",
          amount: Decimal.new("-4.50"),
          description: "uber"
        })

      different =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-10],
          currency: "USD",
          amount: Decimal.new("-5.00"),
          description: "uber"
        })

      assert first == second
      refute first == different
    end

    test "list_duplicate_fingerprints/1 is account-scoped" do
      entity = insert(:entity, name: "Duplicate lookup entity")
      other_entity = insert(:entity, name: "Other duplicate lookup entity")
      account = insert(:account, entity: entity, entity_id: entity.id, name: "Duplicate lookup")

      other_account =
        insert(:account, entity: other_entity, entity_id: other_entity.id, name: "Other lookup")

      assert {:ok, imported_file} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "dedupe-source.csv",
                 sha256: String.duplicate("3", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/dedupe-source.csv"
               })

      assert {:ok, other_imported_file} =
               Ingestion.create_imported_file(%{
                 account_id: other_account.id,
                 filename: "dedupe-other.csv",
                 sha256: String.duplicate("4", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/dedupe-other.csv"
               })

      duplicate_fingerprint =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-10],
          amount: Decimal.new("-4.50"),
          currency: "USD",
          description: "coffee"
        })

      other_fingerprint =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-11],
          amount: Decimal.new("-8.00"),
          currency: "USD",
          description: "groceries"
        })

      assert {:ok, _row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: imported_file.id,
                 account_id: account.id,
                 row_index: 0,
                 raw_data: %{"description" => "Coffee"},
                 fingerprint: duplicate_fingerprint,
                 status: :ready
               })

      assert {:ok, _other_row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: other_imported_file.id,
                 account_id: other_account.id,
                 row_index: 0,
                 raw_data: %{"description" => "Coffee"},
                 fingerprint: duplicate_fingerprint,
                 status: :ready
               })

      assert Ingestion.list_duplicate_fingerprints(
               account_id: account.id,
               fingerprints: [duplicate_fingerprint, other_fingerprint]
             ) == MapSet.new([duplicate_fingerprint])
    end

    test "detects overlapping uploads from previous ready rows in the same account" do
      entity = insert(:entity, name: "Overlapping entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Overlapping account")

      assert {:ok, first_import} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "week-1.csv",
                 sha256: String.duplicate("5", 64),
                 format: :csv,
                 status: :complete,
                 storage_path: "/tmp/imports/week-1.csv"
               })

      assert {:ok, second_import} =
               Ingestion.create_imported_file(%{
                 account_id: account.id,
                 filename: "week-2.csv",
                 sha256: String.duplicate("6", 64),
                 format: :csv,
                 status: :pending,
                 storage_path: "/tmp/imports/week-2.csv"
               })

      overlapping_fingerprint =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-10],
          amount: Decimal.new("-4.50"),
          currency: "USD",
          description: "coffee"
        })

      new_fingerprint =
        Fingerprint.build(%{
          posted_on: ~D[2026-03-12],
          amount: Decimal.new("-12.00"),
          currency: "USD",
          description: "fuel"
        })

      assert {:ok, _existing_row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: first_import.id,
                 account_id: account.id,
                 row_index: 0,
                 raw_data: %{"description" => "Coffee"},
                 fingerprint: overlapping_fingerprint,
                 status: :ready
               })

      assert {:ok, _duplicate_row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: second_import.id,
                 account_id: account.id,
                 row_index: 0,
                 raw_data: %{"description" => "Coffee"},
                 fingerprint: overlapping_fingerprint,
                 status: :duplicate,
                 skip_reason: "already imported"
               })

      assert {:ok, _new_row} =
               Ingestion.create_imported_row(%{
                 imported_file_id: second_import.id,
                 account_id: account.id,
                 row_index: 1,
                 raw_data: %{"description" => "Fuel"},
                 fingerprint: new_fingerprint,
                 status: :ready
               })

      assert Ingestion.list_duplicate_fingerprints(
               account_id: account.id,
               fingerprints: [overlapping_fingerprint, new_fingerprint]
             ) == MapSet.new([overlapping_fingerprint, new_fingerprint])
    end
  end

  describe "imported row persistence" do
    test "list_imported_rows/1 requires account scope" do
      assert_raise ArgumentError, "list_imported_rows/1 requires :account_id", fn ->
        Ingestion.list_imported_rows()
      end
    end

    test "creates immutable-style row evidence and lists rows by imported file" do
      entity = insert(:entity, name: "Rows entity")
      account = insert(:account, entity: entity, entity_id: entity.id, name: "Rows account")

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
      entity = insert(:entity, name: "Duplicate row entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Duplicate row account")

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
      entity = insert(:entity, name: "Row coexist entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Row coexist account")

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
