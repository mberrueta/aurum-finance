defmodule AurumFinance.Fx.Providers.FrankfurterEcbTest do
  use ExUnit.Case, async: false

  import Mock

  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Fx.Providers.FrankfurterEcb

  describe "fetch/3" do
    test "parses rates maps and keeps rows sorted by date" do
      series = %FxSeries{base_currency_code: "USD", quote_currency_code: "EUR"}

      with_mock Req, [:passthrough],
        get: fn url, [receive_timeout: timeout] ->
          assert url == "https://api.frankfurter.app/2026-03-24..2026-03-25?from=USD&to=EUR"

          assert timeout == 30_000

          {:ok,
           %Req.Response{
             status: 200,
             body: %{
               "rates" => %{
                 "2026-03-25" => %{"EUR" => 0.9, "USD" => 1.0},
                 "2026-03-24" => %{"EUR" => 0.8},
                 "2026-03-23" => %{"GBP" => 0.7}
               }
             }
           }}
        end do
        assert {:ok,
                [%{date: ~D[2026-03-24], value: first}, %{date: ~D[2026-03-25], value: second}]} =
                 FrankfurterEcb.fetch(series, ~D[2026-03-24], ~D[2026-03-25])

        assert Decimal.equal?(first, Decimal.new("0.8"))
        assert Decimal.equal?(second, Decimal.new("0.9"))
      end
    end
  end
end
