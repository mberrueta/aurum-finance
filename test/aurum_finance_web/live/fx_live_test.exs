defmodule AurumFinanceWeb.FxLiveTest do
  use AurumFinanceWeb.ConnCase, async: false
  use Oban.Testing, repo: AurumFinance.Repo

  import Ecto.Query
  import Phoenix.LiveViewTest

  alias AurumFinance.Fx
  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Repo
  alias Oban.Job

  describe "detail sync status" do
    test "shows the last sync failure details for a provider-backed series", %{conn: conn} do
      series =
        insert_fx_series(%{
          name: "USD/BRL provider",
          provider_module: "bcb_ptax"
        })

      {:ok, %Job{id: job_id}} = AurumFinance.Fx.enqueue_fx_sync(series)

      {1, _} =
        Repo.update_all(
          from(job in Job, where: job.id == ^job_id),
          set: [
            state: "discarded",
            attempted_at: ~U[2026-03-24 10:00:00Z],
            discarded_at: ~U[2026-03-24 10:01:00Z],
            errors: [%{"error" => "{:error, {:http_status, 404}}"}]
          ]
        )

      {:ok, view, _html} = conn |> log_in_root() |> live("/fx")

      view
      |> element("#fx-view-btn-#{series.id}")
      |> render_click()

      assert_patch(view, ~p"/fx/#{series.slug}")
      assert has_element?(view, "#fx-sync-status")
      assert render(view) =~ "Sync Failed"
      assert render(view) =~ "{:error, {:http_status, 404}}"
      assert has_element?(view, "#fx-sync-now-btn")
      assert has_element?(view, "#fx-refresh-sync-status-btn")
    end

    test "loads detail directly from slug URL", %{conn: conn} do
      series = insert_fx_series(%{name: "Direct URL series"})

      {:ok, view, _html} = conn |> log_in_root() |> live(~p"/fx/#{series.slug}")

      assert has_element?(view, "#fx-series-detail")
      assert render(view) =~ "Direct URL series"
      assert has_element?(view, "#fx-sync-status")
      assert has_element?(view, "#app-breadcrumb-0[href='/fx']", "FX Rates")
      assert has_element?(view, "#app-breadcrumb-1", "Direct URL series")
    end

    test "rate records support filtering, pagination and weekday formatting", %{conn: conn} do
      series = insert_fx_series(%{name: "Paged series"})

      rows =
        for day <- 1..40 do
          %{date: Date.add(~D[2026-01-01], day - 1), value: Decimal.new("5.#{day}")}
        end

      {:ok, 40} = Fx.upsert_rate_records(series.id, rows)

      {:ok, view, _html} = conn |> log_in_root() |> live(~p"/fx/#{series.slug}")

      assert has_element?(view, "#fx-rate-filter-form")
      assert render(view) =~ "Page 1 / 2"
      assert render(view) =~ "Variation"
      assert render(view) =~ "%"
      assert has_element?(view, "#fx-rate-page-prev")
      assert has_element?(view, "#fx-rate-page-next")
      assert render(view) =~ "(Mon)"

      view
      |> element("#fx-rate-page-next")
      |> render_click()

      assert render(view) =~ "Page 2 / 2"

      view
      |> element("#fx-rate-filter-form")
      |> render_change(%{
        "_target" => ["rate_filter", "date"],
        "rate_filter" => %{"date" => "2026-01-10"}
      })

      refute render(view) =~ "Page 1 / 1"
      assert render(view) =~ "2026-01-08 (Thu)"
      assert render(view) =~ "2026-01-10 (Sat)"
      assert render(view) =~ "2026-01-12 (Mon)"
      refute render(view) =~ "2026-01-07 (Wed)"
      refute render(view) =~ "2026-01-13 (Tue)"
      refute has_element?(view, "#fx-rate-page-prev")
      refute has_element?(view, "#fx-rate-page-next")
    end

    test "shows persisted error status in the FX list", %{conn: conn} do
      series =
        Repo.insert!(%FxSeries{
          id: Ecto.UUID.generate(),
          name: "Broken provider",
          slug: "broken-provider-list",
          base_currency_code: "USD",
          quote_currency_code: "BRL",
          from_date: ~D[2026-03-01],
          source_kind: :provider_module,
          provider_module: "broken_provider",
          sync_status: :error,
          sync_message: ":unknown_provider",
          inserted_at: now(),
          updated_at: now()
        })

      {:ok, view, _html} = conn |> log_in_root() |> live("/fx")

      assert has_element?(view, "#fx-series-row-#{series.id}")
      assert render(view) =~ "Error"
      assert render(view) =~ ":unknown_provider"
    end

    test "imports CSV for manual series from detail page", %{conn: conn} do
      series = insert_csv_fx_series(%{name: "Manual CSV series", slug: "manual-csv-series"})

      {:ok, view, _html} = conn |> log_in_root() |> live(~p"/fx/#{series.slug}")

      assert has_element?(view, "#fx-csv-upload-form")

      upload =
        file_input(view, "#fx-csv-upload-form", :csv, [
          %{
            name: "rates.csv",
            content: "date,value\n2026-03-10,5.60\n2026-03-11,5.62\n",
            type: "text/csv"
          }
        ])

      render_upload(upload, "rates.csv")
      view |> element("#fx-csv-upload-form") |> render_submit()

      assert render(view) =~ "CSV imported. Inserted: 2. Updated: 0."
      assert render(view) =~ "2026-03-11 (Wed)"
      assert render(view) =~ "2026-03-10 (Tue)"
      assert Repo.get!(FxSeries, series.id).from_date == ~D[2026-03-10]
    end

    test "shows explicit error when submitting manual import without a file", %{conn: conn} do
      series = insert_csv_fx_series(%{name: "Manual empty upload", slug: "manual-empty-upload"})

      {:ok, view, _html} = conn |> log_in_root() |> live(~p"/fx/#{series.slug}")

      view |> element("#fx-csv-upload-form") |> render_submit()

      assert render(view) =~ "no_file_selected"
    end
  end

  describe "create form currency selects" do
    test "narrows quote currency options for BCB PTAX", %{conn: conn} do
      {:ok, view, _html} = conn |> log_in_root() |> live("/fx")

      view
      |> element("#fx-new-series-btn")
      |> render_click()

      assert has_element?(view, "#fx_series_base_currency_code option[value='USD']")
      assert has_element?(view, "#fx_series_quote_currency_code option[value='BRL']")
      assert has_element?(view, "#fx_series_quote_currency_code option[value='USD']")

      view
      |> element("#fx-series-form-inner")
      |> render_change(%{
        "_target" => ["fx_series", "source_kind"],
        "fx_series" => %{"source_kind" => "provider_module"}
      })

      assert has_element?(view, "#fx_series_provider_module")

      view
      |> element("#fx-series-form-inner")
      |> render_change(%{
        "_target" => ["fx_series", "provider_module"],
        "fx_series" => %{
          "source_kind" => "provider_module",
          "provider_module" => "bcb_ptax"
        }
      })

      assert has_element?(view, "#fx_series_base_currency_code option[value='USD']")
      assert has_element?(view, "#fx_series_quote_currency_code option[value='BRL']")
      refute has_element?(view, "#fx_series_quote_currency_code option[value='USD']")
    end
  end

  defp insert_fx_series(attrs) do
    params =
      %{
        name: "Provider-backed series",
        base_currency_code: "USD",
        quote_currency_code: "BRL",
        from_date: ~D[2026-03-01],
        source_kind: :provider_module,
        provider_module: "bcb_ptax"
      }
      |> Map.merge(attrs)

    %FxSeries{}
    |> FxSeries.create_changeset(params)
    |> Repo.insert!()
  end

  defp insert_csv_fx_series(attrs) do
    params =
      %{
        name: "Manual CSV",
        base_currency_code: "USD",
        quote_currency_code: "BRL",
        from_date: ~D[2026-03-25],
        source_kind: :csv_upload
      }
      |> Map.merge(attrs)

    %FxSeries{}
    |> FxSeries.create_changeset(params)
    |> Repo.insert!()
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
