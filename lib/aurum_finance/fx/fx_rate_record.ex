defmodule AurumFinance.Fx.FxRateRecord do
  @moduledoc """
  A single daily exchange rate observation within an `FxSeries`.

  Each record stores one `rate_value` for one `effective_date`. The combination
  `(fx_series_id, effective_date)` is unique per the DB constraint.

  `rate_value` must be strictly positive and is stored with precision 24,
  scale 12, sufficient for most FX rate representations including inverted
  minor-currency pairs.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Fx.FxSeries

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @required [:fx_series_id, :effective_date, :rate_value]
  @optional []

  schema "fx_rate_records" do
    field :effective_date, :date
    field :rate_value, :decimal

    belongs_to :fx_series, FxSeries

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for a rate record row.

  Validates that `rate_value` is strictly greater than zero.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Fx.FxRateRecord.changeset(
      ...>     %AurumFinance.Fx.FxRateRecord{},
      ...>     %{
      ...>       fx_series_id: Ecto.UUID.generate(),
      ...>       effective_date: ~D[2026-03-20],
      ...>       rate_value: Decimal.new("5.812345678901")
      ...>     }
      ...>   )
      iex> changeset.valid?
      true

      iex> invalid =
      ...>   AurumFinance.Fx.FxRateRecord.changeset(
      ...>     %AurumFinance.Fx.FxRateRecord{},
      ...>     %{rate_value: Decimal.new("0")}
      ...>   )
      iex> invalid.valid?
      false
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(record, attrs) do
    record
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> validate_rate_value_positive()
    |> foreign_key_constraint(:fx_series_id)
    |> unique_constraint([:fx_series_id, :effective_date],
      name: :fx_rate_records_fx_series_id_effective_date_index
    )
  end

  defp validate_rate_value_positive(changeset) do
    case get_field(changeset, :rate_value) do
      nil ->
        changeset

      rate_value ->
        if Decimal.gt?(rate_value, Decimal.new(0)) do
          changeset
        else
          add_error(
            changeset,
            :rate_value,
            Gettext.dgettext(AurumFinance.Gettext, "errors", "error_rate_value_must_be_positive")
          )
        end
    end
  end
end
