defmodule AurumFinance.Ledger.Account do
  @moduledoc """
  Canonical internal ledger account model.

  `Account` is not limited to institution-backed containers. The same schema is
  used for three important account families:

  - institution-backed accounts: bank, broker, wallet, cash, credit, loan
  - category accounts: income and expense ledger accounts used for classification
    and reporting
  - system-managed accounts: technical ledger accounts such as opening balances
    and FX/trading support accounts

  The internal semantics stay ledger-first and double-entry driven:

  - `account_type` controls accounting behavior and normal balance
  - `operational_subtype` refines workflow meaning for asset/liability accounts
  - `management_group` controls how the account is grouped for management surfaces
  - `currency_code` defines the account's native currency
  - `entity_id` keeps the account inside one ownership boundary

  In the UI these families may be shown separately, but they remain the same
  canonical ledger entity underneath.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Entities.Entity

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @account_types [:asset, :liability, :equity, :income, :expense]
  @operational_subtypes [
    :bank_checking,
    :bank_savings,
    :cash,
    :brokerage_cash,
    :brokerage_securities,
    :crypto_wallet,
    :credit_card,
    :loan,
    :other_asset,
    :other_liability
  ]
  @management_groups [:institution, :category, :system_managed]
  @institution_account_types [:asset, :liability]
  @institution_operational_subtypes @operational_subtypes
  @category_account_types [:income, :expense]
  @immutable_fields [
    :entity_id,
    :account_type,
    :operational_subtype,
    :management_group,
    :currency_code
  ]

  @type t :: %__MODULE__{}

  @required [:entity_id, :name, :account_type, :management_group, :currency_code]
  @optional [
    :operational_subtype,
    :institution_name,
    :institution_account_ref,
    :notes,
    :archived_at
  ]

  schema "accounts" do
    field :name, :string
    field :account_type, Ecto.Enum, values: @account_types
    field :operational_subtype, Ecto.Enum, values: @operational_subtypes
    field :management_group, Ecto.Enum, values: @management_groups
    field :currency_code, :string
    field :institution_name, :string
    field :institution_account_ref, :string
    field :notes, :string
    field :archived_at, :utc_datetime_usec

    belongs_to :entity, Entity

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the account changeset with canonical validations and immutability rules.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Ledger.Account.changeset(%AurumFinance.Ledger.Account{}, %{
      ...>     entity_id: Ecto.UUID.generate(),
      ...>     name: "Broker cash",
      ...>     account_type: :asset,
      ...>     operational_subtype: :brokerage_cash,
      ...>     management_group: :institution,
      ...>     currency_code: "usd"
      ...>   })
      iex> changeset.valid?
      true
      iex> Ecto.Changeset.get_field(changeset, :currency_code)
      "USD"
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(account, attrs) do
    account
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:name,
      min: 2,
      max: 160,
      message:
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_account_name_length_invalid")
    )
    |> update_change(:currency_code, &normalize_to_upper/1)
    |> validate_length(:currency_code,
      is: 3,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_account_currency_code_length_invalid"
        )
    )
    |> validate_format(:currency_code, ~r/^[A-Z]{3}$/,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_account_currency_code_format_invalid"
        )
    )
    |> validate_operational_subtype()
    |> validate_management_group()
    |> validate_immutable_fields()
    |> foreign_key_constraint(:entity_id)
  end

  @doc """
  Returns the canonical accounting types supported by the ledger.

  ## Examples

      iex> AurumFinance.Ledger.Account.account_types()
      [:asset, :liability, :equity, :income, :expense]
  """
  @spec account_types() :: [atom()]
  def account_types, do: @account_types

  @doc """
  Returns the full operational subtype catalog.

  ## Examples

      iex> :crypto_wallet in AurumFinance.Ledger.Account.operational_subtypes()
      true
  """
  @spec operational_subtypes() :: [atom()]
  def operational_subtypes, do: @operational_subtypes

  @doc """
  Returns the supported management groups.

  ## Examples

      iex> AurumFinance.Ledger.Account.management_groups()
      [:institution, :category, :system_managed]
  """
  @spec management_groups() :: [atom()]
  def management_groups, do: @management_groups

  @doc """
  Returns the account types presented as institution-backed accounts.

  ## Examples

      iex> AurumFinance.Ledger.Account.institution_account_types()
      [:asset, :liability]
  """
  @spec institution_account_types() :: [atom()]
  def institution_account_types, do: @institution_account_types

  @doc """
  Returns the operational subtypes presented as institution-backed accounts in the UI.

  ## Examples

      iex> AurumFinance.Ledger.Account.institution_operational_subtypes()
      [:bank_checking, :bank_savings, :cash, :brokerage_cash, :brokerage_securities, :crypto_wallet, :credit_card, :loan, :other_asset, :other_liability]
  """
  @spec institution_operational_subtypes() :: [atom()]
  def institution_operational_subtypes, do: @institution_operational_subtypes

  @doc """
  Returns the account types presented as category accounts in the UI.

  ## Examples

      iex> AurumFinance.Ledger.Account.category_account_types()
      [:income, :expense]
  """
  @spec category_account_types() :: [atom()]
  def category_account_types, do: @category_account_types

  @doc """
  Returns the normal balance for an account type or account struct.

  ## Examples

      iex> AurumFinance.Ledger.Account.normal_balance(:asset)
      :debit

      iex> AurumFinance.Ledger.Account.normal_balance(%AurumFinance.Ledger.Account{account_type: :income})
      :credit
  """
  @spec normal_balance(atom() | t()) :: :debit | :credit
  def normal_balance(%__MODULE__{account_type: account_type}), do: normal_balance(account_type)
  def normal_balance(account_type) when account_type in [:asset, :expense], do: :debit

  def normal_balance(account_type) when account_type in [:liability, :equity, :income],
    do: :credit

  @doc """
  Returns the valid operational subtypes for an accounting type.

  Income, expense, and equity accounts do not use an operational subtype.

  ## Examples

      iex> AurumFinance.Ledger.Account.operational_subtypes_for_type(:asset)
      [:bank_checking, :bank_savings, :cash, :brokerage_cash, :brokerage_securities, :crypto_wallet, :other_asset]

      iex> AurumFinance.Ledger.Account.operational_subtypes_for_type(:income)
      []
  """
  @spec operational_subtypes_for_type(atom() | nil) :: [atom()]
  def operational_subtypes_for_type(:asset) do
    [
      :bank_checking,
      :bank_savings,
      :cash,
      :brokerage_cash,
      :brokerage_securities,
      :crypto_wallet,
      :other_asset
    ]
  end

  def operational_subtypes_for_type(:liability), do: [:credit_card, :loan, :other_liability]
  def operational_subtypes_for_type(_account_type), do: []

  @doc """
  Maps an operational subtype to its canonical account type.

  ## Examples

      iex> AurumFinance.Ledger.Account.account_type_for_operational_subtype(:credit_card)
      :liability

      iex> AurumFinance.Ledger.Account.account_type_for_operational_subtype(:brokerage_cash)
      :asset

      iex> AurumFinance.Ledger.Account.account_type_for_operational_subtype(nil)
      nil
  """
  @spec account_type_for_operational_subtype(atom() | nil) :: atom() | nil
  def account_type_for_operational_subtype(:bank_checking), do: :asset
  def account_type_for_operational_subtype(:bank_savings), do: :asset
  def account_type_for_operational_subtype(:cash), do: :asset
  def account_type_for_operational_subtype(:brokerage_cash), do: :asset
  def account_type_for_operational_subtype(:brokerage_securities), do: :asset
  def account_type_for_operational_subtype(:crypto_wallet), do: :asset
  def account_type_for_operational_subtype(:credit_card), do: :liability
  def account_type_for_operational_subtype(:loan), do: :liability
  def account_type_for_operational_subtype(:other_asset), do: :asset
  def account_type_for_operational_subtype(:other_liability), do: :liability
  def account_type_for_operational_subtype(_operational_subtype), do: nil

  @doc """
  Returns true when the account belongs to the institution management group.

  ## Examples

      iex> AurumFinance.Ledger.Account.institution_account?(%AurumFinance.Ledger.Account{account_type: :asset, operational_subtype: :bank_checking, management_group: :institution})
      true

      iex> AurumFinance.Ledger.Account.institution_account?(%AurumFinance.Ledger.Account{account_type: :income, operational_subtype: nil, management_group: :category})
      false
  """
  @spec institution_account?(t()) :: boolean()
  def institution_account?(%__MODULE__{
        management_group: :institution,
        account_type: account_type,
        operational_subtype: operational_subtype
      }) do
    not is_nil(operational_subtype) and account_type in @institution_account_types
  end

  def institution_account?(%__MODULE__{}), do: false

  @doc """
  Returns true when the account belongs to the category management group.

  ## Examples

      iex> AurumFinance.Ledger.Account.category_account?(%AurumFinance.Ledger.Account{account_type: :expense, operational_subtype: nil, management_group: :category})
      true

      iex> AurumFinance.Ledger.Account.category_account?(%AurumFinance.Ledger.Account{account_type: :asset, operational_subtype: :cash, management_group: :institution})
      false
  """
  @spec category_account?(t()) :: boolean()
  def category_account?(%__MODULE__{
        management_group: :category,
        account_type: account_type,
        operational_subtype: nil
      }) do
    account_type in @category_account_types
  end

  def category_account?(%__MODULE__{}), do: false

  @doc """
  Returns true when the account belongs to the system-managed management group.

  ## Examples

      iex> AurumFinance.Ledger.Account.system_managed_account?(%AurumFinance.Ledger.Account{account_type: :equity, operational_subtype: nil, management_group: :system_managed})
      true

      iex> AurumFinance.Ledger.Account.system_managed_account?(%AurumFinance.Ledger.Account{account_type: :liability, operational_subtype: :loan, management_group: :institution})
      false
  """
  @spec system_managed_account?(t()) :: boolean()
  def system_managed_account?(%__MODULE__{
        management_group: :system_managed,
        account_type: :equity,
        operational_subtype: nil
      }),
      do: true

  def system_managed_account?(%__MODULE__{}), do: false

  @doc """
  Returns the effective management group for an account.

  This validates the explicit `management_group` field against the canonical
  ledger attributes and returns `:unknown` when they are inconsistent.

  ## Examples

      iex> AurumFinance.Ledger.Account.management_group(%AurumFinance.Ledger.Account{account_type: :asset, operational_subtype: :cash, management_group: :institution})
      :institution

      iex> AurumFinance.Ledger.Account.management_group(%AurumFinance.Ledger.Account{account_type: :income, operational_subtype: nil, management_group: :category})
      :category

      iex> AurumFinance.Ledger.Account.management_group(%AurumFinance.Ledger.Account{account_type: :equity, operational_subtype: nil, management_group: :system_managed})
      :system_managed

      iex> AurumFinance.Ledger.Account.management_group(%AurumFinance.Ledger.Account{account_type: :asset, operational_subtype: nil, management_group: :institution})
      :unknown
  """
  @spec management_group(t()) :: :institution | :category | :system_managed | :unknown
  def management_group(%__MODULE__{} = account) do
    cond do
      institution_account?(account) -> :institution
      category_account?(account) -> :category
      system_managed_account?(account) -> :system_managed
      true -> :unknown
    end
  end

  defp validate_operational_subtype(changeset) do
    account_type = get_field(changeset, :account_type)
    operational_subtype = get_field(changeset, :operational_subtype)
    mapped_account_type = account_type_for_operational_subtype(operational_subtype)

    cond do
      account_type in [:asset, :liability] and is_nil(operational_subtype) ->
        add_error(
          changeset,
          :operational_subtype,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_account_operational_subtype_required"
          )
        )

      account_type in [:income, :expense, :equity] and not is_nil(operational_subtype) ->
        add_error(
          changeset,
          :operational_subtype,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_account_operational_subtype_not_allowed"
          )
        )

      not is_nil(operational_subtype) and mapped_account_type != account_type ->
        add_error(
          changeset,
          :operational_subtype,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_account_operational_subtype_invalid_for_type"
          )
        )

      true ->
        changeset
    end
  end

  defp validate_management_group(changeset) do
    account_type = get_field(changeset, :account_type)
    operational_subtype = get_field(changeset, :operational_subtype)
    management_group = get_field(changeset, :management_group)

    cond do
      management_group == :institution and
          not (account_type in @institution_account_types and not is_nil(operational_subtype)) ->
        add_management_group_error(changeset)

      management_group == :category and
          not (account_type in @category_account_types and is_nil(operational_subtype)) ->
        add_management_group_error(changeset)

      management_group == :system_managed and
          not (account_type == :equity and is_nil(operational_subtype)) ->
        add_management_group_error(changeset)

      true ->
        changeset
    end
  end

  defp add_management_group_error(changeset) do
    add_error(
      changeset,
      :management_group,
      Gettext.dgettext(
        AurumFinanceWeb.Gettext,
        "errors",
        "error_account_management_group_invalid"
      )
    )
  end

  defp validate_immutable_fields(%Ecto.Changeset{data: %{id: nil}} = changeset), do: changeset

  defp validate_immutable_fields(changeset) do
    Enum.reduce(@immutable_fields, changeset, fn field, acc ->
      case fetch_change(acc, field) do
        {:ok, value} ->
          maybe_add_immutable_error(acc, field, value)

        _ ->
          acc
      end
    end)
  end

  defp maybe_add_immutable_error(changeset, field, value) do
    if value == Map.get(changeset.data, field) do
      changeset
    else
      add_error(
        changeset,
        field,
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_account_immutable_field")
      )
    end
  end

  defp normalize_to_upper(value) when is_binary(value), do: String.upcase(value)
  defp normalize_to_upper(value), do: value
end
