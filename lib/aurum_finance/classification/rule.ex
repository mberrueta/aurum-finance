defmodule AurumFinance.Classification.Rule do
  @moduledoc """
  One ordered condition-action rule that belongs to a rule group.

  A rule combines:
  - an `expression` string in the AurumFinance DSL
  - one or more embedded `actions`
  - execution controls such as `position`, `is_active`, and `stop_processing`

  Rules are evaluated in group order, and `stop_processing` controls whether the
  group stops after the first matching rule.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Classification.RuleAction
  alias AurumFinance.Classification.RuleGroup

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @required [:rule_group_id, :name, :position]
  @optional [:description, :is_active, :stop_processing, :expression]

  schema "rules" do
    field :name, :string
    field :description, :string
    field :position, :integer
    field :is_active, :boolean, default: true
    field :stop_processing, :boolean, default: true
    field :expression, :string

    belongs_to :rule_group, RuleGroup
    embeds_many :actions, RuleAction, on_replace: :delete

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the rule changeset with validated embedded actions.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Classification.Rule.changeset(
      ...>     %AurumFinance.Classification.Rule{},
      ...>     %{
      ...>       rule_group_id: Ecto.UUID.generate(),
      ...>       name: "Uber",
      ...>       position: 1,
      ...>       expression: ~s|description contains "Uber"|,
      ...>       actions: [%{field: :tags, operation: :add, value: "ride"}]
      ...>     }
      ...>   )
      iex> changeset.valid?
      true
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(rule, attrs) do
    rule
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:name,
      min: 2,
      max: 160,
      message:
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_name_length_invalid")
    )
    |> validate_number(:position,
      greater_than: 0,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_position_invalid")
    )
    |> validate_expression_present()
    |> cast_embed(:actions, required: true, with: &RuleAction.changeset/2)
    |> validate_actions_present()
    |> foreign_key_constraint(:rule_group_id)
  end

  defp validate_expression_present(changeset) do
    expression =
      changeset
      |> get_field(:expression)
      |> normalize_expression()

    if is_binary(expression) and expression != "" do
      put_change(changeset, :expression, expression)
    else
      add_error(
        changeset,
        :expression,
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_expression_required")
      )
    end
  end

  defp validate_actions_present(changeset) do
    case get_field(changeset, :actions, []) do
      [] ->
        add_error(
          changeset,
          :actions,
          Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_actions_required")
        )

      _actions ->
        changeset
    end
  end

  defp normalize_expression(value) when is_binary(value), do: String.trim(value)
  defp normalize_expression(value), do: value
end
