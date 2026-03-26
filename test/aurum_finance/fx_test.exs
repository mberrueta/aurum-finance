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
