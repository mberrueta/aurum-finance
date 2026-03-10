defmodule AurumFinance.Ingestion.ParserTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.Parsers.CSV
  alias AurumFinance.Ingestion.Parser
  alias AurumFinance.Ingestion.ParserError

  doctest CSV

  describe "parse/1" do
    test "rejects unsupported formats clearly" do
      assert {:error, %ParserError{} = error} =
               Parser.parse(%{
                 format: :ofx,
                 content: "<OFX></OFX>"
               })

      assert error.reason == :unsupported_format
      assert error.details == %{format: :ofx}
    end

    test "parses csv content into canonical row candidates without dedupe decisions" do
      csv = """
      Date,Description,Amount,Currency
      2026-03-10,"Coffee, Shop",-4.50,usd
      2026-03-11,Salary,1000.00,USD
      """

      assert {:ok, parsed_import} =
               Parser.parse(%{
                 format: :csv,
                 content: csv
               })

      assert parsed_import.format == :csv
      assert parsed_import.row_count == 2
      assert parsed_import.warnings == []

      [first_row, second_row] = parsed_import.rows

      assert first_row.row_index == 1

      assert first_row.raw_data == %{
               "Date" => "2026-03-10",
               "Description" => "Coffee, Shop",
               "Amount" => "-4.50",
               "Currency" => "usd"
             }

      assert first_row.canonical_data == %{
               posted_on: "2026-03-10",
               description: "Coffee, Shop",
               amount: "-4.50",
               currency: "usd"
             }

      assert second_row.row_index == 2
      refute Map.has_key?(second_row, :status)
    end
  end

  describe "parse_imported_file/1" do
    test "parses a stored imported file from storage_path" do
      entity = insert(:entity, name: "Parser entity")
      account = insert(:account, entity: entity, entity_id: entity.id, name: "Parser account")

      assert {:ok, imported_file} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "transactions.csv",
                 content: "posted_on,memo,amount,currency\n2026-03-10,Coffee,-4.50,USD\n",
                 content_type: "text/csv"
               })

      assert {:ok, parsed_import} = Ingestion.parse_imported_file(imported_file)

      assert parsed_import.row_count == 1
      assert [%{canonical_data: canonical_data}] = parsed_import.rows
      assert canonical_data.posted_on == "2026-03-10"
      assert canonical_data.description == "Coffee"
      assert canonical_data.amount == "-4.50"
      assert canonical_data.currency == "USD"
    end

    test "returns a parser error for empty csv files" do
      entity = insert(:entity, name: "Empty parser entity")

      account =
        insert(:account, entity: entity, entity_id: entity.id, name: "Empty parser account")

      assert {:ok, imported_file} =
               Ingestion.store_imported_file(%{
                 account_id: account.id,
                 filename: "empty.csv",
                 content: "",
                 content_type: "text/csv"
               })

      assert {:error, %ParserError{} = error} = Ingestion.parse_imported_file(imported_file)
      assert error.reason == :empty_file
    end
  end
end
