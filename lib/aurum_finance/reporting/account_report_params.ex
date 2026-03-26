defmodule AurumFinance.Reporting.AccountReportParams do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Helpers

  @required [:as_of_date]
  @optional [:target_currency_code, :fx_series_id]

  @type t :: %__MODULE__{}

  embedded_schema do
    field :as_of_date, :date
    field :target_currency_code, :string
    field :fx_series_id, :string
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(params, attrs) do
    params
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> update_change(:target_currency_code, &normalize_target_currency_code/1)
    |> update_change(:fx_series_id, &normalize_fx_series_id/1)
    |> validate_target_currency_code()
    |> validate_conversion_pair()
  end

  defp validate_target_currency_code(changeset) do
    changeset
    |> validate_length(:target_currency_code,
      is: 3,
      message:
        Gettext.dgettext(
          AurumFinance.Gettext,
          "errors",
          "error_account_currency_code_length_invalid"
        )
    )
    |> validate_format(:target_currency_code, ~r/^[A-Z]{3}$/,
      message:
        Gettext.dgettext(
          AurumFinance.Gettext,
          "errors",
          "error_account_currency_code_format_invalid"
        )
    )
  end

  defp validate_conversion_pair(changeset) do
    validate_conversion_pair(
      changeset,
      get_field(changeset, :target_currency_code),
      get_field(changeset, :fx_series_id)
    )
  end

  defp validate_conversion_pair(changeset, nil, nil), do: changeset

  defp validate_conversion_pair(changeset, nil, _fx_series_id) do
    add_error(
      changeset,
      :target_currency_code,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
  end

  defp validate_conversion_pair(changeset, _target_currency_code, nil) do
    add_error(
      changeset,
      :fx_series_id,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
  end

  defp validate_conversion_pair(changeset, _target_currency_code, _fx_series_id), do: changeset

  defp normalize_target_currency_code(nil), do: nil

  defp normalize_target_currency_code(value),
    do: value |> normalize_value() |> Helpers.normalize_to_upper()

  defp normalize_fx_series_id(nil), do: nil
  defp normalize_fx_series_id(value), do: normalize_value(value)

  defp normalize_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> normalize_trimmed_value()
  end

  defp normalize_value(value), do: value
  defp normalize_trimmed_value(""), do: nil
  defp normalize_trimmed_value(value), do: value
end
