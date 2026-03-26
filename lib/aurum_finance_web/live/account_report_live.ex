defmodule AurumFinanceWeb.AccountReportLive do
  @moduledoc """
  Saved account report editor with live preview.
  """

  use AurumFinanceWeb, :live_view

  alias AurumFinance.Entities
  alias AurumFinance.Fx
  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.SavedAccountReport

  @impl true
  def mount(_params, _session, socket) do
    entities = Entities.list_entities()
    accounts = list_accounts(entities)
    accounts_by_id = Map.new(accounts, &{&1.id, &1})
    blank_report = %SavedAccountReport{}

    socket =
      socket
      |> assign(
        active_nav: :reports,
        page_title: dgettext("reports", "saved_account_report_page_title"),
        breadcrumbs: saved_account_report_breadcrumbs(nil),
        entities: entities,
        accounts: accounts,
        accounts_by_id: accounts_by_id,
        account_options: account_options(accounts, entities),
        currency_options: currency_options(),
        compatible_series: [],
        current_account: nil,
        saved_account_report: blank_report,
        preview: nil,
        convert_enabled?: false,
        saving?: false
      )
      |> assign(:form, to_form(report_changeset(blank_report, %{}), as: :saved_account_report))

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Reporting.get_saved_account_report(id) do
      %SavedAccountReport{} = saved_account_report ->
        {:noreply, load_saved_account_report(socket, saved_account_report)}

      nil ->
        {:noreply,
         socket
         |> put_flash(:error, dgettext("reports", "saved_account_report_not_found"))
         |> push_navigate(to: ~p"/reports")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, load_saved_account_report(socket, %SavedAccountReport{})}
  end

  @impl true
  def handle_event("validate", %{"saved_account_report" => params}, socket) do
    changeset = report_changeset(socket.assigns.saved_account_report, params)

    {:noreply,
     socket
     |> assign_report_form_state(changeset, true)
     |> assign_preview(preview_from_changeset(changeset))}
  end

  def handle_event("save", %{"saved_account_report" => params}, socket) do
    saved_account_report = socket.assigns.saved_account_report
    changeset = report_changeset(saved_account_report, params)
    creating? = is_nil(saved_account_report.id)

    case persist_saved_account_report(saved_account_report, params) do
      {:ok, saved_account_report} ->
        preview = preview_for_saved_account_report(saved_account_report)
        message = save_success_message(creating?)

        socket =
          socket
          |> put_flash(:info, message)
          |> assign(:saved_account_report, saved_account_report)
          |> assign_report_form_state(report_changeset(saved_account_report, %{}))
          |> assign_preview(preview)

        if creating? do
          {:noreply,
           push_navigate(socket, to: ~p"/reports/account-reports/#{saved_account_report.id}")}
        else
          {:noreply, socket}
        end

      {:error, %Ecto.Changeset{} = error_changeset} ->
        {:noreply,
         socket
         |> assign_report_form_state(error_changeset, true)
         |> assign_preview(preview_from_changeset(changeset))}
    end
  end

  def handle_event("delete", _params, socket) do
    case Reporting.delete_saved_account_report(socket.assigns.saved_account_report) do
      {:ok, _saved_account_report} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("reports", "saved_account_report_deleted"))
         |> push_navigate(to: ~p"/reports")}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, dgettext("reports", "saved_account_report_delete_failed"))}
    end
  end

  defp load_saved_account_report(socket, %SavedAccountReport{} = saved_account_report) do
    changeset = report_changeset(saved_account_report, %{})

    preview =
      case saved_account_report.id do
        nil -> nil
        _ -> preview_for_saved_account_report(saved_account_report)
      end

    socket
    |> assign(
      page_title: dgettext("reports", "saved_account_report_page_title"),
      breadcrumbs: saved_account_report_breadcrumbs(saved_account_report),
      saved_account_report: saved_account_report
    )
    |> assign_report_form_state(changeset)
    |> assign_preview(preview)
  end

  defp assign_report_form_state(socket, changeset, show_errors \\ false) do
    form_changeset = if(show_errors, do: Map.put(changeset, :action, :validate), else: changeset)
    account = selected_account(changeset, socket.assigns.accounts_by_id)
    compatible_series = compatible_fx_series(changeset, account)

    socket
    |> assign(:form, to_form(form_changeset, as: :saved_account_report))
    |> assign(:current_account, account)
    |> assign(:convert_enabled?, Ecto.Changeset.get_field(changeset, :convert) == true)
    |> assign(:compatible_series, compatible_series)
  end

  defp assign_preview(socket, nil), do: assign(socket, :preview, nil)

  defp assign_preview(socket, preview), do: assign(socket, :preview, preview)

  defp preview_from_changeset(changeset) do
    case Ecto.Changeset.apply_action(changeset, :insert) do
      {:ok, saved_account_report} -> preview_for_saved_account_report(saved_account_report)
      {:error, _changeset} -> nil
    end
  end

  defp preview_for_saved_account_report(%SavedAccountReport{} = saved_account_report) do
    case Reporting.preview_saved_account_report(saved_account_report) do
      {:ok, %{report: report, live?: live?, effective_as_of_date: effective_as_of_date}} ->
        %{
          status: report.conversion_status,
          live?: live?,
          effective_as_of_date: effective_as_of_date,
          report: report,
          message: nil
        }

      {:error, reason} ->
        %{
          status: :invalid,
          live?: SavedAccountReport.live?(saved_account_report),
          effective_as_of_date: saved_account_report.pinned_as_of_date || Date.utc_today(),
          report: nil,
          message: preview_error_message(reason)
        }
    end
  end

  defp preview_error_message(_reason) do
    dgettext("reports", "saved_account_report_invalid_body")
  end

  defp persist_saved_account_report(%SavedAccountReport{id: nil}, params) do
    Reporting.create_saved_account_report(params)
  end

  defp persist_saved_account_report(%SavedAccountReport{} = saved_account_report, params) do
    Reporting.update_saved_account_report(saved_account_report, params)
  end

  defp save_success_message(true),
    do: dgettext("reports", "saved_account_report_created")

  defp save_success_message(false),
    do: dgettext("reports", "saved_account_report_updated")

  defp report_changeset(%SavedAccountReport{} = saved_account_report, params) do
    Reporting.change_saved_account_report(saved_account_report, params)
  end

  defp saved_account_report_breadcrumbs(nil) do
    [
      %{label: dgettext("reports", "page_title"), path: ~p"/reports"},
      %{label: dgettext("reports", "saved_account_report_page_title"), path: nil}
    ]
  end

  defp saved_account_report_breadcrumbs(%SavedAccountReport{} = saved_account_report) do
    [
      %{label: dgettext("reports", "page_title"), path: ~p"/reports"},
      %{label: Reporting.saved_account_report_label(saved_account_report), path: nil}
    ]
  end

  defp selected_account(changeset, accounts_by_id) do
    case Ecto.Changeset.get_field(changeset, :account_id) do
      nil -> nil
      account_id -> Map.get(accounts_by_id, account_id)
    end
  end

  defp compatible_fx_series(changeset, %Account{} = account) do
    case {
      Ecto.Changeset.get_field(changeset, :convert),
      Ecto.Changeset.get_field(changeset, :target_currency_code),
      Ecto.Changeset.get_field(changeset, :pinned_as_of_date)
    } do
      {true, target_currency_code, %Date{} = pinned_as_of_date}
      when is_binary(target_currency_code) and target_currency_code != account.currency_code ->
        Fx.list_compatible_fx_series(
          account.currency_code,
          target_currency_code,
          pinned_as_of_date
        )

      {true, target_currency_code, nil}
      when is_binary(target_currency_code) and target_currency_code != account.currency_code ->
        Fx.list_compatible_fx_series(
          account.currency_code,
          target_currency_code,
          Date.utc_today()
        )

      _ ->
        []
    end
  end

  defp compatible_fx_series(_changeset, _account), do: []

  defp list_accounts(entities) do
    entity_names = Map.new(entities, &{&1.id, &1.name})

    entities
    |> Enum.map(& &1.id)
    |> Ledger.list_accounts_for_entities(include_archived: true)
    |> Enum.sort_by(&{Map.fetch!(entity_names, &1.entity_id), &1.name, &1.id})
  end

  defp account_options(accounts, entities) do
    entity_names = Map.new(entities, &{&1.id, &1.name})

    Enum.map(accounts, fn account ->
      label =
        [
          Map.fetch!(entity_names, account.entity_id),
          account.name,
          account.currency_code
        ]
        |> Enum.join(" · ")

      {label, account.id}
    end)
  end

  defp currency_options do
    Fx.Provider.common_currency_codes()
    |> Enum.map(&{&1, &1})
  end

  defp compatible_series_options(series) do
    Enum.map(series, fn %FxSeries{} = fx_series ->
      {
        compatible_series_label(fx_series),
        fx_series.id
      }
    end)
  end

  defp compatible_series_label(%FxSeries{} = series) do
    inversion =
      if(series.inverted?,
        do: dgettext("reports", "account_report_inverted_series_tag"),
        else: ""
      )

    [
      series.name,
      "#{series.base_currency_code}/#{series.quote_currency_code}",
      inversion
    ]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(" · ")
  end

  defp conversion_status_label(:converted),
    do: dgettext("reports", "account_report_status_converted")

  defp conversion_status_label(:unavailable),
    do: dgettext("reports", "account_report_status_unavailable")

  defp conversion_status_label(:not_requested),
    do: dgettext("reports", "account_report_status_native")

  defp conversion_status_label(_), do: dgettext("reports", "saved_account_report_invalid")

  defp conversion_status_variant(:converted), do: :good
  defp conversion_status_variant(:unavailable), do: :warn
  defp conversion_status_variant(:not_requested), do: :default
  defp conversion_status_variant(_), do: :bad

  defp native_amount_display(%{
         native_amount: %Decimal{} = amount,
         native_currency_code: currency_code
       }),
       do: format_money(amount, currency_code)

  defp native_amount_display(_report), do: dgettext("reports", "account_report_not_available")

  defp converted_amount_display(%{
         conversion_status: :converted,
         converted_amount: %Decimal{} = amount,
         converted_currency_code: currency_code
       }),
       do: format_money(amount, currency_code)

  defp converted_amount_display(%{conversion_status: :unavailable}),
    do: dgettext("reports", "account_report_unavailable_value")

  defp converted_amount_display(%{conversion_status: :not_requested}),
    do: dgettext("reports", "account_report_not_requested_value")

  defp converted_amount_display(_report), do: dgettext("reports", "account_report_not_available")

  defp rate_date_display(%{
         conversion_status: :converted,
         fx_rate_effective_date: %Date{} = date
       }),
       do: Date.to_iso8601(date)

  defp rate_date_display(%{conversion_status: :unavailable}),
    do: dgettext("reports", "account_report_not_available")

  defp rate_date_display(_report), do: dgettext("reports", "account_report_not_requested_value")

  defp series_reference(%{fx_series_name: nil, fx_series_slug: nil}),
    do: dgettext("reports", "account_report_not_available")

  defp series_reference(%{fx_series_slug: slug}) when is_binary(slug), do: slug

  defp series_reference(_report), do: dgettext("reports", "account_report_not_available")

  defp series_reference_badge(%{conversion_status: status} = report)
       when status in [:converted, :unavailable],
       do: series_reference(report)

  defp series_reference_badge(_report), do: nil

  defp preview_status_label(nil), do: nil

  defp preview_status_label(%{status: :invalid}),
    do: dgettext("reports", "saved_account_report_invalid")

  defp preview_status_label(%{status: status}), do: conversion_status_label(status)

  defp preview_status_variant(nil), do: :default
  defp preview_status_variant(%{status: :invalid}), do: :bad
  defp preview_status_variant(%{status: status}), do: conversion_status_variant(status)
end
