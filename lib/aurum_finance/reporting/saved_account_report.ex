defmodule AurumFinance.Reporting.SavedAccountReport do
  @moduledoc """
  Persisted saved account report definition.

  The row stores configuration only. Report output is always derived at read
  time from the underlying account, snapshot, and FX data.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Helpers
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Fx.FxSeries

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @required [:account_id]
  @optional [:target_currency_code, :fx_series_id, :pinned_as_of_date, :convert]

  @type t :: %__MODULE__{}

  schema "saved_account_reports" do
    field :target_currency_code, :string
    field :pinned_as_of_date, :date
    field :convert, :boolean, virtual: true

    belongs_to :account, Account
    belongs_to :fx_series, FxSeries

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for saved account report definitions.

  Conversion is controlled by the virtual `convert` flag:

  - false means native-only and clears conversion fields
  - true requires both target currency and FX series
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(saved_account_report, attrs) do
    saved_account_report
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> update_change(:target_currency_code, &Helpers.normalize_to_upper/1)
    |> normalize_convert_flag()
    |> normalize_conversion_fields()
    |> validate_target_currency_code()
    |> validate_conversion_pair()
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:fx_series_id)
  end

  @doc """
  Returns true when the definition is configured for conversion.

  ## Examples

      iex> report = %AurumFinance.Reporting.SavedAccountReport{
      ...>   target_currency_code: "EUR",
      ...>   fx_series_id: "series-1"
      ...> }
      iex> AurumFinance.Reporting.SavedAccountReport.converted?(report)
      true

      iex> AurumFinance.Reporting.SavedAccountReport.converted?(%AurumFinance.Reporting.SavedAccountReport{})
      false
  """
  @spec converted?(t()) :: boolean()
  def converted?(%__MODULE__{
        target_currency_code: target_currency_code,
        fx_series_id: fx_series_id
      }) do
    is_binary(target_currency_code) and is_binary(fx_series_id)
  end

  def converted?(_), do: false

  @doc """
  Returns true when the definition uses live, unpinned date semantics.

  ## Examples

      iex> AurumFinance.Reporting.SavedAccountReport.live?(%AurumFinance.Reporting.SavedAccountReport{})
      true

      iex> report = %AurumFinance.Reporting.SavedAccountReport{pinned_as_of_date: ~D[2026-03-10]}
      iex> AurumFinance.Reporting.SavedAccountReport.live?(report)
      false
  """
  @spec live?(t()) :: boolean()
  def live?(%__MODULE__{pinned_as_of_date: nil}), do: true
  def live?(_), do: false

  defp normalize_convert_flag(changeset) do
    normalize_convert_flag(changeset, get_field(changeset, :convert))
  end

  defp normalize_convert_flag(changeset, nil) do
    put_change(changeset, :convert, conversion_configured?(changeset.data))
  end

  defp normalize_convert_flag(changeset, value) do
    put_change(changeset, :convert, value)
  end

  defp normalize_conversion_fields(changeset) do
    normalize_conversion_fields(changeset, get_field(changeset, :convert))
  end

  defp normalize_conversion_fields(changeset, false) do
    changeset
    |> put_change(:target_currency_code, nil)
    |> put_change(:fx_series_id, nil)
  end

  defp normalize_conversion_fields(changeset, _value) do
    changeset
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
      get_field(changeset, :convert),
      get_field(changeset, :target_currency_code),
      get_field(changeset, :fx_series_id)
    )
  end

  defp validate_conversion_pair(changeset, false, _target_currency_code, _fx_series_id),
    do: changeset

  defp validate_conversion_pair(changeset, true, nil, nil) do
    required_message =
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")

    changeset
    |> add_error(:target_currency_code, required_message)
    |> add_error(:fx_series_id, required_message)
  end

  defp validate_conversion_pair(changeset, true, nil, _fx_series_id) do
    required_message =
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")

    add_error(changeset, :target_currency_code, required_message)
  end

  defp validate_conversion_pair(changeset, true, _target_currency_code, nil) do
    required_message =
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")

    add_error(changeset, :fx_series_id, required_message)
  end

  defp validate_conversion_pair(changeset, true, _target_currency_code, _fx_series_id),
    do: changeset

  defp conversion_configured?(%__MODULE__{
         target_currency_code: target_currency_code,
         fx_series_id: fx_series_id
       }) do
    is_binary(target_currency_code) or is_binary(fx_series_id)
  end

  defp conversion_configured?(_), do: false
end
