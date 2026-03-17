defmodule AurumFinance.Classification.ClassificationRecord do
  @moduledoc """
  Mutable per-transaction classification overlay with per-field provenance.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Classification.Types.StringList
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Transaction

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @required [:transaction_id, :entity_id]
  @optional [
    :category_account_id,
    :category_classified_by,
    :category_manually_overridden,
    :tags,
    :tags_classified_by,
    :tags_manually_overridden,
    :investment_type,
    :investment_type_classified_by,
    :investment_type_manually_overridden,
    :notes,
    :notes_classified_by,
    :notes_manually_overridden
  ]

  schema "classification_records" do
    field :category_classified_by, :map
    field :category_manually_overridden, :boolean, default: false
    field :tags, StringList, default: []
    field :tags_classified_by, :map
    field :tags_manually_overridden, :boolean, default: false
    field :investment_type, :string
    field :investment_type_classified_by, :map
    field :investment_type_manually_overridden, :boolean, default: false
    field :notes, :string
    field :notes_classified_by, :map
    field :notes_manually_overridden, :boolean, default: false

    belongs_to :transaction, Transaction
    belongs_to :entity, Entity
    belongs_to :category_account, Account, foreign_key: :category_account_id

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the classification record changeset with tags and notes validations.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(classification_record, attrs) do
    classification_record
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> validate_tags()
    |> validate_length(:notes,
      max: 2000,
      message:
        Gettext.dgettext(
          AurumFinance.Gettext,
          "errors",
          "error_classification_notes_length_invalid"
        )
    )
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:entity_id)
    |> foreign_key_constraint(:category_account_id)
    |> unique_constraint(:transaction_id, name: :classification_records_transaction_id_index)
  end

  defp validate_tags(changeset) do
    tags = get_field(changeset, :tags, [])

    changeset
    |> maybe_add_tag_count_error(tags)
    |> maybe_add_tag_length_error(tags)
  end

  defp maybe_add_tag_count_error(changeset, tags) when length(tags) <= 20, do: changeset

  defp maybe_add_tag_count_error(changeset, _tags) do
    add_error(
      changeset,
      :tags,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_classification_tags_too_many")
    )
  end

  defp maybe_add_tag_length_error(changeset, tags) do
    if Enum.any?(tags, &(String.length(&1) > 50)) do
      add_error(
        changeset,
        :tags,
        Gettext.dgettext(
          AurumFinance.Gettext,
          "errors",
          "error_classification_tag_length_invalid"
        )
      )
    else
      changeset
    end
  end
end
