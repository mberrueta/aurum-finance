defmodule AurumFinance.Reconciliation.MatchCandidateFinder do
  @moduledoc """
  Retrieves raw imported-row candidates for reconciliation matching before any
  scoring or presentation shaping happens.

  This module is responsible only for the retrieval window:

  - scope candidates to the posting account
  - limit rows to `:ready` imported evidence
  - constrain by a configurable date window around the posting date
  - constrain by a broad amount tolerance so obviously unrelated rows are not
    sent to the scorer

  It intentionally does not assign match bands, scores, or UI wording. That
  separation keeps retrieval policy independent from scoring calibration and
  presentation concerns.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Repo

  @default_date_window_days 2
  @absolute_amount_tolerance Decimal.new("1.00")
  @relative_amount_tolerance Decimal.new("0.20")

  @doc """
  Returns imported-row candidates for a posting context within the configured
  retrieval window.

  Expected `posting_context` shape:

  - `:posting` - ledger posting struct
  - `:transaction_date` - posting transaction date
  - `:transaction_description` - posting transaction description
  - `:account` - posting account struct

  Supported options:

  - `:date_window_days` - broad date window around the posting date

  This function is intentionally generous. It returns candidate evidence for the
  scorer to rank, rather than trying to decide the final quality band itself.

  ## Examples

      iex> posting_context = %{
      ...>   posting: %AurumFinance.Ledger.Posting{
      ...>     id: Ecto.UUID.generate(),
      ...>     account_id: Ecto.UUID.generate(),
      ...>     amount: Decimal.new("-20.00")
      ...>   },
      ...>   transaction_date: ~D[2026-03-02],
      ...>   transaction_description: "Fuel",
      ...>   account: %AurumFinance.Ledger.Account{id: Ecto.UUID.generate()}
      ...> }
      iex> [first_candidate | _rest] =
      ...>   AurumFinance.Reconciliation.MatchCandidateFinder.find(
      ...>     posting_context,
      ...>     date_window_days: 2
      ...>   )
      iex> %AurumFinance.Ingestion.ImportedRow{
      ...>   id: _id,
      ...>   imported_file_id: _imported_file_id,
      ...>   account_id: _account_id,
      ...>   posted_on: _posted_on,
      ...>   amount: _amount,
      ...>   description: _description
      ...> } = first_candidate
  """
  @spec find(map(), keyword()) :: [ImportedRow.t()]
  def find(posting_context, opts \\ []) do
    date_window_days = Keyword.get(opts, :date_window_days, @default_date_window_days)

    posting_context
    |> candidate_query(date_window_days)
    |> preload(:imported_file)
    |> order_by([imported_row], desc: imported_row.posted_on, asc: imported_row.row_index)
    |> Repo.all()
  end

  defp candidate_query(posting_context, date_window_days) do
    ImportedRow
    |> where([imported_row], imported_row.account_id == ^posting_context.account.id)
    |> where([imported_row], imported_row.status == ^:ready)
    |> where(
      [imported_row],
      not is_nil(imported_row.posted_on) and not is_nil(imported_row.amount)
    )
    |> where(
      [imported_row],
      imported_row.posted_on >= ^min_candidate_date(posting_context, date_window_days) and
        imported_row.posted_on <= ^max_candidate_date(posting_context, date_window_days)
    )
    |> where(
      [imported_row],
      fragment("ABS(?)", imported_row.amount) >= ^min_candidate_amount(posting_context) and
        fragment("ABS(?)", imported_row.amount) <= ^max_candidate_amount(posting_context)
    )
  end

  defp amount_tolerance(amount) do
    relative_tolerance =
      amount
      |> abs_decimal()
      |> Decimal.mult(@relative_amount_tolerance)

    decimal_max(relative_tolerance, @absolute_amount_tolerance)
  end

  defp decimal_max(left, right) do
    case Decimal.compare(left, right) do
      :lt -> right
      _other -> left
    end
  end

  defp min_candidate_date(posting_context, date_window_days) do
    Date.add(posting_context.transaction_date, -date_window_days)
  end

  defp max_candidate_date(posting_context, date_window_days) do
    Date.add(posting_context.transaction_date, date_window_days)
  end

  defp min_candidate_amount(posting_context) do
    Decimal.sub(
      abs_decimal(posting_context.posting.amount),
      amount_tolerance(posting_context.posting.amount)
    )
  end

  defp max_candidate_amount(posting_context) do
    Decimal.add(
      abs_decimal(posting_context.posting.amount),
      amount_tolerance(posting_context.posting.amount)
    )
  end

  defp abs_decimal(amount), do: Decimal.abs(amount)
end
