defmodule AurumFinance.Ledger.Posting do
  @moduledoc """
  Immutable posting leg targeting a single account.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Transaction

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @required [:transaction_id, :account_id, :amount]
  @optional []

  schema "postings" do
    field :amount, :decimal

    belongs_to :transaction, Transaction
    belongs_to :account, Account

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  @doc """
  Builds the posting changeset.

  ## Examples

  ```elixir
  changeset =
    AurumFinance.Ledger.Posting.changeset(%AurumFinance.Ledger.Posting{}, %{
      transaction_id: Ecto.UUID.generate(),
      account_id: Ecto.UUID.generate(),
      amount: Decimal.new("10.00")
    })

  changeset.valid?
  #=> true
  ```
  """
  def changeset(posting, attrs) do
    posting
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> foreign_key_constraint(:transaction_id)
    |> foreign_key_constraint(:account_id)
  end
end
