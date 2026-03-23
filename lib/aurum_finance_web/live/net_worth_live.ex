defmodule AurumFinanceWeb.NetWorthLive do
  @moduledoc """
  Detailed Net Worth reporting page.
  """

  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.NetWorthComponents

  alias AurumFinance.Entities
  alias AurumFinance.Reporting

  @report_refresh_debounce_ms 75

  @impl true
  def mount(_params, _session, socket) do
    empty_report = empty_report(Date.utc_today())

    socket =
      socket
      |> assign(
        active_nav: :reports,
        page_title: dgettext("reports", "net_worth_page_title"),
        entity_ids: visible_entity_ids(),
        report: empty_report,
        report_load_failed?: false,
        report_refresh_scheduled?: false,
        expanded_account_id: nil,
        drilldown_account_row: nil,
        drilldown_data: nil,
        drilldown_page: 1
      )
      |> assign_report_derivatives(empty_report)

    if connected?(socket) do
      _ = reporting_module().subscribe_hub_freshness()
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    as_of_date = parse_as_of_date(params)

    {:noreply,
     socket
     |> assign(:as_of_date, as_of_date)
     |> load_report(socket.assigns.entity_ids, as_of_date)}
  end

  @impl true
  def handle_event("change_filters", %{"filters" => %{"as_of_date" => date}}, socket) do
    {:noreply, push_patch(socket, to: net_worth_path(parse_as_of_date(%{"as_of_date" => date})))}
  end

  @impl true
  def handle_event("toggle_drilldown", %{"id" => account_id}, socket) do
    socket =
      if socket.assigns.expanded_account_id == account_id do
        clear_drilldown_state(socket)
      else
        load_drilldown(socket, account_id, 1)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_drilldown_page", %{"page" => page}, socket) do
    {:noreply, load_drilldown_page(socket, page)}
  end

  @impl true
  def handle_info({:reporting_hub_freshness_invalidated, _payload}, socket) do
    {:noreply, schedule_report_refresh(socket)}
  end

  @impl true
  def handle_info({:reporting_hub_freshness_refreshed, _payload}, socket) do
    {:noreply, schedule_report_refresh(socket)}
  end

  @impl true
  def handle_info(:refresh_report, socket) do
    {:noreply,
     socket
     |> assign(:report_refresh_scheduled?, false)
     |> refresh_report()}
  end

  @impl true
  def handle_info(_message, socket), do: {:noreply, socket}

  defp refresh_report(socket) do
    load_report(socket, socket.assigns.entity_ids, socket.assigns.as_of_date)
  end

  defp schedule_report_refresh(%{assigns: %{report_refresh_scheduled?: true}} = socket),
    do: socket

  defp schedule_report_refresh(socket) do
    Process.send_after(self(), :refresh_report, @report_refresh_debounce_ms)
    assign(socket, :report_refresh_scheduled?, true)
  end

  defp load_report(socket, entity_ids, as_of_date) do
    case reporting_module().net_worth_report(entity_ids, as_of_date: as_of_date) do
      {:ok, report} ->
        socket
        |> clear_flash(:error)
        |> assign(:report, report)
        |> assign(:report_load_failed?, false)
        |> assign_report_derivatives(report)

      {:error, _reason} ->
        report = empty_report(as_of_date)

        socket
        |> put_flash(:error, dgettext("reports", "report_load_failed"))
        |> assign(:report, report)
        |> assign(:report_load_failed?, true)
        |> assign_report_derivatives(report)
    end
  end

  defp load_drilldown(socket, account_id, page) do
    case account_row_by_id(socket.assigns.report.account_rows, account_id) do
      nil ->
        clear_drilldown_state(socket)

      %{has_snapshot?: false} ->
        clear_drilldown_state(socket)

      account_row ->
        case reporting_module().net_worth_drilldown_transactions(
               account_id,
               account_row.snapshot_date_used,
               page: page
             ) do
          {:ok, drilldown_data} ->
            socket
            |> assign(:expanded_account_id, account_id)
            |> assign(:drilldown_account_row, account_row)
            |> assign(:drilldown_data, drilldown_data)
            |> assign(:drilldown_page, drilldown_data.page)

          {:error, _reason} ->
            clear_drilldown_state(socket)
        end
    end
  end

  defp load_drilldown_page(%{assigns: %{drilldown_data: nil}} = socket, _page), do: socket

  defp load_drilldown_page(socket, page) do
    page = normalize_positive_integer(page, socket.assigns.drilldown_page)

    load_drilldown(socket, socket.assigns.expanded_account_id, page)
  end

  defp visible_entity_ids do
    Entities.list_entities()
    |> Enum.map(& &1.id)
  end

  defp reporting_module do
    Application.get_env(:aurum_finance, :reporting_module, Reporting)
  end

  defp parse_as_of_date(%{"as_of_date" => date}), do: parse_as_of_date(date)
  defp parse_as_of_date(%{"filters" => %{"as_of_date" => date}}), do: parse_as_of_date(date)

  defp parse_as_of_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, parsed_date} -> parsed_date
      {:error, _reason} -> Date.utc_today()
    end
  end

  defp parse_as_of_date(_params), do: Date.utc_today()

  defp assign_report_derivatives(socket, report) do
    assign(socket,
      filter_form: to_form(%{"as_of_date" => Date.to_iso8601(report.as_of_date)}, as: :filters),
      freshness_badge_variant:
        freshness_badge_variant(report.freshness_status, socket.assigns.report_load_failed?),
      freshness_badge_label:
        freshness_badge_label(report.freshness_status, socket.assigns.report_load_failed?),
      date_presets: date_presets(report.as_of_date),
      summary_cards: build_summary_cards(report.currency_summaries),
      account_rows: build_account_rows(report.account_rows),
      coverage_counts_display: coverage_counts_display(report.coverage_counts),
      expanded_account_id: nil,
      drilldown_account_row: nil,
      drilldown_data: nil,
      drilldown_page: 1
    )
  end

  defp empty_report(as_of_date) do
    %{
      as_of_date: as_of_date,
      freshness_status: :up_to_date,
      refresh_suggested?: false,
      empty?: true,
      included_account_count: 0,
      entity_count: 0,
      show_entity_column?: false,
      coverage_counts: %{exact: 0, carried_forward: 0, refreshable_gap: 0, no_history: 0},
      currency_summaries: [],
      account_rows: []
    }
  end

  defp freshness_badge_variant(_status, true), do: :bad
  defp freshness_badge_variant(:up_to_date, false), do: :good
  defp freshness_badge_variant(:outdated, false), do: :warn

  defp freshness_badge_label(_status, true),
    do: dgettext("reports", "report_freshness_unavailable")

  defp freshness_badge_label(:up_to_date, false),
    do: dgettext("reports", "hub_freshness_up_to_date")

  defp freshness_badge_label(:outdated, false), do: dgettext("reports", "hub_freshness_outdated")

  defp build_summary_cards(currency_summaries) do
    Enum.map(currency_summaries, fn summary ->
      %{
        currency_code: summary.currency_code,
        net_worth: format_money(summary.net_worth, summary.currency_code),
        assets: format_money(summary.assets, summary.currency_code),
        liabilities: format_money(summary.liabilities, summary.currency_code),
        coverage_meta:
          dgettext("reports", "net_worth_summary_coverage",
            covered: summary.covered_account_count,
            total: summary.account_count,
            no_history: summary.no_history_count
          )
      }
    end)
  end

  defp build_account_rows(account_rows) do
    Enum.map(account_rows, fn row ->
      %{
        account_id: row.account_id,
        has_snapshot?: not is_nil(row.snapshot_date_used),
        snapshot_date_used: row.snapshot_date_used,
        entity_name: row.entity.name,
        account_name: row.account_name,
        account_type: net_worth_account_type_label(row.account_type),
        currency_code: row.currency_code,
        balance_display: balance_display(row),
        snapshot_used_display: snapshot_used_display(row),
        coverage_label: net_worth_coverage_label(row.coverage),
        coverage_variant: net_worth_coverage_variant(row.coverage)
      }
    end)
  end

  defp net_worth_account_type_label(:asset),
    do: dgettext("reports", "net_worth_account_type_asset")

  defp net_worth_account_type_label(:liability),
    do: dgettext("reports", "net_worth_account_type_liability")

  defp balance_display(%{coverage: :no_history}),
    do: dgettext("reports", "net_worth_balance_unavailable")

  defp balance_display(row), do: format_money(row.balance, row.currency_code)

  defp snapshot_used_display(%{snapshot_date_used: nil}) do
    dgettext("reports", "net_worth_snapshot_none")
  end

  defp snapshot_used_display(%{snapshot_date_used: date, coverage: :exact}) do
    dgettext("reports", "net_worth_snapshot_exact", date: Date.to_iso8601(date))
  end

  defp snapshot_used_display(%{snapshot_date_used: date, coverage: :carried_forward}) do
    dgettext("reports", "net_worth_snapshot_carried_forward", date: Date.to_iso8601(date))
  end

  defp snapshot_used_display(%{snapshot_date_used: date, coverage: :refreshable_gap}) do
    dgettext("reports", "net_worth_snapshot_refreshable_gap", date: Date.to_iso8601(date))
  end

  defp net_worth_coverage_label(:exact), do: dgettext("reports", "net_worth_coverage_exact")

  defp net_worth_coverage_label(:carried_forward),
    do: dgettext("reports", "net_worth_coverage_carried_forward")

  defp net_worth_coverage_label(:refreshable_gap),
    do: dgettext("reports", "net_worth_coverage_refreshable_gap")

  defp net_worth_coverage_label(:no_history),
    do: dgettext("reports", "net_worth_coverage_no_history")

  defp net_worth_coverage_variant(:exact), do: :good
  defp net_worth_coverage_variant(:carried_forward), do: :default
  defp net_worth_coverage_variant(:refreshable_gap), do: :warn
  defp net_worth_coverage_variant(:no_history), do: :bad

  defp coverage_counts_display(coverage_counts) do
    [
      dgettext("reports", "net_worth_coverage_counts_exact", count: coverage_counts.exact),
      dgettext("reports", "net_worth_coverage_counts_carried_forward",
        count: coverage_counts.carried_forward
      ),
      dgettext("reports", "net_worth_coverage_counts_refreshable_gap",
        count: coverage_counts.refreshable_gap
      ),
      dgettext("reports", "net_worth_coverage_counts_no_history",
        count: coverage_counts.no_history
      )
    ]
  end

  defp date_presets(%Date{} = selected_date) do
    today = Date.utc_today()
    last_month_end = today.year |> Date.new!(today.month, 1) |> Date.add(-1)
    last_year_end = Date.new!(today.year - 1, 12, 31)

    [
      date_preset(:today, dgettext("reports", "net_worth_preset_today"), today, selected_date),
      date_preset(
        :last_month_end,
        dgettext("reports", "net_worth_preset_last_month_end"),
        last_month_end,
        selected_date
      ),
      date_preset(
        :last_year_end,
        dgettext("reports", "net_worth_preset_last_year_end"),
        last_year_end,
        selected_date
      )
    ]
  end

  defp date_preset(key, label, date, selected_date) do
    %{
      key: key,
      label: label,
      date: date,
      path: net_worth_path(date),
      active?: Date.compare(date, selected_date) == :eq
    }
  end

  defp net_worth_path(%Date{} = as_of_date) do
    ~p"/reports/net-worth?#{[as_of_date: Date.to_iso8601(as_of_date)]}"
  end

  defp clear_drilldown_state(socket) do
    assign(socket,
      expanded_account_id: nil,
      drilldown_account_row: nil,
      drilldown_data: nil,
      drilldown_page: 1
    )
  end

  defp account_row_by_id(account_rows, account_id) do
    Enum.find(account_rows, &(&1.account_id == account_id))
  end

  defp normalize_positive_integer(page, _default_page) when is_integer(page) and page > 0,
    do: page

  defp normalize_positive_integer(page, default_page) when is_binary(page) do
    case Integer.parse(page) do
      {int, ""} when int > 0 -> int
      _ -> default_page
    end
  end

  defp normalize_positive_integer(_page, default_page), do: default_page

  defp drilldown_colspan(true), do: 7
  defp drilldown_colspan(false), do: 6
end
