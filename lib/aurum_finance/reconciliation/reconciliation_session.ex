defmodule AurumFinance.Reconciliation.ReconciliationSession do
  @moduledoc """
  Reconciliation session header for a single account statement run.

  A reconciliation starts when the user opens the reconciliation workflow for an
  account and creates a new session with a statement date and statement
  balance. This schema stores that top-level session record.

  The session is the container for the workflow:

  - it identifies the account being reconciled
  - it stores the statement reference data entered by the user
  - it stays active while the user reviews unreconciled postings and marks them
    as cleared
  - it is completed when the user finalizes the reconciliation and the cleared
    postings become reconciled

  While `completed_at` is `nil`, the session is in progress and the user can
  keep working through postings. Once `completed_at` is set, the session becomes
  the immutable historical record of that reconciliation run.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @required [:account_id, :entity_id, :statement_date, :statement_balance]
  @optional [:completed_at]

  schema "reconciliation_sessions" do
    field :statement_date, :date
    field :statement_balance, :decimal
    field :completed_at, :utc_datetime_usec

    belongs_to :account, Account
    belongs_to :entity, Entity

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the reconciliation session changeset.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Reconciliation.ReconciliationSession.changeset(
      ...>     %AurumFinance.Reconciliation.ReconciliationSession{},
      ...>     %{
      ...>       account_id: Ecto.UUID.generate(),
      ...>       entity_id: Ecto.UUID.generate(),
      ...>       statement_date: ~D[2026-03-11],
      ...>       statement_balance: Decimal.new("100.00")
      ...>     }
      ...>   )
      iex> changeset.valid?
      true
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(reconciliation_session, attrs) do
    reconciliation_session
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_number(:statement_balance,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_reconciliation_statement_balance_invalid"
        )
    )
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:entity_id)
    |> unique_constraint(:account_id,
      name: :reconciliation_sessions_account_id_active_index,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_active_session_exists")
    )
  end
end
