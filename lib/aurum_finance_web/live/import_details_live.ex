defmodule AurumFinanceWeb.ImportDetailsLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.UiComponents

  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ingestion.PubSub

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> stream_configure(:imported_rows, dom_id: &"imported-row-#{&1.id}")
      |> assign(
        active_nav: :import,
        page_title: dgettext("import", "details_page_title"),
        imported_file: nil,
        imported_row_count: 0,
        materializable_row_count: 0,
        imported_file_deletable?: false,
        imported_file_delete_block_reason: nil,
        import_materializations: [],
        subscribed_imported_file_id: nil
      )
      |> stream(:imported_rows, [], reset: true)

    {:ok, socket}
  end

  @impl true
  def handle_params(
        %{"account_id" => account_id, "imported_file_id" => imported_file_id},
        _uri,
        socket
      ) do
    {:noreply,
     socket
     |> load_import(account_id, imported_file_id)
     |> maybe_subscribe_imported_file()}
  end

  @impl true
  def handle_info(
        {:import_updated, %{imported_file_id: imported_file_id}},
        %{assigns: %{imported_file: %ImportedFile{id: imported_file_id, account_id: account_id}}} =
          socket
      ) do
    {:noreply, load_import(socket, account_id, imported_file_id)}
  end

  def handle_info(
        {event, %{imported_file_id: imported_file_id}},
        %{assigns: %{imported_file: %ImportedFile{id: imported_file_id, account_id: account_id}}} =
          socket
      )
      when event in [
             :materialization_requested,
             :materialization_processing,
             :materialization_completed,
             :materialization_failed
           ] do
    {:noreply, load_import(socket, account_id, imported_file_id)}
  end

  def handle_info({:import_updated, _payload}, socket), do: {:noreply, socket}
  def handle_info({_event, _payload}, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "request_materialization",
        _params,
        %{assigns: %{imported_file: %ImportedFile{} = imported_file}} = socket
      ) do
    socket =
      imported_file.account_id
      |> Ingestion.request_materialization(imported_file.id, requested_by: "root")
      |> request_materialization_result(socket)

    {:noreply, socket}
  end

  def handle_event(
        "delete_imported_file",
        _params,
        %{assigns: %{imported_file: %ImportedFile{} = imported_file}} = socket
      ) do
    {:noreply, delete_imported_file_result(socket, imported_file)}
  end

  defp load_import(socket, account_id, imported_file_id) do
    imported_file = Ingestion.get_imported_file!(account_id, imported_file_id)

    imported_rows =
      Ingestion.list_imported_rows(account_id: account_id, imported_file_id: imported_file_id)

    materializable_rows =
      Ingestion.list_materializable_imported_rows(
        account_id: account_id,
        imported_file_id: imported_file_id
      )

    import_materializations =
      Ingestion.list_import_materializations(
        account_id: account_id,
        imported_file_id: imported_file_id
      )

    socket
    |> assign(
      imported_file: imported_file,
      imported_row_count: length(imported_rows),
      materializable_row_count: length(materializable_rows),
      imported_file_deletable?: import_materializations == [],
      imported_file_delete_block_reason: delete_block_reason(import_materializations),
      import_materializations: import_materializations,
      page_title: dgettext("import", "details_page_title")
    )
    |> stream(:imported_rows, imported_rows, reset: true)
  end

  defp maybe_subscribe_imported_file(
         %{
           assigns: %{
             imported_file: %ImportedFile{id: imported_file_id},
             subscribed_imported_file_id: imported_file_id
           }
         } = socket
       ),
       do: socket

  defp maybe_subscribe_imported_file(
         %{assigns: %{imported_file: %ImportedFile{id: imported_file_id}}} = socket
       ) do
    socket
    |> maybe_subscribe_imported_file(imported_file_id, connected?(socket))
  end

  defp maybe_subscribe_imported_file(socket, _imported_file_id, false), do: socket

  defp maybe_subscribe_imported_file(socket, imported_file_id, true) do
    :ok = PubSub.subscribe_imported_file(imported_file_id)
    assign(socket, :subscribed_imported_file_id, imported_file_id)
  end

  defp warning_entries(%ImportedFile{warnings: warnings}) when warnings == %{}, do: []

  defp warning_entries(%ImportedFile{warnings: warnings}) when is_map(warnings),
    do: Map.to_list(warnings)

  defp warning_entries(%ImportedFile{}), do: []

  defp import_status_variant(:pending), do: :purple
  defp import_status_variant(:processing), do: :warn
  defp import_status_variant(:complete), do: :good
  defp import_status_variant(:failed), do: :bad
  defp import_status_variant(_), do: :default

  defp import_status_label(:pending), do: dgettext("import", "status_pending")
  defp import_status_label(:processing), do: dgettext("import", "status_processing")
  defp import_status_label(:complete), do: dgettext("import", "status_complete")
  defp import_status_label(:failed), do: dgettext("import", "status_failed")
  defp import_status_label(status), do: to_string(status)

  defp imported_row_status_variant(:ready), do: :good
  defp imported_row_status_variant(:duplicate), do: :warn
  defp imported_row_status_variant(:invalid), do: :bad
  defp imported_row_status_variant(_), do: :default

  defp imported_row_status_label(:ready), do: dgettext("import", "status_ready")
  defp imported_row_status_label(:duplicate), do: dgettext("import", "status_duplicate")
  defp imported_row_status_label(:invalid), do: dgettext("import", "status_invalid")
  defp imported_row_status_label(status), do: to_string(status)

  defp materialization_status_variant(:pending), do: :purple
  defp materialization_status_variant(:processing), do: :warn
  defp materialization_status_variant(:completed), do: :good
  defp materialization_status_variant(:completed_with_errors), do: :warn
  defp materialization_status_variant(:failed), do: :bad
  defp materialization_status_variant(_), do: :default

  defp materialization_status_label(:pending), do: dgettext("import", "status_pending")
  defp materialization_status_label(:processing), do: dgettext("import", "status_processing")
  defp materialization_status_label(:completed), do: dgettext("import", "status_completed")

  defp materialization_status_label(:completed_with_errors),
    do: dgettext("import", "status_completed_with_errors")

  defp materialization_status_label(:failed), do: dgettext("import", "status_failed")
  defp materialization_status_label(status), do: to_string(status)

  defp format_timestamp(nil), do: "—"

  defp format_timestamp(%DateTime{} = timestamp),
    do: Calendar.strftime(timestamp, "%Y-%m-%d %H:%M")

  defp format_date(nil), do: "—"
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)

  defp format_amount(nil), do: "—"

  defp format_amount(%Decimal{} = amount) do
    Decimal.to_string(amount, :normal)
  end

  defp format_byte_size(nil), do: "—"
  defp format_byte_size(byte_size), do: "#{byte_size} B"

  defp row_note(%ImportedRow{status: :duplicate, skip_reason: skip_reason})
       when is_binary(skip_reason),
       do: skip_reason

  defp row_note(%ImportedRow{status: :invalid, validation_error: validation_error})
       when is_binary(validation_error),
       do: validation_error

  defp row_note(%ImportedRow{}), do: "—"

  defp duplicate_visibility_copy(%ImportedRow{status: :duplicate}) do
    dgettext("import", "details_duplicate_visibility_copy")
  end

  defp duplicate_visibility_copy(%ImportedRow{}), do: nil

  defp duplicate_fingerprint(%ImportedRow{status: :duplicate, fingerprint: fingerprint})
       when is_binary(fingerprint),
       do: fingerprint

  defp duplicate_fingerprint(%ImportedRow{}), do: nil

  defp request_materialization_result({:ok, %ImportMaterialization{}}, socket) do
    put_flash(socket, :info, dgettext("import", "flash_materialization_requested"))
  end

  defp request_materialization_result({:error, reason}, socket) do
    put_flash(
      socket,
      :error,
      dgettext("import", "flash_materialization_request_failed", reason: reason)
    )
  end

  defp delete_imported_file_result(socket, %ImportedFile{} = imported_file) do
    case Ingestion.delete_imported_file(imported_file.account_id, imported_file.id) do
      {:ok, _deleted_imported_file} ->
        socket
        |> put_flash(
          :info,
          dgettext("import", "flash_import_deleted", file: imported_file.filename)
        )
        |> push_navigate(to: ~p"/import")

      {:error, reason} ->
        put_flash(
          socket,
          :error,
          dgettext("import", "flash_import_delete_failed", reason: reason)
        )
    end
  end

  defp delete_block_reason([]), do: nil

  defp delete_block_reason([%ImportMaterialization{} | _rest]) do
    dgettext("import", "details_delete_blocked_materialization")
  end
end
