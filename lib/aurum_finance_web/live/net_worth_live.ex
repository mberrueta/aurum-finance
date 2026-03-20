defmodule AurumFinanceWeb.NetWorthLive do
  @moduledoc """
  Detailed Net Worth reporting page.
  """

  use AurumFinanceWeb, :live_view

  alias AurumFinance.Entities
  alias AurumFinance.Reporting

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        active_nav: :reports,
        page_title: dgettext("reports", "net_worth_page_title"),
        entity_ids: visible_entity_ids(),
        report: nil
      )
      |> assign_report_derivatives(Reporting.net_worth_report([]) |> empty_report_result())

    if connected?(socket) do
      _ = Reporting.subscribe_hub_freshness()
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    as_of_date = parse_as_of_date(params)
    report = load_report(socket.assigns.entity_ids, as_of_date)

    {:noreply,
     socket
     |> assign(:report, report)
     |> assign(:as_of_date, as_of_date)
     |> assign_report_derivatives(report)}
  end

  @impl true
  def handle_event("change_filters", %{"filters" => %{"as_of_date" => date}}, socket) do
    {:noreply, push_patch(socket, to: net_worth_path(parse_as_of_date(%{"as_of_date" => date})))}
  end

  @impl true
  def handle_info({:reporting_hub_freshness_invalidated, _payload}, socket) do
    {:noreply, refresh_report(socket)}
  end

  @impl true
  def handle_info({:reporting_hub_freshness_refreshed, _payload}, socket) do
    {:noreply, refresh_report(socket)}
  end

  @impl true
  def handle_info(_message, socket), do: {:noreply, socket}

  defp refresh_report(socket) do
    report = load_report(socket.assigns.entity_ids, socket.assigns.as_of_date)

    socket
    |> assign(:report, report)
    |> assign_report_derivatives(report)
  end

  defp load_report(entity_ids, as_of_date) do
    {:ok, report} = Reporting.net_worth_report(entity_ids, as_of_date: as_of_date)
    report
  end

  defp visible_entity_ids do
    Entities.list_entities()
    |> Enum.map(& &1.id)
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
      freshness_badge_variant: freshness_badge_variant(report.freshness_status),
      freshness_badge_label: freshness_badge_label(report.freshness_status),
      date_presets: date_presets(report.as_of_date),
      summary_cards: build_summary_cards(report.currency_summaries),
      account_rows: build_account_rows(report.account_rows),
      coverage_counts_display: coverage_counts_display(report.coverage_counts)
    )
  end

  defp empty_report_result({:ok, report}), do: report

  defp freshness_badge_variant(:up_to_date), do: :good
  defp freshness_badge_variant(:outdated), do: :warn

  defp freshness_badge_label(:up_to_date), do: dgettext("reports", "hub_freshness_up_to_date")
  defp freshness_badge_label(:outdated), do: dgettext("reports", "hub_freshness_outdated")

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
end
