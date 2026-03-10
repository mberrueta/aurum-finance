defmodule AurumFinanceWeb.ImportLiveTest do
  use AurumFinanceWeb.ConnCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  import Phoenix.LiveViewTest

  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.ImportWorker
  alias AurumFinance.Ingestion.PubSub

  test "requires selecting an account before queueing an upload", %{conn: conn} do
    entity = insert_entity(name: "Upload entity")
    account = insert_account(entity, %{name: "Upload checking", currency_code: "USD"})

    {:ok, view, _html} = conn |> log_in_root() |> live("/import")

    assert has_element?(view, "#import-upload-placeholder")
    refute has_element?(view, "#import-upload-panel-wrapper")

    view
    |> form("#import-entity-selector", entity_scope: %{entity_id: entity.id})
    |> render_change()

    assert has_element?(view, "#import-upload-placeholder")
    refute has_element?(view, "#import-upload-panel-wrapper")
    assert Ingestion.list_imported_files(account_id: account.id) == []
    refute_enqueued(worker: ImportWorker)
  end

  test "renders import expectations guidance", %{conn: conn} do
    {:ok, view, _html} = conn |> log_in_root() |> live("/import")

    assert has_element?(view, "#import-guidance")
    assert has_element?(view, "#import-tips")
    assert render(view) =~ "Expected format"
    assert render(view) =~ "Format checks"
    assert render(view) =~ "Tips"
  end

  test "filters accounts by entity and queues a pending import for the selected account", %{
    conn: conn
  } do
    entity = insert_entity(name: "Alpha entity")
    other_entity = insert_entity(name: "Zulu entity")
    account = insert_account(entity, %{name: "Alpha checking", currency_code: "USD"})
    _other_account = insert_account(other_entity, %{name: "Zulu checking", currency_code: "EUR"})

    {:ok, view, _html} = conn |> log_in_root() |> live("/import")

    view
    |> form("#import-entity-selector", entity_scope: %{entity_id: entity.id})
    |> render_change()

    assert render(view) =~ "Alpha checking"
    refute render(view) =~ "Zulu checking"

    view
    |> form("#import-account-selector", account_scope: %{account_id: account.id})
    |> render_change()

    refute has_element?(view, "#import-upload-placeholder")
    assert has_element?(view, "#import-upload-panel-wrapper")
    assert has_element?(view, "#import-submit-btn[disabled]")

    upload =
      file_input(view, "#import-upload-form", :source_file, [
        %{
          last_modified: 1_710_000_000_001,
          name: "statement.csv",
          content: "Date,Description,Amount,Currency\n2026-03-10,Coffee,-4.50,USD\n",
          type: "text/csv"
        }
      ])

    assert render_upload(upload, "statement.csv") =~ "statement.csv"
    assert has_element?(view, "#import-upload-selected")
    assert has_element?(view, "#import-submit-btn")
    refute has_element?(view, "#import-submit-btn[disabled]")
    assert render(view) =~ "Selected file"
    assert render(view) =~ "statement.csv"

    view
    |> form("#import-upload-form")
    |> render_submit()

    [imported_file] = Ingestion.list_imported_files(account_id: account.id)

    assert imported_file.status == :pending

    assert_enqueued(
      worker: ImportWorker,
      queue: :imports,
      args: %{"account_id" => account.id, "imported_file_id" => imported_file.id}
    )

    assert has_element?(view, "#imported-file-#{imported_file.id}[data-status='pending']")

    assert has_element?(
             view,
             "#view-import-#{imported_file.id}[href='/import/accounts/#{account.id}/files/#{imported_file.id}']"
           )
  end

  test "refreshes the selected account history when PubSub broadcasts import updates", %{
    conn: conn
  } do
    entity = insert_entity(name: "Realtime entity")
    account = insert_account(entity, %{name: "Realtime checking", currency_code: "USD"})

    assert {:ok, imported_file} =
             Ingestion.create_imported_file(%{
               account_id: account.id,
               filename: "realtime.csv",
               sha256: String.duplicate("a", 64),
               format: :csv,
               status: :pending,
               storage_path: "/tmp/imports/realtime.csv"
             })

    {:ok, view, _html} = conn |> log_in_root() |> live("/import")

    view
    |> form("#import-entity-selector", entity_scope: %{entity_id: entity.id})
    |> render_change()

    view
    |> form("#import-account-selector", account_scope: %{account_id: account.id})
    |> render_change()

    assert has_element?(view, "#imported-file-#{imported_file.id}[data-status='pending']")

    assert {:ok, processing_import} =
             Ingestion.update_imported_file(imported_file, %{status: :processing})

    assert :ok = PubSub.broadcast_imported_file(processing_import)

    assert has_element?(view, "#imported-file-#{imported_file.id}[data-status='processing']")
  end
end
