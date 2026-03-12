defmodule AurumFinance.Reconciliation.MatchCandidateScorer do
  @moduledoc """
  Scores one imported-row candidate against one posting for reconciliation
  assistance.

  This module exists to keep score calibration separate from candidate
  retrieval. It converts already scoped imported-row evidence into the stable
  backend contract used by reconciliation candidate inspection:

  - normalized heuristic `score` in the range `0.0..1.0`
  - stable qualitative `match_band`
  - machine-readable `signals`
  - human-usable `reasons`

  The scoring model is intentionally conservative:

  - amount matters most
  - date matters second
  - description similarity is only supportive

  Description similarity must never rescue a weak amount/date candidate into a
  strong match band. This keeps noisy institution descriptions from dominating
  the ranking.
  """

  @amount_weight 0.55
  @date_weight 0.30
  @description_weight 0.15

  @near_match_threshold 0.65
  @weak_match_threshold 0.45
  @close_amount_threshold 0.80
  @near_amount_threshold 0.50
  @same_day_threshold 0.50
  @near_day_threshold 0.25
  @exact_amount Decimal.new("0")

  @doc """
  Scores one imported-row candidate against a posting context.

  Expected `posting_context` shape:

  - `:posting` - ledger posting struct
  - `:transaction_date` - posting transaction date
  - `:transaction_description` - posting transaction description

  This function is pure and side-effect free. It does not persist matches,
  clear postings, or mutate reconciliation state.

  ## Examples

      iex> posting_context = %{
      ...>   posting: %AurumFinance.Ledger.Posting{
      ...>     id: "posting-1",
      ...>     amount: Decimal.new("-20.00")
      ...>   },
      ...>   transaction_date: ~D[2026-03-02],
      ...>   transaction_description: "Fuel"
      ...> }
      iex> imported_row = %AurumFinance.Ingestion.ImportedRow{
      ...>   id: "row-1",
      ...>   imported_file_id: "file-1",
      ...>   posted_on: ~D[2026-03-02],
      ...>   amount: Decimal.new("-20.00"),
      ...>   description: "Fuel purchase",
      ...>   normalized_description: "fuel purchase"
      ...> }
      iex> candidate =
      ...>   AurumFinance.Reconciliation.MatchCandidateScorer.score(
      ...>     posting_context,
      ...>     imported_row
      ...>   )
      iex> %{
      ...>   posting_id: "posting-1",
      ...>   imported_row_id: "row-1",
      ...>   imported_file_id: "file-1",
      ...>   score: score,
      ...>   match_band: :exact_match,
      ...>   reasons: reasons,
      ...>   signals: %{
      ...>     amount_exact: true,
      ...>     date_distance_days: 0
      ...>   },
      ...>   imported_row: %AurumFinance.Ingestion.ImportedRow{}
      ...> } = candidate
      iex> is_float(score) and score >= 0.0 and score <= 1.0 and :exact_amount in reasons
      true
  """
  @spec score(map(), map(), keyword()) :: map()
  def score(posting_context, imported_row, _opts \\ []) do
    signals =
      posting_context
      |> build_signals(imported_row)

    score =
      signals
      |> weighted_score()

    %{
      posting_id: posting_context.posting.id,
      imported_row_id: imported_row.id,
      imported_file_id: imported_row.imported_file_id,
      score: Float.round(score, 4),
      match_band: classify_match_band(signals, score),
      reasons: reasons(signals),
      signals: public_signals(signals),
      imported_row: imported_row
    }
  end

  defp build_signals(posting_context, imported_row) do
    amount_absolute_distance = amount_absolute_distance(posting_context, imported_row)
    amount_relative_distance = amount_relative_distance(posting_context, amount_absolute_distance)
    date_distance_days = date_distance_days(posting_context, imported_row)
    description_similarity = description_similarity(posting_context, imported_row)

    %{
      amount_exact: Decimal.equal?(amount_absolute_distance, @exact_amount),
      amount_absolute_distance: amount_absolute_distance,
      amount_relative_distance: amount_relative_distance,
      amount_score: amount_score(amount_relative_distance),
      date_distance_days: date_distance_days,
      date_score: date_score(date_distance_days),
      description_similarity: description_similarity
    }
  end

  defp public_signals(signals) do
    %{
      amount_exact: signals.amount_exact,
      amount_absolute_distance: signals.amount_absolute_distance,
      amount_relative_distance: signals.amount_relative_distance,
      date_distance_days: signals.date_distance_days,
      description_similarity: Float.round(signals.description_similarity, 4)
    }
  end

  defp weighted_score(signals) do
    signals.amount_score * @amount_weight +
      signals.date_score * @date_weight +
      signals.description_similarity * @description_weight
  end

  defp classify_match_band(signals, score) do
    cond do
      exact_match?(signals) ->
        :exact_match

      near_match?(signals, score) ->
        :near_match

      weak_match?(signals, score) ->
        :weak_match

      true ->
        :below_threshold
    end
  end

  defp exact_match?(signals) do
    signals.amount_exact and signals.date_score == 1.0
  end

  defp near_match?(signals, score) do
    signals.amount_score >= @close_amount_threshold and
      signals.date_score >= @same_day_threshold and
      score >= @near_match_threshold
  end

  defp weak_match?(signals, score) do
    signals.amount_score >= @near_amount_threshold and
      signals.date_score >= @near_day_threshold and
      score >= @weak_match_threshold
  end

  defp reasons(signals) do
    []
    |> maybe_add_reason(signals.amount_exact, :exact_amount)
    |> maybe_add_reason(not signals.amount_exact, :close_amount)
    |> maybe_add_reason(signals.date_distance_days == 0, :same_day)
    |> maybe_add_reason(signals.date_distance_days in [1, 2], :near_date)
    |> maybe_add_reason(signals.description_similarity >= 0.75, :description_similarity)
  end

  defp maybe_add_reason(reasons, true, reason), do: [reason | reasons]
  defp maybe_add_reason(reasons, false, _reason), do: reasons

  defp amount_absolute_distance(posting_context, imported_row) do
    imported_row.amount
    |> Decimal.abs()
    |> Decimal.sub(Decimal.abs(posting_context.posting.amount))
    |> Decimal.abs()
  end

  defp amount_relative_distance(posting_context, amount_absolute_distance) do
    amount_absolute_distance
    |> Decimal.div(decimal_denominator(posting_context.posting.amount))
    |> Decimal.to_float()
  end

  defp date_distance_days(posting_context, imported_row) do
    Date.diff(imported_row.posted_on, posting_context.transaction_date) |> abs()
  end

  defp amount_score(relative_distance) when relative_distance == 0.0, do: 1.0

  defp amount_score(relative_distance) when relative_distance <= 0.10 do
    max(0.8, 1.0 - relative_distance)
  end

  defp amount_score(relative_distance) when relative_distance <= 0.20 do
    max(0.5, 0.9 - relative_distance * 2)
  end

  defp amount_score(_relative_distance), do: 0.0

  defp date_score(0), do: 1.0
  defp date_score(1), do: 0.75
  defp date_score(2), do: 0.5
  defp date_score(_distance_days), do: 0.0

  defp description_similarity(posting_context, imported_row) do
    posting_context.transaction_description
    |> normalize_description()
    |> jaro_similarity(imported_row)
  end

  defp jaro_similarity("", _imported_row), do: 0.0

  defp jaro_similarity(normalized_transaction_description, imported_row) do
    imported_row
    |> imported_row_description()
    |> normalize_description()
    |> jaro_similarity_result(normalized_transaction_description)
  end

  defp jaro_similarity_result("", _normalized_transaction_description), do: 0.0

  defp jaro_similarity_result(
         normalized_imported_row_description,
         normalized_transaction_description
       ) do
    String.jaro_distance(normalized_transaction_description, normalized_imported_row_description)
  end

  defp imported_row_description(imported_row) do
    imported_row.normalized_description || imported_row.description || ""
  end

  defp normalize_description(nil), do: ""

  defp normalize_description(description) do
    description
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/u, " ")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp decimal_denominator(amount) do
    case Decimal.compare(Decimal.abs(amount), Decimal.new("0.01")) do
      :lt -> Decimal.new("0.01")
      _other -> Decimal.abs(amount)
    end
  end
end
