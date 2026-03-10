defmodule AurumFinance.Ingestion.RowNormalizer do
  @moduledoc """
  Deterministic normalization for canonical row data before dedupe.

  This layer is parser-agnostic. It operates on canonical row candidates
  regardless of whether they came from CSV or a future parser implementation.

  The primary API is row-oriented and stream-friendly so async jobs can process
  large imports incrementally instead of materializing every normalized row in
  memory at once.

  Normalization also accepts `opts` so downstream jobs can provide account
  context without coupling the API to a specific parser.
  """

  alias AurumFinance.Helpers
  alias AurumFinance.Ingestion.CanonicalRowCandidate
  alias AurumFinance.Ledger.Account

  @downcased_keys [:description, :normalized_description, :memo, :payee, :narrative, :name]
  @upcased_keys [:currency, :currency_code]

  @type normalize_opt ::
          {:account, Account.t()}
          | {:default_currency, String.t()}
          | {:source_locale, String.t()}

  @doc """
  Returns a lazy stream that normalizes canonical row candidates one by one.

  This is the preferred API for async jobs processing large files.

  ## Examples

      iex> normalized_rows =
      ...>   [
      ...>     %AurumFinance.Ingestion.CanonicalRowCandidate{
      ...>       row_index: 1,
      ...>       raw_data: %{"Description" => " UBER "},
      ...>       canonical_data: %{description: " UBER ", currency: " usd "}
      ...>     }
      ...>   ]
      ...>   |> AurumFinance.Ingestion.RowNormalizer.normalize_rows(
      ...>     account: %AurumFinance.Ledger.Account{currency_code: "USD"}
      ...>   )
      ...>   |> Enum.to_list()
      iex> hd(normalized_rows)
      %AurumFinance.Ingestion.CanonicalRowCandidate{
        row_index: 1,
        raw_data: %{"Description" => " UBER "},
        canonical_data: %{description: "uber", currency: "USD"}
      }
  """
  @spec normalize_rows(Enumerable.t(), [normalize_opt()]) :: Enumerable.t()
  def normalize_rows(rows, opts \\ []) do
    Stream.map(rows, &normalize_candidate(&1, opts))
  end

  defp normalize_candidate(%CanonicalRowCandidate{} = candidate, opts) do
    normalized_data =
      candidate.canonical_data
      |> maybe_put_default_currency(opts)
      |> Enum.map(fn {key, value} -> {key, normalize_field(key, value, opts)} end)
      |> Map.new()

    %{candidate | canonical_data: normalized_data}
  end

  defp normalize_description(value) when is_binary(value),
    do: Helpers.normalize_string(value, case: :lower)

  defp normalize_currency(nil, opts),
    do: normalize_default_currency(default_currency_from_opts(opts))

  defp normalize_currency(value, _opts) when is_binary(value),
    do: Helpers.normalize_string(value, case: :upper)

  defp normalize_field(key, value, _opts) when key in @downcased_keys and is_binary(value),
    do: normalize_description(value)

  defp normalize_field(key, value, opts) when key in @upcased_keys,
    do: normalize_currency(value, opts)

  defp normalize_field(_key, value, _opts) when is_binary(value),
    do: Helpers.normalize_string(value)

  defp normalize_field(_key, value, _opts), do: value

  defp maybe_put_default_currency(%{currency: _currency} = canonical_data, _opts),
    do: canonical_data

  defp maybe_put_default_currency(canonical_data, opts) do
    put_default_currency(canonical_data, default_currency_from_opts(opts))
  end

  defp put_default_currency(canonical_data, nil), do: canonical_data

  defp put_default_currency(canonical_data, currency) do
    Map.put(canonical_data, :currency, normalize_currency(currency, []))
  end

  defp normalize_default_currency(nil), do: nil
  defp normalize_default_currency(currency), do: Helpers.normalize_string(currency, case: :upper)

  defp default_currency_from_opts([{:account, %Account{currency_code: currency_code}} | _rest])
       when is_binary(currency_code) and currency_code != "",
       do: currency_code

  defp default_currency_from_opts(opts), do: Keyword.get(opts, :default_currency)
end
