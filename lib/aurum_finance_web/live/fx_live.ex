defmodule AurumFinanceWeb.FxLive do
  @moduledoc """
  LiveView for FX rate series management.

  Supports two views within the same route (`/fx`):

  - **List view** — shows all series in a table with create/edit/delete actions.
  - **Detail view** — shows metadata and last 30 rate records for a single series.

  A right-sidebar panel handles both create and edit forms. The `:view` assign
  toggles between `:list` and `:detail`. Identity fields (currencies, source kind,
  provider module) are read-only when editing.

  ## Assigns

  - `:view` — `:list | :detail`
  - `:series` — list of `%FxSeries{}` (list view)
  - `:selected_series` — currently viewed `%FxSeries{}` (detail view)
  - `:rate_records` — list of `%FxRateRecord{}` for the detail view
  - `:form_mode` — `:none | :create | :edit`
  - `:editing_series` — `%FxSeries{}` being edited, or `nil`
  - `:form` — the current Phoenix form
  - `:saving` — boolean, true while save is in progress
  - `:pending_delete` — `%FxSeries{}` awaiting delete confirmation, or `nil`
  """

  use AurumFinanceWeb, :live_view

  alias AurumFinance.Fx
  alias AurumFinance.Fx.CsvImport
  alias AurumFinance.Fx.FxSeries

  require Logger

  @rate_page_size 30

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        active_nav: :fx,
        page_title: dgettext("fx", "page_title"),
        breadcrumbs: fx_list_breadcrumbs(),
        view: :list,
        series: [],
        selected_series: nil,
        sync_status: %{state: :not_applicable},
        rate_records: [],
        rate_total_count: 0,
        rate_total_pages: 1,
        rate_page: 1,
        form_mode: :none,
        editing_series: nil,
        saving: false,
        pending_delete: nil
      )
      |> allow_upload(:csv, accept: ~w(.csv), max_entries: 1, max_file_size: 1_048_576)
      |> assign_rate_filter_form(default_rate_filter_params())
      |> assign_blank_form()
      |> load_series()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    {:noreply, load_detail_from_slug(socket, slug)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply,
     socket
     |> close_form()
     |> assign(:view, :list)
     |> assign(:selected_series, nil)
     |> assign(:sync_status, %{state: :not_applicable})
     |> assign(:rate_records, [])
     |> assign(:rate_total_count, 0)
     |> assign(:rate_total_pages, 1)
     |> assign(:rate_page, 1)
     |> assign(:breadcrumbs, fx_list_breadcrumbs())
     |> assign_rate_filter_form(default_rate_filter_params())
     |> load_series()}
  end

  @impl true
  def handle_event("back_to_list", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/fx")}
  end

  def handle_event("filter_rate_records", %{"rate_filter" => params}, socket) do
    params = normalize_rate_filter_params(params)

    {:noreply,
     socket
     |> assign(:rate_page, 1)
     |> assign_rate_filter_form(params)
     |> reload_rate_records()}
  end

  def handle_event("change_rate_page", %{"page" => page}, socket) do
    page = normalize_positive_integer(page, socket.assigns.rate_page)

    {:noreply,
     socket
     |> assign(:rate_page, page)
     |> reload_rate_records()}
  end

  def handle_event(
        "import_csv",
        _params,
        %{assigns: %{selected_series: %FxSeries{source_kind: :csv_upload} = series}} = socket
      ) do
    case consume_csv_upload(socket, series) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  def handle_event("import_csv", _params, socket) do
    {:noreply, put_flash(socket, :error, dgettext("fx", "flash_sync_not_supported"))}
  end

  def handle_event("validate_csv_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("sync_now", %{"id" => id}, socket) do
    case find_series_or_fetch(socket, id) do
      %FxSeries{} = series ->
        socket =
          case Fx.enqueue_fx_sync(series) do
            {:ok, _job} ->
              socket
              |> put_flash(:info, dgettext("fx", "flash_sync_enqueued"))
              |> load_series()
              |> load_series_detail(series)

            {:error, :already_up_to_date} ->
              socket
              |> put_flash(:info, dgettext("fx", "flash_sync_already_up_to_date"))
              |> load_series()
              |> load_series_detail(series)

            {:error, :not_a_provider_series} ->
              put_flash(socket, :error, dgettext("fx", "flash_sync_not_supported"))

            {:error, _reason} ->
              socket
              |> put_flash(:error, dgettext("fx", "flash_sync_enqueue_failed"))
              |> load_series()
              |> load_series_detail(series)
          end

        {:noreply, socket}

      nil ->
        {:noreply, put_flash(socket, :error, dgettext("fx", "flash_save_failed"))}
    end
  end

  def handle_event("refresh_sync_status", %{"id" => id}, socket) do
    case find_series_or_fetch(socket, id) do
      %FxSeries{} = series -> {:noreply, load_series_detail(socket, series)}
      nil -> {:noreply, put_flash(socket, :error, dgettext("fx", "flash_save_failed"))}
    end
  end

  def handle_event("new_series", _params, socket) do
    {:noreply,
     socket
     |> assign(:form_mode, :create)
     |> assign(:editing_series, nil)
     |> assign_blank_form()}
  end

  def handle_event("edit_series", %{"id" => id}, socket) do
    case find_series_or_fetch(socket, id) do
      %FxSeries{} = series ->
        {:noreply,
         socket
         |> assign(:form_mode, :edit)
         |> assign(:editing_series, series)
         |> assign_edit_form(series)}

      nil ->
        {:noreply, put_flash(socket, :error, dgettext("fx", "flash_save_failed"))}
    end
  end

  def handle_event("close_form", _params, socket) do
    {:noreply, close_form(socket)}
  end

  def handle_event("validate", %{"fx_series" => params}, socket) do
    changeset =
      case socket.assigns.form_mode do
        :create ->
          %FxSeries{}
          |> Fx.change_fx_series(params)
          |> Map.put(:action, :validate)

        :edit ->
          socket.assigns.editing_series
          |> Fx.change_fx_series(params)
          |> Map.put(:action, :validate)

        :none ->
          Fx.change_fx_series(%FxSeries{})
      end

    {:noreply, assign(socket, :form, to_form(changeset, as: :fx_series))}
  end

  def handle_event("save", %{"fx_series" => params}, socket) do
    socket = assign(socket, :saving, true)

    result =
      case socket.assigns.form_mode do
        :create -> Fx.create_fx_series(params)
        :edit -> Fx.update_fx_series(socket.assigns.editing_series, params)
        :none -> {:error, :no_form_mode}
      end

    {:noreply, handle_save_result(socket, result)}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    case find_series_or_fetch(socket, id) do
      %FxSeries{} = series -> {:noreply, assign(socket, :pending_delete, series)}
      nil -> {:noreply, put_flash(socket, :error, dgettext("fx", "flash_save_failed"))}
    end
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :pending_delete, nil)}
  end

  def handle_event("do_delete", _params, socket) do
    case Fx.delete_fx_series(socket.assigns.pending_delete) do
      {:ok, _series} ->
        {:noreply,
         socket
         |> assign(:pending_delete, nil)
         |> put_flash(:info, dgettext("fx", "flash_series_deleted"))
         |> load_series()}

      {:error, :has_records} ->
        {:noreply,
         socket
         |> assign(:pending_delete, nil)
         |> put_flash(:error, dgettext("fx", "flash_delete_blocked_has_records"))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:pending_delete, nil)
         |> put_flash(:error, dgettext("fx", "flash_delete_failed"))}
    end
  end

  defp load_series(socket) do
    assign(socket, :series, Fx.list_fx_series())
  end

  defp load_series_detail(socket, %FxSeries{} = series) do
    filter_opts = rate_filter_opts(socket.assigns.rate_filter_form.source)
    page = socket.assigns.rate_page

    page_result =
      Fx.paginate_fx_rate_records(
        series,
        filter_opts ++ [page: page, page_size: @rate_page_size]
      )

    assign(socket,
      selected_series: series,
      rate_records: page_result.entries,
      rate_total_count: page_result.total_entries,
      rate_total_pages: page_result.total_pages,
      rate_page: page_result.page_number,
      sync_status: Fx.latest_sync_status(series)
    )
  end

  defp close_form(socket) do
    socket
    |> assign(:form_mode, :none)
    |> assign(:editing_series, nil)
    |> assign(:saving, false)
    |> assign_blank_form()
  end

  defp assign_blank_form(socket) do
    changeset = Fx.change_fx_series(%FxSeries{})
    assign(socket, :form, to_form(changeset, as: :fx_series))
  end

  defp assign_edit_form(socket, %FxSeries{} = series) do
    changeset = Fx.change_fx_series(series, %{})
    assign(socket, :form, to_form(changeset, as: :fx_series))
  end

  defp handle_save_result(socket, {:ok, _series}) do
    message =
      if socket.assigns.form_mode == :create,
        do: dgettext("fx", "flash_series_created"),
        else: dgettext("fx", "flash_series_updated")

    socket
    |> put_flash(:info, message)
    |> close_form()
    |> load_series()
  end

  defp handle_save_result(socket, {:error, %Ecto.Changeset{} = changeset}) do
    socket
    |> assign(:saving, false)
    |> assign(:form, to_form(changeset, as: :fx_series))
  end

  defp handle_save_result(socket, {:error, _reason}) do
    socket
    |> assign(:saving, false)
    |> put_flash(:error, dgettext("fx", "flash_save_failed"))
  end

  defp find_series_or_fetch(socket, id) do
    Enum.find(socket.assigns.series, &(&1.id == id)) || Fx.get_fx_series(id)
  end

  defp load_detail_from_slug(socket, slug) do
    case Fx.get_fx_series_by_slug(slug) do
      %FxSeries{} = series ->
        socket
        |> close_form()
        |> assign(:rate_page, 1)
        |> assign(:breadcrumbs, fx_detail_breadcrumbs(series))
        |> assign_rate_filter_form(default_rate_filter_params())
        |> assign(:view, :detail)
        |> load_series()
        |> load_series_detail(series)

      nil ->
        socket
        |> put_flash(:error, dgettext("fx", "flash_save_failed"))
        |> push_patch(to: ~p"/fx")
    end
  end

  defp source_kind_label(:csv_upload), do: dgettext("fx", "source_kind_csv_upload")
  defp source_kind_label(:provider_module), do: dgettext("fx", "source_kind_provider_module")
  defp source_kind_label(_), do: "-"

  defp series_status_status(%FxSeries{source_kind: :csv_upload}), do: :not_applicable
  defp series_status_status(%FxSeries{sync_status: :error}), do: :sync_failed
  defp series_status_status(%FxSeries{sync_status: status}), do: status
  defp series_status_status(_), do: :not_applicable

  defp sync_badge_status(:error), do: :sync_failed
  defp sync_badge_status(:failed), do: :sync_failed
  defp sync_badge_status(status), do: status

  defp sync_status_comment(%{state: :never_run}), do: dgettext("fx", "sync_comment_never_run")

  defp sync_status_comment(%{state: :active, error: nil}),
    do: dgettext("fx", "sync_comment_active")

  defp sync_status_comment(%{state: :stopped}), do: dgettext("fx", "sync_comment_stopped")

  defp sync_status_comment(%{state: :error, error: error}) when is_binary(error),
    do: dgettext("fx", "sync_comment_failed", error: error)

  defp sync_status_comment(%{state: :queued, from_date: from_date, to_date: to_date}) do
    dgettext("fx", "sync_comment_queued",
      from_date: format_date(from_date),
      to_date: format_date(to_date)
    )
  end

  defp sync_status_comment(%{state: :running, from_date: from_date, to_date: to_date}) do
    dgettext("fx", "sync_comment_running",
      from_date: format_date(from_date),
      to_date: format_date(to_date)
    )
  end

  defp sync_status_comment(%{state: :ok, finished_at: finished_at}) do
    dgettext("fx", "sync_comment_ok", timestamp: format_datetime(finished_at))
  end

  defp sync_status_comment(%{state: :retrying, error: error}) when is_binary(error) do
    dgettext("fx", "sync_comment_retrying", error: error)
  end

  defp sync_status_comment(%{state: :retrying}) do
    dgettext("fx", "sync_comment_retrying_generic")
  end

  defp sync_status_comment(%{state: :failed, error: error}) when is_binary(error) do
    dgettext("fx", "sync_comment_failed", error: error)
  end

  defp sync_status_comment(%{state: :failed}) do
    dgettext("fx", "sync_comment_failed_generic")
  end

  defp sync_status_comment(%{state: :cancelled}) do
    dgettext("fx", "sync_comment_cancelled")
  end

  defp sync_status_comment(%{state: :not_applicable}) do
    dgettext("fx", "sync_comment_not_applicable")
  end

  defp sync_status_comment(_) do
    dgettext("fx", "sync_comment_unknown")
  end

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)
  defp format_day_date(nil), do: "-"

  defp format_day_date(%Date{} = date) do
    weekday = Calendar.strftime(date, "%a")
    "#{Date.to_iso8601(date)} (#{weekday})"
  end

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = datetime),
    do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")

  defp format_rate(%Decimal{} = d), do: Decimal.to_string(d)
  defp format_rate(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 6)
  defp format_rate(nil), do: "-"

  defp previous_rate_value(records, idx) when is_list(records) and is_integer(idx) do
    records
    |> Enum.at(idx + 1)
    |> then(fn
      %{rate_value: rate_value} -> rate_value
      _ -> nil
    end)
  end

  defp previous_rate_value(_records, _idx), do: nil

  defp format_rate_variation(%Decimal{} = current_rate, %Decimal{} = previous_rate) do
    if Decimal.equal?(previous_rate, Decimal.new(0)) do
      "-"
    else
      percentage =
        current_rate
        |> Decimal.sub(previous_rate)
        |> Decimal.div(previous_rate)
        |> Decimal.mult(Decimal.new(100))
        |> Decimal.round(2)

      "#{signed_percentage(percentage)}%"
    end
  end

  defp format_rate_variation(current_rate, previous_rate)
       when is_float(current_rate) and is_float(previous_rate) and previous_rate != 0.0 do
    percentage = Float.round((current_rate - previous_rate) / previous_rate * 100, 2)
    "#{signed_percentage(percentage)}%"
  end

  defp format_rate_variation(_current_rate, _previous_rate), do: "-"

  defp signed_percentage(%Decimal{} = percentage) do
    case Decimal.compare(percentage, Decimal.new(0)) do
      :gt -> "+" <> Decimal.to_string(percentage, :normal)
      _ -> Decimal.to_string(percentage, :normal)
    end
  end

  defp signed_percentage(percentage) when is_float(percentage) do
    if percentage > 0 do
      "+" <> :erlang.float_to_binary(percentage, decimals: 2)
    else
      :erlang.float_to_binary(percentage, decimals: 2)
    end
  end

  defp format_inverse_rate(%Decimal{} = d) do
    if Decimal.equal?(d, Decimal.new(0)) do
      "-"
    else
      Decimal.div(Decimal.new(1), d)
      |> Decimal.round(4)
      |> Decimal.to_string(:normal)
    end
  end

  defp format_inverse_rate(v) when is_float(v) and v != 0.0 do
    :erlang.float_to_binary(1 / v, decimals: 4)
  end

  defp format_inverse_rate(_), do: "-"

  # Returns the current source_kind value from the form as a string,
  # used to conditionally show the provider_module select.
  defp form_source_kind(form) do
    case form[:source_kind].value do
      value when is_atom(value) -> Atom.to_string(value)
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp form_provider_module(form) do
    case form[:provider_module].value do
      value when is_binary(value) -> value
      _ -> nil
    end
  end

  defp currency_options(form, field) when field in [:base, :quote] do
    source_kind = form_source_kind(form)
    provider_module = form_provider_module(form)

    case {source_kind, provider_module, field} do
      {"provider_module", selected_provider, :base} ->
        FxSeries.base_currency_options(selected_provider)

      {"provider_module", selected_provider, :quote} ->
        FxSeries.quote_currency_options(selected_provider)

      _ ->
        FxSeries.common_currency_options()
    end
  end

  defp assign_rate_filter_form(socket, params) do
    assign(socket, :rate_filter_form, to_form(params, as: :rate_filter))
  end

  defp default_rate_filter_params do
    %{"date" => ""}
  end

  defp normalize_rate_filter_params(params) do
    %{"date" => Map.get(params, "date", "")}
  end

  defp reload_rate_records(%{assigns: %{selected_series: nil}} = socket), do: socket

  defp reload_rate_records(socket) do
    load_series_detail(socket, socket.assigns.selected_series)
  end

  defp consume_csv_upload(socket, %FxSeries{} = series) do
    results =
      consume_uploaded_entries(socket, :csv, fn %{path: path}, _entry ->
        with {:ok, content} <- File.read(path),
             {:ok, rows} <- CsvImport.parse(content),
             {:ok, result} <- CsvImport.import(series, rows) do
          {:ok, {:ok, result}}
        else
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    handle_csv_upload_result(socket, series, results)
  end

  defp handle_csv_upload_result(socket, _series, []) do
    {completed_entries, in_progress_entries} = uploaded_entries(socket, :csv)
    upload_error = csv_upload_error(socket.assigns.uploads.csv)

    reason =
      cond do
        upload_error ->
          "upload_error: #{upload_error}"

        in_progress_entries != [] ->
          "upload_in_progress"

        completed_entries == [] ->
          "no_file_selected"

        true ->
          "unknown_upload_state"
      end

    Logger.debug("FX CSV import failed before consumption", reason: reason)

    {:error, put_flash(socket, :error, "#{dgettext("fx", "flash_save_failed")} (#{reason})")}
  end

  defp handle_csv_upload_result(socket, series, [
         {:ok, %{inserted: inserted, updated: updated}} | _
       ]) do
    case Fx.get_fx_series(series.id) do
      %FxSeries{} = refreshed_series ->
        {:ok,
         socket
         |> put_flash(:info, "CSV imported. Inserted: #{inserted}. Updated: #{updated}.")
         |> assign(:rate_page, 1)
         |> load_series()
         |> load_series_detail(refreshed_series)}

      nil ->
        {:error,
         socket
         |> put_flash(:error, dgettext("fx", "flash_save_failed"))
         |> push_patch(to: ~p"/fx")}
    end
  end

  defp handle_csv_upload_result(socket, _series, [{:error, reason} | _]) do
    {:error,
     put_flash(
       socket,
       :error,
       "#{dgettext("fx", "flash_save_failed")} (#{format_csv_import_error(reason)})"
     )}
  end

  defp format_csv_import_error(:empty_file), do: "empty_file"
  defp format_csv_import_error(:no_data_rows), do: "no_data_rows"
  defp format_csv_import_error(:malformed_csv), do: "malformed_csv"
  defp format_csv_import_error({:invalid_rows, _rows}), do: "invalid_rows"
  defp format_csv_import_error({:duplicate_dates_in_file, _dates}), do: "duplicate_dates_in_file"
  defp format_csv_import_error(:not_a_csv_series), do: "not_a_csv_series"
  defp format_csv_import_error(reason), do: inspect(reason)

  defp csv_upload_error(upload) do
    upload
    |> upload_errors()
    |> List.first()
    |> csv_upload_error_message()
  end

  defp csv_upload_error_message(:too_large), do: "File too large."
  defp csv_upload_error_message(:too_many_files), do: "Only one file is allowed."
  defp csv_upload_error_message(:not_accepted), do: "Only .csv files are accepted."
  defp csv_upload_error_message(nil), do: nil
  defp csv_upload_error_message(_error), do: "Upload validation failed."

  defp rate_filter_opts(params) when is_map(params) do
    case parse_filter_date(Map.get(params, "date")) do
      %Date{} = selected_date ->
        from_date = Date.add(selected_date, -2)
        to_date = Date.add(selected_date, 2)

        [from_date: from_date, to_date: to_date]

      _ ->
        []
    end
  end

  defp rate_filter_opts(_), do: []

  defp parse_filter_date(nil), do: nil
  defp parse_filter_date(""), do: nil

  defp parse_filter_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp normalize_positive_integer(value, _fallback) when is_integer(value) and value > 0,
    do: value

  defp normalize_positive_integer(value, fallback)
       when is_binary(value) and is_integer(fallback) and fallback > 0 do
    case Integer.parse(value) do
      {parsed_value, ""} when parsed_value > 0 -> parsed_value
      _ -> fallback
    end
  end

  defp normalize_positive_integer(_value, _fallback), do: 1

  defp fx_list_breadcrumbs do
    [%{label: dgettext("fx", "page_title"), path: nil}]
  end

  defp fx_detail_breadcrumbs(%FxSeries{name: name}) do
    [
      %{label: dgettext("fx", "page_title"), path: ~p"/fx"},
      %{label: name, path: nil}
    ]
  end
end
