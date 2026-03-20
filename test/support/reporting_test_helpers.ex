defmodule AurumFinance.ReportingTestHelpers do
  @moduledoc false

  alias AurumFinance.Ledger
  alias AurumFinance.Repo
  alias AurumFinance.Reporting.DailyBalanceSnapshot

  def insert_snapshot!(account, snapshot_date, closing_balance, daily_delta, computed_at \\ nil) do
    computed_at = computed_at || DateTime.utc_now() |> DateTime.truncate(:microsecond)

    %DailyBalanceSnapshot{}
    |> DailyBalanceSnapshot.changeset(%{
      account_id: account.id,
      entity_id: account.entity_id,
      snapshot_date: snapshot_date,
      closing_balance: Decimal.new(closing_balance),
      daily_delta: Decimal.new(daily_delta),
      computed_at: computed_at,
      projection_version: 1
    })
    |> Repo.insert!()
  end

  def create_transaction!(entity, date, postings, description \\ "Reporting test transaction") do
    {:ok, transaction} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: date,
        description: description,
        source_type: :manual,
        postings: postings
      })

    transaction
  end
end
