defmodule AurumFinanceWeb.ImportLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.ImportComponents

  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.PubSub
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account

  @impl true
  def mount(_params, _session, socket) do
    entities = Entities.list_entities()
    current_entity = List.first(entities)
    accounts = load_accounts(current_entity)

    socket =
      socket
      |> allow_upload(:source_file, accept: ~w(.csv), max_entries: 1)
      |> stream_configure(:imports, dom_id: &"imported-file-#{&1.id}")
      |> assign(
        active_nav: :import,
        page_title: dgettext("import", "page_title"),
        entities: entities,
        current_entity: current_entity,
        accounts: accounts,
        current_account: nil,
        subscribed_account_ids: MapSet.new(),
        import_count: 0
      )
      |> assign_scope_forms()
      |> stream(:imports, [], reset: true)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_entity", %{"entity_scope" => %{"entity_id" => entity_id}}, socket) do
    current_entity = find_entity(socket.assigns.entities, entity_id)
    accounts = load_accounts(current_entity)

    {:noreply,
     socket
     |> assign(
       current_entity: current_entity,
       accounts: accounts,
       current_account: nil
     )
     |> assign_scope_forms()
     |> assign(:import_count, 0)
     |> stream(:imports, [], reset: true)}
  end

  def handle_event("select_account", %{"account_scope" => %{"account_id" => account_id}}, socket) do
    current_account = find_account(socket.assigns.accounts, account_id)

    {:noreply,
     socket
     |> assign(current_account: current_account)
     |> subscribe_account_imports()
     |> assign_scope_forms()
     |> load_imports()}
  end

  def handle_event("upload", _params, %{assigns: %{current_account: nil}} = socket) do
    {:noreply, put_flash(socket, :error, dgettext("import", "flash_account_required"))}
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("upload", _params, socket) do
    socket
    |> consume_source_file()
    |> handle_upload_result(socket)
  end

  @impl true
  def handle_info(
        {:import_updated, %{account_id: account_id}},
        %{assigns: %{current_account: %Account{id: account_id}}} = socket
      ) do
    {:noreply, load_imports(socket)}
  end

  def handle_info({:import_updated, _payload}, socket), do: {:noreply, socket}

  defp assign_scope_forms(socket) do
    socket
    |> assign(
      :entity_form,
      to_form(
        %{"entity_id" => socket.assigns.current_entity && socket.assigns.current_entity.id},
        as: :entity_scope
      )
    )
    |> assign(
      :account_form,
      to_form(
        %{"account_id" => socket.assigns.current_account && socket.assigns.current_account.id},
        as: :account_scope
      )
    )
  end

  defp load_accounts(nil), do: []

  defp load_accounts(%Entity{id: entity_id}) do
    Ledger.list_institution_accounts(entity_id: entity_id)
  end

  defp load_imports(%{assigns: %{current_account: nil}} = socket) do
    socket
    |> assign(:import_count, 0)
    |> stream(:imports, [], reset: true)
  end

  defp load_imports(%{assigns: %{current_account: %Account{id: account_id}}} = socket) do
    imports = Ingestion.list_imported_files(account_id: account_id)

    socket
    |> assign(:import_count, length(imports))
    |> stream(:imports, imports, reset: true)
  end

  defp subscribe_account_imports(%{assigns: %{current_account: nil}} = socket), do: socket

  defp subscribe_account_imports(
         %{assigns: %{current_account: %Account{id: account_id}}} = socket
       ) do
    socket
    |> maybe_subscribe_account_imports(account_id, connected?(socket))
  end

  defp maybe_subscribe_account_imports(socket, _account_id, false), do: socket

  defp maybe_subscribe_account_imports(
         %{assigns: %{subscribed_account_ids: subscribed_account_ids}} = socket,
         account_id,
         true
       ) do
    socket
    |> maybe_broadcast_subscription(
      account_id,
      MapSet.member?(subscribed_account_ids, account_id)
    )
  end

  defp maybe_broadcast_subscription(socket, _account_id, true), do: socket

  defp maybe_broadcast_subscription(socket, account_id, false) do
    :ok = PubSub.subscribe_account_imports(account_id)
    update(socket, :subscribed_account_ids, &MapSet.put(&1, account_id))
  end

  defp consume_source_file(%{assigns: %{current_account: current_account}} = socket) do
    consume_uploaded_entries(socket, :source_file, fn %{path: path}, entry ->
      path
      |> File.read()
      |> store_uploaded_entry(current_account, entry)
    end)
  end

  defp store_uploaded_entry({:ok, content}, current_account, entry) do
    current_account
    |> build_upload_attrs(content, entry)
    |> Ingestion.store_imported_file()
    |> enqueue_import()
    |> wrap_upload_result()
  end

  defp store_uploaded_entry({:error, reason}, _current_account, _entry),
    do: {:ok, {:error, reason}}

  defp build_upload_attrs(%Account{id: account_id}, content, entry) do
    %{
      account_id: account_id,
      filename: entry.client_name,
      content: content,
      content_type: entry.client_type
    }
  end

  defp enqueue_import({:ok, imported_file}) do
    imported_file
    |> Ingestion.enqueue_import_processing()
    |> normalize_enqueued_import(imported_file)
  end

  defp enqueue_import({:error, reason}), do: {:error, reason}

  defp normalize_enqueued_import({:ok, _job}, imported_file), do: {:ok, imported_file}
  defp normalize_enqueued_import({:error, reason}, _imported_file), do: {:error, reason}

  defp wrap_upload_result({:ok, imported_file}), do: {:ok, {:ok, imported_file}}
  defp wrap_upload_result({:error, reason}), do: {:ok, {:error, reason}}

  defp handle_upload_result([], socket) do
    {:noreply, put_flash(socket, :error, dgettext("import", "flash_file_required"))}
  end

  defp handle_upload_result([{:ok, imported_file}], socket) do
    {:noreply,
     socket
     |> put_flash(
       :info,
       dgettext("import", "flash_import_enqueued", file: imported_file.filename)
     )
     |> load_imports()}
  end

  defp handle_upload_result([{:error, reason}], socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       dgettext("import", "flash_import_failed", reason: format_upload_error(reason))
     )}
  end

  defp history_copy(nil, accounts) when accounts == [],
    do: dgettext("import", "history_copy_no_accounts")

  defp history_copy(nil, _accounts), do: dgettext("import", "history_copy_select_account")

  defp history_copy(%Account{} = current_account, _accounts) do
    dgettext("import", "history_copy_selected", account: current_account.name)
  end

  defp upload_error(upload) do
    upload
    |> upload_errors()
    |> List.first()
    |> upload_error_message()
  end

  defp upload_error_message(:too_large), do: dgettext("import", "upload_error_too_large")

  defp upload_error_message(:too_many_files),
    do: dgettext("import", "upload_error_too_many_files")

  defp upload_error_message(:not_accepted), do: dgettext("import", "upload_error_not_accepted")
  defp upload_error_message(nil), do: nil
  defp upload_error_message(_error), do: dgettext("import", "upload_error_generic")

  defp format_upload_error(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_upload_error(reason) when is_binary(reason), do: reason
  defp format_upload_error(reason), do: inspect(reason)

  defp selected_upload_name([]), do: nil
  defp selected_upload_name([entry | _rest]), do: entry.client_name

  defp selected_upload_format([]), do: nil

  defp selected_upload_format([entry | _rest]) do
    entry.client_name
    |> Path.extname()
    |> String.trim_leading(".")
    |> String.upcase()
    |> blank_to_nil()
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp find_entity(entities, entity_id), do: Enum.find(entities, &(&1.id == entity_id))
  defp find_account(accounts, account_id), do: Enum.find(accounts, &(&1.id == account_id))
end
