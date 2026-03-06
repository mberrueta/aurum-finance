defmodule AurumFinance.Entities.Entity do
  @moduledoc """
  Entity is the ownership boundary for accounts, holdings, and ledger data.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @types [:individual, :legal_entity, :trust, :other]

  @type t :: %__MODULE__{}

  @required [:name, :type, :country_code]
  @optional [
    :tax_identifier,
    :fiscal_residency_country_code,
    :default_tax_rate_type,
    :notes,
    :archived_at
  ]

  schema "entities" do
    field :name, :string
    field :type, Ecto.Enum, values: @types
    field :tax_identifier, :string
    field :country_code, :string
    field :fiscal_residency_country_code, :string
    field :default_tax_rate_type, :string
    field :notes, :string
    field :archived_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:name,
      min: 2,
      max: 160,
      message:
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_entity_name_length_invalid")
    )
    |> validate_length(:country_code,
      is: 2,
      message:
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_country_code_length_invalid")
    )
    |> update_change(:country_code, &normalize_to_upper/1)
    |> update_change(:fiscal_residency_country_code, &normalize_to_upper/1)
    |> unique_constraint(:name)
  end

  @spec types() :: [atom()]
  def types, do: @types

  defp normalize_to_upper(value) when is_binary(value), do: String.upcase(value)
  defp normalize_to_upper(value), do: value
end
