defmodule AurumFinance.Fx.FxSeries do
  @moduledoc """
  Named FX rate series linking a currency pair to a source of daily exchange
  rates.

  Each series is global (not entity-scoped) and carries identity fields that
  are immutable after creation: `base_currency_code`, `quote_currency_code`,
  `source_kind`, and `provider_module`. The `slug` is auto-generated from
  `name` at creation via `AurumFinance.Helpers.slugify/1` and is also immutable.

  Mutable fields are `name`, `description`, `from_date`, and `to_date`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Fx.Provider
  alias AurumFinance.Helpers

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @source_kinds [:csv_upload, :provider_module]
  @sync_statuses [:active, :error, :stopped]
  @supported_providers ["bcb_ptax", "frankfurter_ecb"]
  @create_required [:name, :base_currency_code, :quote_currency_code, :from_date, :source_kind]
  @create_optional [:description, :to_date, :provider_module]

  @update_required [:name, :from_date]
  @update_optional [:description, :to_date]

  schema "fx_series" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :base_currency_code, :string
    field :quote_currency_code, :string
    field :from_date, :date
    field :to_date, :date
    field :source_kind, Ecto.Enum, values: @source_kinds
    field :provider_module, :string
    field :sync_status, Ecto.Enum, values: @sync_statuses, default: :active
    field :sync_message, :string
    field :last_sync_attempted_at, :utc_datetime_usec

    # Virtual fields populated by list/filter queries
    field :row_count, :integer, virtual: true, default: 0
    field :last_ingested_date, :date, virtual: true
    field :inverted?, :boolean, virtual: true, default: false

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for creating a new FX series.

  The `slug` is auto-generated from `name` and identity fields are set once.
  `provider_module` is required when `source_kind` is `:provider_module`.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Fx.FxSeries.create_changeset(
      ...>     %AurumFinance.Fx.FxSeries{},
      ...>     %{
      ...>       name: "BCB PTAX USD/BRL",
      ...>       base_currency_code: "usd",
      ...>       quote_currency_code: "brl",
      ...>       from_date: ~D[2024-01-01],
      ...>       source_kind: :provider_module,
      ...>       provider_module: "bcb_ptax"
      ...>     }
      ...>   )
      iex> changeset.valid?
      true
      iex> Ecto.Changeset.get_field(changeset, :slug)
      "bcb-ptax-usdbrl"
      iex> Ecto.Changeset.get_field(changeset, :base_currency_code)
      "USD"
  """
  @spec create_changeset(t(), map()) :: Ecto.Changeset.t()
  def create_changeset(series, attrs) do
    series
    |> cast(attrs, @create_required ++ @create_optional)
    |> validate_required(@create_required,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> update_change(:base_currency_code, &Helpers.normalize_to_upper/1)
    |> update_change(:quote_currency_code, &Helpers.normalize_to_upper/1)
    |> validate_currency_codes()
    |> validate_date_range()
    |> validate_provider_module()
    |> validate_provider_currency_pair()
    |> put_slug()
    |> unique_constraint(:slug, name: :fx_series_slug_index)
  end

  @doc """
  Builds a changeset for updating an existing FX series.

  Only mutable fields (`name`, `description`, `from_date`, `to_date`) can be
  changed. Identity fields are rejected.

  ## Examples

      iex> series = %AurumFinance.Fx.FxSeries{
      ...>   id: Ecto.UUID.generate(),
      ...>   name: "Old name",
      ...>   slug: "old-name",
      ...>   base_currency_code: "USD",
      ...>   quote_currency_code: "BRL",
      ...>   from_date: ~D[2024-01-01],
      ...>   source_kind: :csv_upload
      ...> }
      iex> changeset =
      ...>   AurumFinance.Fx.FxSeries.update_changeset(series, %{
      ...>     name: "New name",
      ...>     description: "Updated"
      ...>   })
      iex> changeset.valid?
      true
  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(series, attrs) do
    series
    |> cast(attrs, @update_required ++ @update_optional)
    |> validate_required(@update_required,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> validate_date_range()
  end

  @doc """
  Returns the supported source kinds.

  ## Examples

      iex> AurumFinance.Fx.FxSeries.source_kinds()
      [:csv_upload, :provider_module]
  """
  @spec source_kinds() :: [atom()]
  def source_kinds, do: @source_kinds

  @doc """
  Returns the list of supported provider module identifiers.

  ## Examples

      iex> "bcb_ptax" in AurumFinance.Fx.FxSeries.supported_providers()
      true
  """
  @spec supported_providers() :: [String.t()]
  def supported_providers, do: @supported_providers

  @doc """
  Returns the common currency options used by the UI when no provider-specific
  restriction applies.
  """
  @spec common_currency_options() :: [{String.t(), String.t()}]
  def common_currency_options do
    Provider.common_currency_codes()
    |> Enum.map(&{&1, &1})
  end

  @doc """
  Returns allowed base currency options for a provider-backed series.
  """
  @spec base_currency_options(String.t() | nil) :: [{String.t(), String.t()}]
  def base_currency_options(provider_identifier) do
    provider_identifier
    |> Provider.base_currency_codes()
    |> Enum.map(&{&1, &1})
  end

  @doc """
  Returns allowed quote currency options for a provider-backed series.
  """
  @spec quote_currency_options(String.t() | nil) :: [{String.t(), String.t()}]
  def quote_currency_options(provider_identifier) do
    provider_identifier
    |> Provider.quote_currency_codes()
    |> Enum.map(&{&1, &1})
  end

  defp put_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :slug, Helpers.slugify(name))
    end
  end

  defp validate_currency_codes(changeset) do
    changeset
    |> validate_length(:base_currency_code,
      is: 3,
      message:
        Gettext.dgettext(AurumFinance.Gettext, "errors", "error_currency_code_length_invalid")
    )
    |> validate_format(:base_currency_code, ~r/^[A-Z]{3}$/,
      message:
        Gettext.dgettext(AurumFinance.Gettext, "errors", "error_currency_code_format_invalid")
    )
    |> validate_length(:quote_currency_code,
      is: 3,
      message:
        Gettext.dgettext(AurumFinance.Gettext, "errors", "error_currency_code_length_invalid")
    )
    |> validate_format(:quote_currency_code, ~r/^[A-Z]{3}$/,
      message:
        Gettext.dgettext(AurumFinance.Gettext, "errors", "error_currency_code_format_invalid")
    )
    |> validate_currencies_differ()
  end

  defp validate_currencies_differ(changeset) do
    base = get_field(changeset, :base_currency_code)
    quote_code = get_field(changeset, :quote_currency_code)

    if base && quote_code && base == quote_code do
      add_error(
        changeset,
        :quote_currency_code,
        Gettext.dgettext(AurumFinance.Gettext, "errors", "error_currencies_must_differ")
      )
    else
      changeset
    end
  end

  defp validate_date_range(changeset) do
    from_date = get_field(changeset, :from_date)
    to_date = get_field(changeset, :to_date)

    if from_date && to_date && Date.compare(to_date, from_date) == :lt do
      add_error(
        changeset,
        :to_date,
        Gettext.dgettext(AurumFinance.Gettext, "errors", "error_to_date_before_from_date")
      )
    else
      changeset
    end
  end

  defp validate_provider_module(changeset) do
    source_kind = get_field(changeset, :source_kind)
    provider = get_field(changeset, :provider_module)

    changeset
    |> validate_provider_required(source_kind, provider)
    |> validate_provider_supported(source_kind, provider)
    |> validate_provider_absent(source_kind, provider)
  end

  defp validate_provider_required(changeset, :provider_module, nil) do
    add_error(
      changeset,
      :provider_module,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
  end

  defp validate_provider_required(changeset, _source_kind, _provider), do: changeset

  defp validate_provider_supported(changeset, :provider_module, provider)
       when is_binary(provider) do
    if provider in @supported_providers do
      changeset
    else
      add_error(
        changeset,
        :provider_module,
        Gettext.dgettext(AurumFinance.Gettext, "errors", "error_provider_not_supported")
      )
    end
  end

  defp validate_provider_supported(changeset, _source_kind, _provider), do: changeset

  defp validate_provider_absent(changeset, :csv_upload, provider) when not is_nil(provider) do
    add_error(
      changeset,
      :provider_module,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "error_provider_not_allowed_for_csv")
    )
  end

  defp validate_provider_absent(changeset, _source_kind, _provider), do: changeset

  defp validate_provider_currency_pair(changeset) do
    source_kind = get_field(changeset, :source_kind)
    provider = get_field(changeset, :provider_module)
    base_currency_code = get_field(changeset, :base_currency_code)
    quote_currency_code = get_field(changeset, :quote_currency_code)

    validate_provider_currency_pair(
      changeset,
      source_kind,
      provider,
      base_currency_code,
      quote_currency_code
    )
  end

  defp validate_provider_currency_pair(
         changeset,
         :provider_module,
         provider,
         base_currency_code,
         quote_currency_code
       )
       when is_binary(provider) and is_binary(base_currency_code) and
              is_binary(quote_currency_code) do
    if Provider.compatible_currency_pair?(provider, base_currency_code, quote_currency_code) do
      changeset
    else
      add_error(
        changeset,
        :quote_currency_code,
        Gettext.dgettext(
          AurumFinance.Gettext,
          "errors",
          "error_fx_provider_currency_pair_not_supported"
        )
      )
    end
  end

  defp validate_provider_currency_pair(
         changeset,
         _source_kind,
         _provider,
         _base_currency_code,
         _quote_currency_code
       ),
       do: changeset
end
