defmodule AurumFinance.Classification.Engine.ProposedChange do
  @moduledoc """
  Explainable proposal emitted by the pure classification engine for one field.

  `status` captures how the merge pass treated the proposal:

  - `:proposed` - accepted and field claim won
  - `:protected` - skipped because the current field is manually protected
  - `:skipped_claimed` - skipped because a higher-precedence proposal already
    claimed the field
  - `:invalid` - skipped because the rule expression or action payload was not
    evaluable
  """

  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleAction
  alias AurumFinance.Classification.RuleGroup

  @type status :: :proposed | :protected | :skipped_claimed | :invalid
  @type field :: :category | :tags | :investment_type | :notes

  @enforce_keys [:field, :status, :rule_group, :rule]
  defstruct field: nil,
            status: nil,
            current_value: nil,
            proposed_value: nil,
            currently_overridden?: false,
            rule_group: nil,
            rule: nil,
            actions: [],
            reason: nil

  @type t :: %__MODULE__{
          field: field(),
          status: status(),
          current_value: term(),
          proposed_value: term(),
          currently_overridden?: boolean(),
          rule_group: RuleGroup.t(),
          rule: Rule.t(),
          actions: [RuleAction.t()],
          reason: atom() | nil
        }
end
