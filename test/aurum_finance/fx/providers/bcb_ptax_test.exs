defmodule AurumFinance.Fx.Providers.BcbPtaxTest do
  use ExUnit.Case, async: true

  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Fx.Providers.BcbPtax

  setup do
    bypass = Bypass.open()
    original_base_urls = Application.get_env(:aurum_finance, :fx_provider_base_urls, %{})

    Application.put_env(
      :aurum_finance,
      :fx_provider_base_urls,
      Map.put(original_base_urls, "bcb_ptax", "http://localhost:#{bypass.port}")
    )

    on_exit(fn ->
      Application.put_env(:aurum_finance, :fx_provider_base_urls, original_base_urls)
    end)

    {:ok, bypass: bypass}
  end

  describe "fetch/3" do
    test "uses the OData endpoint and keeps only fechamento quotes", %{bypass: bypass} do
      Bypass.expect_once(
        bypass,
        "GET",
        "/CotacaoMoedaPeriodo(moeda=@moeda,dataInicial=@dataInicial,dataFinalCotacao=@dataFinalCotacao)",
        fn conn ->
          conn = Plug.Conn.fetch_query_params(conn)

          assert conn.query_params["@moeda"] == "'USD'"
          assert conn.query_params["@dataInicial"] == "'03-24-2026'"
          assert conn.query_params["@dataFinalCotacao"] == "'03-25-2026'"
          assert conn.query_params["$format"] == "json"
          assert conn.query_params["$select"] == "cotacaoVenda,dataHoraCotacao,tipoBoletim"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(
            200,
            Jason.encode!(%{
              "value" => [
                %{
                  "cotacaoVenda" => 5.72,
                  "dataHoraCotacao" => "2026-03-24 13:00:00.000",
                  "tipoBoletim" => "Abertura"
                },
                %{
                  "cotacaoVenda" => 5.75,
                  "dataHoraCotacao" => "2026-03-24 18:00:00.000",
                  "tipoBoletim" => "Fechamento"
                }
              ]
            })
          )
        end
      )

      series = %FxSeries{base_currency_code: "USD", quote_currency_code: "BRL"}

      assert {:ok, [%{date: ~D[2026-03-24], value: value}]} =
               BcbPtax.fetch(series, ~D[2026-03-24], ~D[2026-03-25])

      assert Decimal.equal?(value, Decimal.new("5.75"))
    end

    test "rejects non-BRL quote pairs before making the request" do
      series = %FxSeries{base_currency_code: "USD", quote_currency_code: "EUR"}

      assert {:error, :unsupported_currency_pair} =
               BcbPtax.fetch(series, ~D[2026-03-24], ~D[2026-03-25])
    end
  end
end
