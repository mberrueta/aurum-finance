defmodule AurumFinance.Reconciliation.PostingReconciliationState do
  @moduledoc """
  Overlay workflow state for a posting during reconciliation.

  This schema does not replace or mutate the immutable ledger posting. Instead,
  it adds workflow state on top of a posting while the user is reconciling an
  account.

  The intended flow is:

  - when the user opens a reconciliation session, postings without a row in this
    table are treated as unreconciled
  - when the user marks a posting as cleared, a row is inserted with
    `status: :cleared`
  - while the session is still open, a cleared posting can be un-cleared by
    deleting that row, which returns the posting to the implicit unreconciled
    state
  - when the user finalizes the session, rows that belong to that session move
    from `:cleared` to `:reconciled`

  `:reconciled` is terminal. After finalization, the posting is considered
  protected reconciliation history and must not be changed back through normal
  workflow operations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Reconciliation.ReconciliationSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses [:cleared, :reconciled]

  @type t :: %__MODULE__{}

  @required [:entity_id, :posting_id, :status]
  @optional [:reconciliation_session_id, :reason]

  schema "posting_reconciliation_states" do
    field :status, Ecto.Enum, values: @statuses
    field :reason, :string

    belongs_to :entity, Entity
    belongs_to :posting, Posting
    belongs_to :reconciliation_session, ReconciliationSession

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the posting reconciliation state changeset.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Reconciliation.PostingReconciliationState.changeset(
      ...>     %AurumFinance.Reconciliation.PostingReconciliationState{},
      ...>     %{
      ...>       entity_id: Ecto.UUID.generate(),
      ...>       posting_id: Ecto.UUID.generate(),
      ...>       status: :cleared
      ...>     }
      ...>   )
      iex> changeset.valid?
      true
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(posting_reconciliation_state, attrs) do
    posting_reconciliation_state
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:reason,
      max: 500,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_reconciliation_reason_length_invalid"
        )
    )
    |> foreign_key_constraint(:entity_id)
    |> foreign_key_constraint(:posting_id)
    |> foreign_key_constraint(:reconciliation_session_id)
    |> unique_constraint(:posting_id, name: :posting_reconciliation_states_posting_id_index)
    |> check_constraint(:status, name: :posting_reconciliation_states_status_check)
  end
end
