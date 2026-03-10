defmodule AurumFinance.Ingestion.CanonicalRowCandidate do
  @moduledoc """
  Parser output for one source row before normalization, dedupe, and validation.
  """

  @enforce_keys [:row_index, :raw_data, :canonical_data]
  defstruct [:row_index, :raw_data, :canonical_data]

  @type t :: %__MODULE__{
          row_index: pos_integer(),
          raw_data: map(),
          canonical_data: map()
        }
end
