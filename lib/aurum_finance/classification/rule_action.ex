defmodule AurumFinance.Classification.RuleAction do
  @moduledoc """
  Embedded action definition stored inside a rule's JSONB payload.

  A rule action describes what classification field should change when a rule
  matches and which operation should be applied to that field.

  Supported fields:
  - `:category`
  - `:tags`
  - `:investment_type`
  - `:notes`

  Supported operations depend on the field:
  - `:category` -> `:set`
  - `:tags` -> `:add`, `:remove`
  - `:investment_type` -> `:set`
  - `:notes` -> `:set`, `:append`
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false

  @fields [:category, :tags, :investment_type, :notes]
  @operations [:set, :add, :remove, :append]

  @type t :: %__MODULE__{}

  @required [:field, :operation, :value]
  @optional []

  embedded_schema do
    field :field, Ecto.Enum, values: @fields
    field :operation, Ecto.Enum, values: @operations
    field :value, :string
  end

  @doc """
  Builds the embedded changeset for one persisted rule action.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(rule_action, attrs) do
    rule_action
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_field_operation_compatibility()
  end

  @doc """
  Returns the supported action fields.
  """
  @spec fields() :: [atom()]
  def fields, do: @fields

  @doc """
  Returns the supported action operations.
  """
  @spec operations() :: [atom()]
  def operations, do: @operations

  defp validate_field_operation_compatibility(changeset) do
    field = get_field(changeset, :field)
    operation = get_field(changeset, :operation)

    if compatible_operation?(field, operation) do
      changeset
    else
      add_error(
        changeset,
        :operation,
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_rule_action_operation_invalid"
        )
      )
    end
  end

  defp compatible_operation?(:category, :set), do: true
  defp compatible_operation?(:tags, operation) when operation in [:add, :remove], do: true
  defp compatible_operation?(:investment_type, :set), do: true
  defp compatible_operation?(:notes, operation) when operation in [:set, :append], do: true
  defp compatible_operation?(nil, _operation), do: true
  defp compatible_operation?(_field, nil), do: true
  defp compatible_operation?(_field, _operation), do: false
end
