defmodule AurumFinance.Fx.GlobalSyncSchedulerTest do
  use AurumFinance.DataCase, async: false
  use Oban.Testing, repo: AurumFinance.Repo

  alias AurumFinance.Fx.FxRateRecord
  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Fx.GlobalSyncScheduler
  alias AurumFinance.Fx.SyncWorker

  describe "handle_info/2" do
    test "enqueues sync jobs only for stale provider-backed active series" do
      yesterday = Date.add(Date.utc_today(), -1)

      stale_series =
        insert_fx_series(%{
          name: "BCB USD/BRL stale",
          from_date: ~D[2026-03-01],
          provider_module: "bcb_ptax"
        })

      missing_series =
        insert_fx_series(%{
          name: "ECB EUR/USD missing",
          from_date: ~D[2026-03-05],
          base_currency_code: "EUR",
          quote_currency_code: "USD",
          provider_module: "frankfurter_ecb"
        })

      fresh_series =
        insert_fx_series(%{
          name: "BCB USD/BRL fresh",
          from_date: ~D[2026-03-01],
          provider_module: "bcb_ptax"
        })

      expired_series =
        insert_fx_series(%{
          name: "BCB USD/BRL expired",
          from_date: ~D[2026-03-01],
          to_date: Date.add(yesterday, -1),
          provider_module: "bcb_ptax"
        })

      insert_fx_rate_record(stale_series, Date.add(yesterday, -2))
      insert_fx_rate_record(fresh_series, yesterday)
      insert_fx_rate_record(expired_series, Date.add(yesterday, -10))

      assert {:noreply, %{}} = GlobalSyncScheduler.handle_info(:run, %{})

      assert_enqueued(
        worker: SyncWorker,
        queue: :fx,
        args: %{
          "fx_series_id" => stale_series.id,
          "from_date" => Date.to_iso8601(Date.add(yesterday, -1)),
          "to_date" => Date.to_iso8601(Date.utc_today())
        }
      )

      assert_enqueued(
        worker: SyncWorker,
        queue: :fx,
        args: %{
          "fx_series_id" => missing_series.id,
          "from_date" => Date.to_iso8601(missing_series.from_date),
          "to_date" => Date.to_iso8601(Date.utc_today())
        }
      )

      refute_enqueued(
        worker: SyncWorker,
        queue: :fx,
        args: %{"fx_series_id" => fresh_series.id}
      )

      refute_enqueued(
        worker: SyncWorker,
        queue: :fx,
        args: %{"fx_series_id" => expired_series.id}
      )
    end
  end

  defp insert_fx_series(attrs) do
    params =
      %{
        name: "BCB USD/BRL",
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

  defp insert_fx_rate_record(series, effective_date) do
    %FxRateRecord{}
    |> FxRateRecord.changeset(%{
      fx_series_id: series.id,
      effective_date: effective_date,
      rate_value: Decimal.new("5.250000000000")
    })
    |> Repo.insert!()
  end
end
