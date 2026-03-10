defmodule AurumFinanceWeb.ImportDetailsLiveTest do
  use AurumFinanceWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.PubSub

  test "shows summary and imported rows for one completed import", %{conn: conn} do
    entity = insert_entity(name: "Import detail entity")
    account = insert_account(entity, %{name: "Import detail account", currency_code: "USD"})

    assert {:ok, imported_file} =
             Ingestion.create_imported_file(%{
               account_id: account.id,
               filename: "detail.csv",
               sha256: String.duplicate("c", 64),
               format: :csv,
               status: :complete,
               row_count: 3,
               imported_row_count: 1,
               skipped_row_count: 1,
               invalid_row_count: 1,
               processed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
               byte_size: 321,
               storage_path: "/tmp/imports/detail.csv"
             })

    assert {:ok, _ready_row} =
             Ingestion.create_imported_row(%{
               imported_file_id: imported_file.id,
               account_id: account.id,
               row_index: 0,
               raw_data: %{"Description" => "Salary"},
               description: "Salary",
               normalized_description: "salary",
               posted_on: ~D[2026-03-01],
               amount: Decimal.new("1000.00"),
               currency: "USD",
               fingerprint: "fp-ready",
               status: :ready
             })

    assert {:ok, _duplicate_row} =
             Ingestion.create_imported_row(%{
               imported_file_id: imported_file.id,
               account_id: account.id,
               row_index: 1,
               raw_data: %{"Description" => "Coffee"},
               description: "Coffee",
               normalized_description: "coffee",
               posted_on: ~D[2026-03-02],
               amount: Decimal.new("-4.50"),
               currency: "USD",
               fingerprint: "fp-duplicate",
               status: :duplicate,
               skip_reason: "already imported"
             })

    assert {:ok, _invalid_row} =
             Ingestion.create_imported_row(%{
               imported_file_id: imported_file.id,
               account_id: account.id,
               row_index: 2,
               raw_data: %{"Description" => ""},
               description: nil,
               normalized_description: nil,
               status: :invalid,
               validation_error: "missing description"
             })

    {:ok, view, _html} =
      conn
      |> log_in_root()
      |> live("/import/accounts/#{account.id}/files/#{imported_file.id}")

    assert has_element?(view, "#import-details-page")
    assert has_element?(view, "#import-rows-table")
    assert render(view) =~ "Import details"
    assert render(view) =~ "detail.csv"
    assert render(view) =~ "Salary"
    assert render(view) =~ "already imported"
    assert render(view) =~ "missing description"
    assert render(view) =~ "Rows read"
  end

  test "refreshes the import details when a PubSub update arrives", %{conn: conn} do
    entity = insert_entity(name: "Realtime detail entity")
    account = insert_account(entity, %{name: "Realtime detail account", currency_code: "USD"})

    assert {:ok, imported_file} =
             Ingestion.create_imported_file(%{
               account_id: account.id,
               filename: "realtime-detail.csv",
               sha256: String.duplicate("d", 64),
               format: :csv,
               status: :processing,
               row_count: 0,
               imported_row_count: 0,
               skipped_row_count: 0,
               invalid_row_count: 0,
               storage_path: "/tmp/imports/realtime-detail.csv"
             })

    {:ok, view, _html} =
      conn
      |> log_in_root()
      |> live("/import/accounts/#{account.id}/files/#{imported_file.id}")

    assert render(view) =~ "Processing"

    assert {:ok, completed_import} =
             Ingestion.update_imported_file(imported_file, %{
               status: :complete,
               row_count: 1,
               imported_row_count: 1,
               processed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
             })

    assert {:ok, _row} =
             Ingestion.create_imported_row(%{
               imported_file_id: imported_file.id,
               account_id: account.id,
               row_index: 0,
               raw_data: %{"Description" => "Dinner"},
               description: "Dinner",
               normalized_description: "dinner",
               posted_on: ~D[2026-03-03],
               amount: Decimal.new("-18.25"),
               currency: "USD",
               fingerprint: "fp-realtime-detail",
               status: :ready
             })

    assert :ok = PubSub.broadcast_imported_file(completed_import)

    assert has_element?(view, "#import-rows-table")
    assert render(view) =~ "Complete"
    assert render(view) =~ "Dinner"
  end

  test "shows error details for a failed import", %{conn: conn} do
    entity = insert_entity(name: "Failed detail entity")
    account = insert_account(entity, %{name: "Failed detail account", currency_code: "USD"})

    assert {:ok, imported_file} =
             Ingestion.create_imported_file(%{
               account_id: account.id,
               filename: "failed-detail.csv",
               sha256: String.duplicate("e", 64),
               format: :csv,
               status: :failed,
               row_count: 0,
               imported_row_count: 0,
               skipped_row_count: 0,
               invalid_row_count: 0,
               error_message: "CSV file is empty",
               processed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
               storage_path: "/tmp/imports/failed-detail.csv"
             })

    {:ok, view, _html} =
      conn
      |> log_in_root()
      |> live("/import/accounts/#{account.id}/files/#{imported_file.id}")

    assert has_element?(view, "#import-details-error")
    assert has_element?(view, "#import-rows-empty")
    assert render(view) =~ "Processing error"
    assert render(view) =~ "CSV file is empty"
  end
end
