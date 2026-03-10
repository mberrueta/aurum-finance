defmodule AurumFinance.Ingestion.ParsedImport do
  @moduledoc """
  Parser result for one imported source file.
  """

  alias AurumFinance.Ingestion.CanonicalRowCandidate

  @enforce_keys [:format, :row_count, :rows, :warnings]
  defstruct [:format, :row_count, :rows, :warnings]

  @type t :: %__MODULE__{
          format: atom(),
          row_count: non_neg_integer(),
          rows: [CanonicalRowCandidate.t()],
          warnings: [String.t()]
        }
end
