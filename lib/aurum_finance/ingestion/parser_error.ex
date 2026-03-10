defmodule AurumFinance.Ingestion.ParserError do
  @moduledoc """
  Structured parser error returned by the ingestion parser boundary.
  """

  defexception [:reason, :message, details: %{}]

  @type t :: %__MODULE__{
          reason: atom(),
          message: String.t(),
          details: map()
        }
end
