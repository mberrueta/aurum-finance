defmodule AurumFinance.Classification.RuleGroup do
  @moduledoc """
  Scoped group of ordered rules used by the classification engine.

  A rule group defines the ownership boundary and merge priority for a set of
  rules that work together as one classification dimension.

  Supported scope types:
  - `:global` for rules visible to every transaction
  - `:entity` for rules tied to one entity
  - `:account` for rules tied to one account

  Rules inside the group are ordered by `position`, while groups themselves are
  ordered by `priority` inside their scope tier.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Classification.Rule
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @scope_types [:global, :entity, :account]

  @type t :: %__MODULE__{}

  @required [:scope_type, :name, :priority]
  @optional [:entity_id, :account_id, :description, :target_fields, :is_active]

  schema "rule_groups" do
    field :scope_type, Ecto.Enum, values: @scope_types
    field :name, :string
    field :description, :string
    field :priority, :integer
    field :target_fields, {:array, :string}, default: []
    field :is_active, :boolean, default: true

    belongs_to :entity, Entity
    belongs_to :account, Account
    has_many :rules, Rule

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the rule group changeset with explicit scope validation.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(rule_group, attrs) do
    rule_group
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:name,
      min: 2,
      max: 160,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_rule_group_name_length_invalid"
        )
    )
    |> validate_number(:priority,
      greater_than: 0,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_rule_group_priority_invalid"
        )
    )
    |> validate_scope_columns()
    |> foreign_key_constraint(:entity_id)
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:name,
      name: :rule_groups_global_name_index,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_rule_group_name_taken_for_scope"
        )
    )
    |> unique_constraint(:name,
      name: :rule_groups_entity_name_index,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_rule_group_name_taken_for_scope"
        )
    )
    |> unique_constraint(:name,
      name: :rule_groups_account_name_index,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_rule_group_name_taken_for_scope"
        )
    )
  end

  @doc """
  Returns the supported scope types.
  """
  @spec scope_types() :: [atom()]
  def scope_types, do: @scope_types

  defp validate_scope_columns(changeset) do
    scope_type = get_field(changeset, :scope_type)
    entity_id = get_field(changeset, :entity_id)
    account_id = get_field(changeset, :account_id)

    case valid_scope_columns?(scope_type, entity_id, account_id) do
      true -> changeset
      false -> add_scope_error(changeset)
    end
  end

  defp valid_scope_columns?(:global, nil, nil), do: true
  defp valid_scope_columns?(:entity, entity_id, nil) when is_binary(entity_id), do: true
  defp valid_scope_columns?(:account, nil, account_id) when is_binary(account_id), do: true
  defp valid_scope_columns?(nil, _entity_id, _account_id), do: true
  defp valid_scope_columns?(_scope_type, _entity_id, _account_id), do: false

  defp add_scope_error(changeset) do
    add_error(
      changeset,
      :scope_type,
      Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_rule_group_scope_invalid")
    )
  end
end
