defmodule AurumFinance.Reconciliation.ReconciliationAuditLog do
  @moduledoc """
  Append-only audit trail for reconciliation state transitions.

  Every meaningful reconciliation transition should leave a historical trace in
  this table.

  The main workflow it documents is:

  - a posting goes from no state to `cleared` when the user marks it during an
    active session
  - a posting goes from `cleared` back to no state when the user un-clears it
    before finalization
  - a posting goes from `cleared` to `reconciled` when the user completes the
    session

  This schema exists so the system can preserve a durable transition history
  even when the active workflow row in `posting_reconciliation_states` is later
  deleted during an un-clear. That is why the log also stores `posting_id` and
  session references directly.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Reconciliation.PostingReconciliationState
  alias AurumFinance.Reconciliation.ReconciliationSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @required [:reconciliation_session_id, :posting_id, :actor, :channel, :occurred_at]
  @optional [:posting_reconciliation_state_id, :from_status, :to_status, :metadata]

  schema "reconciliation_audit_logs" do
    field :from_status, :string
    field :to_status, :string
    field :actor, :string
    field :channel, :string
    field :occurred_at, :utc_datetime_usec
    field :metadata, :map

    belongs_to :posting_reconciliation_state, PostingReconciliationState
    belongs_to :reconciliation_session, ReconciliationSession
    belongs_to :posting, Posting

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Builds the reconciliation audit log changeset.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Reconciliation.ReconciliationAuditLog.changeset(
      ...>     %AurumFinance.Reconciliation.ReconciliationAuditLog{},
      ...>     %{
      ...>       reconciliation_session_id: Ecto.UUID.generate(),
      ...>       posting_id: Ecto.UUID.generate(),
      ...>       actor: "root",
      ...>       channel: "web",
      ...>       occurred_at: DateTime.utc_now()
      ...>     }
      ...>   )
      iex> changeset.valid?
      true
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(reconciliation_audit_log, attrs) do
    reconciliation_audit_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:actor,
      min: 1,
      max: 120,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_audit_actor_invalid")
    )
    |> validate_length(:channel,
      min: 1,
      max: 120,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_reconciliation_audit_channel_invalid"
        )
    )
    |> foreign_key_constraint(:posting_reconciliation_state_id)
    |> foreign_key_constraint(:reconciliation_session_id)
    |> foreign_key_constraint(:posting_id)
  end
end
