defmodule AurumFinance.Reporting.AccountReportObservabilityTest do
  use AurumFinance.DataCase, async: false

  import AurumFinance.ReportingTestHelpers
  import ExUnit.CaptureLog

  alias AurumFinance.Reporting

  setup do
    original_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: original_level)
    end)

    :ok
  end

  describe "get_report/2" do
    test "logs generated reports" do
      entity = insert(:entity, name: "Alpha")
      account = insert_account(entity, name: "Checking")

      insert_snapshot!(account, ~D[2026-03-10], "100.0000", "5.0000")

      log =
        capture_log(fn ->
          assert {:ok, report} =
                   Reporting.account_report(account.id, as_of_date: ~D[2026-03-10])

          assert report.account_id == account.id
        end)

      assert log =~ "reporting.account_report.generated"
      assert log =~ "account_id=#{account.id}"
      assert log =~ "conversion_status=not_requested"
    end
  end
end
