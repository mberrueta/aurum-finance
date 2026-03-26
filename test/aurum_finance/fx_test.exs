defmodule AurumFinance.FxTest do
  use AurumFinance.DataCase, async: true
  use Oban.Testing, repo: AurumFinance.Repo

  doctest AurumFinance.Fx

  import ExUnit.CaptureLog

  alias AurumFinance.Fx
  alias AurumFinance.Fx.SyncWorker
  alias AurumFinance.Fx.FxSeries
  alias Oban.Job

  describe "create_changeset/2" do
    test "rejects provider-backed pairs not supported by BCB PTAX" do
      changeset =
        FxSeries.create_changeset(%FxSeries{}, %{
          name: "Invalid PTAX pair",
          base_currency_code: "USD",
          quote_currency_code: "EUR",
          from_date: ~D[2026-03-01],
          source_kind: :provider_module,
          provider_module: "bcb_ptax"
        })

      refute changeset.valid?

      expected_error =
        Gettext.dgettext(
          AurumFinance.Gettext,
          "errors",
          "error_fx_provider_currency_pair_not_supported"
        )

      assert expected_error in errors_on(changeset).quote_currency_code
    end
  end

  describe "delete_fx_series/1" do
    test "blocks deletion when the series has persisted rate records" do
      series = insert_fx_series(%{provider_module: nil, source_kind: :csv_upload})

      assert {:ok, 1} =
               Fx.upsert_rate_records(series.id, [
                 %{date: ~D[2026-03-10], value: Decimal.new("5.2500")}
               ])

      assert {:error, :has_records} = Fx.delete_fx_series(series)
      assert %FxSeries{} = Fx.get_fx_series(series.id)
    end

    test "deletes an empty series" do
      series = insert_fx_series(%{provider_module: nil, source_kind: :csv_upload})

      assert {:ok, %FxSeries{id: deleted_id}} = Fx.delete_fx_series(series)
      assert deleted_id == series.id
      assert is_nil(Fx.get_fx_series(series.id))
    end
  end

  describe "lookup_fx_rate/3" do
    test "returns the latest direct rate within the staleness window" do
      series = insert_fx_series(%{provider_module: nil, source_kind: :csv_upload})

      assert {:ok, 2} =
               Fx.upsert_rate_records(series.id, [
                 %{date: ~D[2026-03-08], value: Decimal.new("5.1000")},
                 %{date: ~D[2026-03-10], value: Decimal.new("5.2500")}
               ])

      assert {:ok, %{rate_value: rate, effective_date: ~D[2026-03-10], inverted: false}} =
               Fx.lookup_fx_rate(series.id, ~D[2026-03-12])

      assert Decimal.equal?(rate, Decimal.new("5.2500"))
    end

    test "returns an inverted rate when requested" do
      series = insert_fx_series(%{provider_module: nil, source_kind: :csv_upload})

      assert {:ok, 1} =
               Fx.upsert_rate_records(series.id, [
                 %{date: ~D[2026-03-10], value: Decimal.new("0.25")}
               ])

      assert {:ok, %{rate_value: rate, effective_date: ~D[2026-03-10], inverted: true}} =
               Fx.lookup_fx_rate(series.id, ~D[2026-03-10], invert: true)

      assert Decimal.equal?(rate, Decimal.new("4"))
    end

    test "returns rate_not_found when only stale rows exist" do
      series = insert_fx_series(%{provider_module: nil, source_kind: :csv_upload})

      assert {:ok, 1} =
               Fx.upsert_rate_records(series.id, [
                 %{date: ~D[2026-03-01], value: Decimal.new("5.2500")}
               ])

      assert {:error, :rate_not_found} = Fx.lookup_fx_rate(series.id, ~D[2026-03-10])
    end
  end

  describe "enqueue_fx_sync/1" do
    test "enqueues from the day after the latest stored rate" do
      series = insert_fx_series(%{from_date: ~D[2026-03-01], to_date: ~D[2026-03-10]})

      assert {:ok, 1} =
               Fx.upsert_rate_records(series.id, [
                 %{date: ~D[2026-03-07], value: Decimal.new("5.2500")}
               ])

      assert {:ok, _job} = Fx.enqueue_fx_sync(series)

      assert_enqueued(
        worker: SyncWorker,
        queue: :fx,
        args: %{
          "fx_series_id" => series.id,
          "from_date" => "2026-03-08",
          "to_date" => "2026-03-10"
        }
      )
    end

    test "returns already_up_to_date when the stored coverage already reaches to_date" do
      series = insert_fx_series(%{from_date: ~D[2026-03-01], to_date: ~D[2026-03-10]})

      assert {:ok, 1} =
               Fx.upsert_rate_records(series.id, [
                 %{date: ~D[2026-03-10], value: Decimal.new("5.2500")}
               ])

      assert {:error, :already_up_to_date} = Fx.enqueue_fx_sync(series)

      refute_enqueued(worker: SyncWorker, queue: :fx, args: %{"fx_series_id" => series.id})
    end

    test "rejects csv-backed series" do
      series = insert_fx_series(%{provider_module: nil, source_kind: :csv_upload})

      assert {:error, :not_a_provider_series} = Fx.enqueue_fx_sync(series)
    end
  end

  describe "latest_sync_status/1" do
    test "returns the latest failed sync details for a provider-backed series" do
      series = insert_fx_series(%{provider_module: "bcb_ptax"})

      assert {:ok, %Job{id: job_id}} = Fx.enqueue_fx_sync(series)

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

      status = Fx.latest_sync_status(series)

      assert status.state == :failed
      assert status.job_state == "discarded"
      assert status.from_date == series.from_date
      assert status.to_date == Date.utc_today()
      assert status.last_attempt_at == ~U[2026-03-24 10:00:00.000000Z]
      assert status.finished_at == ~U[2026-03-24 10:01:00.000000Z]
      assert status.error == "{:error, {:http_status, 404}}"
    end

    test "returns never_run when no sync job exists yet" do
      series = insert_fx_series(%{provider_module: "frankfurter_ecb"})

      status = Fx.latest_sync_status(series)

      assert status.state == :active
      assert is_nil(status.error)
      assert is_nil(status.from_date)
    end

    test "marks a provider series as terminal error after the final failed attempt" do
      series =
        Repo.insert!(%FxSeries{
          id: Ecto.UUID.generate(),
          name: "Broken provider",
          slug: "broken-provider",
          base_currency_code: "USD",
          quote_currency_code: "BRL",
          from_date: ~D[2026-03-01],
          source_kind: :provider_module,
          provider_module: "broken_provider",
          inserted_at: now(),
          updated_at: now()
        })

      assert capture_log(fn ->
               assert {:error, :unknown_provider} =
                        SyncWorker.perform(%Job{
                          attempt: 5,
                          max_attempts: 5,
                          args: %{
                            "fx_series_id" => series.id,
                            "from_date" => "2026-03-01",
                            "to_date" => "2026-03-02"
                          }
                        })
             end) =~ "FX sync failed"

      persisted = Repo.get!(FxSeries, series.id)

      assert persisted.sync_status == :error
      assert persisted.sync_message == ":unknown_provider"
      refute is_nil(persisted.last_sync_attempted_at)
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

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
