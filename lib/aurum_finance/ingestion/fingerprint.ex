defmodule AurumFinance.Ingestion.Fingerprint do
  @moduledoc """
  Stable exact-match fingerprint builder for normalized canonical row data.

  The fingerprint is account-agnostic by design. Account scoping belongs to the
  duplicate lookup layer, not to the hash itself.
  """

  alias Decimal, as: DecimalValue

  @doc """
  Builds a stable SHA-256 fingerprint from normalized canonical row data.

  The input must already be normalized. This function does not apply fuzzy
  matching or parser-specific branching.

  ## Examples

      iex> AurumFinance.Ingestion.Fingerprint.build(%{
      ...>   posted_on: ~D[2026-03-10],
      ...>   amount: Decimal.new("-4.50"),
      ...>   currency: "USD",
      ...>   description: "coffee"
      ...> })
      "7ee69f191c2b5fc7050f50e55bafda60192002457f233feeabe08018d17e3ff1"
  """
  @spec build(map()) :: String.t()
  def build(canonical_data) when is_map(canonical_data) do
    canonical_data
    |> canonical_term()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(%DecimalValue{} = value),
    do: {:decimal, Decimal.normalize(value) |> Decimal.to_string(:normal)}

  defp canonical_term(%Date{} = value), do: {:date, Date.to_iso8601(value)}

  defp canonical_term(%NaiveDateTime{} = value),
    do: {:naive_datetime, NaiveDateTime.to_iso8601(value)}

  defp canonical_term(%DateTime{} = value), do: {:datetime, DateTime.to_iso8601(value)}

  defp canonical_term(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested_value} -> {to_key(key), canonical_term(nested_value)} end)
    |> Enum.sort_by(fn {key, _nested_value} -> key end)
  end

  defp canonical_term(value) when is_list(value), do: Enum.map(value, &canonical_term/1)

  defp canonical_term(value) when is_atom(value), do: {:atom, Atom.to_string(value)}
  defp canonical_term(value), do: value

  defp to_key(key) when is_atom(key), do: Atom.to_string(key)
  defp to_key(key), do: key
end
