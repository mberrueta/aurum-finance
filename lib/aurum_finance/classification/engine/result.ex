defmodule AurumFinance.Classification.Engine.Result do
  @moduledoc """
  Pure evaluation result for one transaction.

  The engine never writes to the database. Instead it returns a result struct per
  transaction with:

  - the input `transaction`
  - `matched_groups` and `matched_rules` for explainability
  - `proposed_changes` describing accepted, protected, skipped, or invalid field
    proposals
  - `claimed_fields` showing which classification fields were won during the
    first-writer merge pass
  - `no_match?` set only when no active rule matched
  """

  alias AurumFinance.Classification.Engine.ProposedChange
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleGroup

  @enforce_keys [:transaction]
  defstruct transaction: nil,
            matched_groups: [],
            matched_rules: [],
            proposed_changes: [],
            claimed_fields: MapSet.new(),
            no_match?: true

  @type matched_group :: %{
          rule_group: RuleGroup.t(),
          matched_rules: [Rule.t()]
        }

  @type t :: %__MODULE__{
          transaction: term(),
          matched_groups: [matched_group()],
          matched_rules: [Rule.t()],
          proposed_changes: [ProposedChange.t()],
          claimed_fields: MapSet.t(atom()),
          no_match?: boolean()
        }
end
