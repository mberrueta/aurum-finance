defmodule AurumFinance.Reconciliation do
  @moduledoc """
  Reconciliation context for session lifecycle, posting overlay state, and
  reconciliation balance derivation.

  This context keeps ledger postings immutable. The user-facing reconciliation
  workflow happens through a session record plus overlay rows in
  `posting_reconciliation_states`.

  The main flow is:

  - create a reconciliation session for one account and statement
  - list account postings with their derived reconciliation status
  - mark unreconciled postings as cleared
  - optionally un-clear cleared postings while the session is still active
  - complete the session, which promotes `:cleared` rows to `:reconciled`
  - preserve every transition in `reconciliation_audit_logs`
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Audit.Multi, as: AuditMulti
  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Reconciliation.MatchCandidateFinder
  alias AurumFinance.Reconciliation.MatchCandidateScorer
  alias AurumFinance.Reconciliation.PostingReconciliationState
  alias AurumFinance.Reconciliation.ReconciliationAuditLog
  alias AurumFinance.Reconciliation.ReconciliationSession
  alias AurumFinance.Repo

  @default_actor "system"
  @session_entity_type "reconciliation_session"
  @cleared_status :cleared
  @reconciled_status :reconciled

  @type audit_opt :: {:actor, String.t()} | {:channel, Audit.audit_channel()}

  @type list_opt ::
          {:entity_id, Ecto.UUID.t()}
          | {:account_id, Ecto.UUID.t()}
          | {:include_completed, boolean()}

  @type match_candidate_opt ::
          {:entity_id, Ecto.UUID.t()}
          | {:date_window_days, non_neg_integer()}
          | {:include_below_threshold, boolean()}
          | {:limit, pos_integer()}

  @type posting_status :: :unreconciled | :cleared | :reconciled
  @type match_band :: :exact_match | :near_match | :weak_match | :below_threshold

  @type reconciliation_posting :: %{
          id: Ecto.UUID.t(),
          account_id: Ecto.UUID.t(),
          transaction_id: Ecto.UUID.t(),
          amount: Decimal.t(),
          inserted_at: DateTime.t(),
          transaction_date: Date.t(),
          transaction_description: String.t(),
          reconciliation_status: posting_status(),
          posting_reconciliation_state_id: Ecto.UUID.t() | nil,
          reconciliation_session_id: Ecto.UUID.t() | nil,
          reason: String.t() | nil
        }

  @type match_candidate :: %{
          posting_id: Ecto.UUID.t(),
          imported_row_id: Ecto.UUID.t(),
          imported_file_id: Ecto.UUID.t(),
          score: float(),
          match_band: match_band(),
          reasons: [atom()],
          signals: %{
            amount_exact: boolean(),
            amount_absolute_distance: Decimal.t(),
            amount_relative_distance: float(),
            date_distance_days: non_neg_integer(),
            description_similarity: float()
          },
          imported_row: ImportedRow.t()
        }

  @doc """
  Returns a composable query for reconciliation sessions within one entity scope.

  Supported filters:

  - `:entity_id` (required)
  - `:account_id`
  - `:include_completed` (defaults to `true`)

  ## Examples

      iex> query =
      ...>   AurumFinance.Reconciliation.list_reconciliation_sessions_query(
      ...>     entity_id: Ecto.UUID.generate()
      ...>   )
      iex> %Ecto.Query{} = query
      true
  """
  @spec list_reconciliation_sessions_query([list_opt()]) :: Ecto.Query.t()
  def list_reconciliation_sessions_query(opts \\ []) do
    opts =
      opts
      |> require_entity_scope!("list_reconciliation_sessions_query/1")
      |> Keyword.put_new(:include_completed, true)

    filter_query(
      {:sessions,
       from(session in ReconciliationSession,
         preload: [:account, :entity]
       )},
      opts
    )
  end

  @doc """
  Lists reconciliation sessions within one entity scope.

  Active sessions are returned first, followed by completed sessions ordered by
  `statement_date` descending.

  ## Examples

      iex> AurumFinance.Reconciliation.list_reconciliation_sessions(entity_id: Ecto.UUID.generate())
      []
  """
  @spec list_reconciliation_sessions([list_opt()]) :: [ReconciliationSession.t()]
  def list_reconciliation_sessions(opts \\ []) do
    list_reconciliation_sessions_query(opts)
    |> order_by(
      [session],
      asc: fragment("CASE WHEN ? IS NULL THEN 0 ELSE 1 END", session.completed_at),
      desc: session.statement_date,
      desc: session.inserted_at
    )
    |> Repo.all()
  end

  @doc """
  Fetches one reconciliation session within an explicit entity scope.

  Raises `Ecto.NoResultsError` when the session does not exist inside that
  entity boundary.

  ## Examples

      iex> entity_id = Ecto.UUID.generate()
      iex> session_id = Ecto.UUID.generate()
      iex> AurumFinance.Reconciliation.get_reconciliation_session!(entity_id, session_id)
      ** (Ecto.NoResultsError)
  """
  @spec get_reconciliation_session!(Ecto.UUID.t(), Ecto.UUID.t()) :: ReconciliationSession.t()
  def get_reconciliation_session!(entity_id, session_id) do
    list_reconciliation_sessions_query(entity_id: entity_id)
    |> where([session], session.id == ^session_id)
    |> Repo.one!()
  end

  @doc """
  Creates a reconciliation session and emits an audit event.

  The account must belong to the same entity and must be an institution account.
  The active-session uniqueness rule is enforced by the database partial unique
  index and surfaced through the session changeset.

  ## Examples

      iex> AurumFinance.Reconciliation.create_reconciliation_session(%{
      ...>   entity_id: Ecto.UUID.generate(),
      ...>   account_id: Ecto.UUID.generate(),
      ...>   statement_date: ~D[2026-03-11],
      ...>   statement_balance: Decimal.new("100.00")
      ...> }, entity_id: Ecto.UUID.generate())
      {:error, %Ecto.Changeset{}}
  """
  @spec create_reconciliation_session(map(), [list_opt() | audit_opt()]) ::
          {:ok, ReconciliationSession.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def create_reconciliation_session(attrs, opts \\ []) do
    opts = require_entity_scope!(opts, "create_reconciliation_session/2")

    %ReconciliationSession{}
    |> session_changeset(attrs)
    |> validate_session_account_scope()
    |> Audit.insert_and_log(session_audit_meta(opts))
  end

  @doc """
  Updates an active reconciliation session and emits an audit event.

  Completed sessions are read-only and cannot be updated through this API.

  ## Examples

      iex> session = %AurumFinance.Reconciliation.ReconciliationSession{}
      iex> AurumFinance.Reconciliation.update_reconciliation_session(session, %{})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_reconciliation_session(ReconciliationSession.t(), map()) ::
          {:ok, ReconciliationSession.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  @spec update_reconciliation_session(ReconciliationSession.t(), map(), [audit_opt()]) ::
          {:ok, ReconciliationSession.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, term()}}
  def update_reconciliation_session(%ReconciliationSession{} = session, attrs, opts \\ []) do
    changeset =
      session
      |> session_changeset(attrs)
      |> validate_session_mutable(session)
      |> validate_session_account_scope()

    Audit.update_and_log(session, changeset, session_audit_meta(opts, action: "updated"))
  end

  @doc """
  Returns a changeset for reconciliation session form handling.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Reconciliation.change_reconciliation_session(
      ...>     %AurumFinance.Reconciliation.ReconciliationSession{},
      ...>     %{
      ...>       entity_id: Ecto.UUID.generate(),
      ...>       account_id: Ecto.UUID.generate(),
      ...>       statement_date: ~D[2026-03-11],
      ...>       statement_balance: Decimal.new("100.00")
      ...>     }
      ...>   )
      iex> changeset.valid?
      false
  """
  @spec change_reconciliation_session(ReconciliationSession.t(), map()) :: Ecto.Changeset.t()
  def change_reconciliation_session(%ReconciliationSession{} = session, attrs \\ %{}) do
    session_changeset(session, attrs)
  end

  @doc """
  Completes an active reconciliation session atomically.

  All cleared overlay rows for the session move to `:reconciled`, transition
  audit log rows are inserted, `completed_at` is set, and the session emits a
  generic audit event in the same transaction.

  ## Examples

      iex> session = %AurumFinance.Reconciliation.ReconciliationSession{}
      iex> AurumFinance.Reconciliation.complete_reconciliation_session(session)
      {:error, :session_already_completed}
  """
  @spec complete_reconciliation_session(ReconciliationSession.t()) ::
          {:ok, ReconciliationSession.t()} | {:error, term()}
  @spec complete_reconciliation_session(ReconciliationSession.t(), [audit_opt()]) ::
          {:ok, ReconciliationSession.t()} | {:error, term()}
  def complete_reconciliation_session(%ReconciliationSession{} = session, opts \\ []) do
    case active_session(session) do
      {:ok, session} ->
        do_complete_reconciliation_session(session, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a composable query for account postings with derived reconciliation
  state inside one entity scope.

  The result uses a `LEFT JOIN` against `posting_reconciliation_states` so rows
  without an overlay record are treated as unreconciled.

  ## Examples

      iex> query =
      ...>   AurumFinance.Reconciliation.list_postings_for_reconciliation_query(
      ...>     Ecto.UUID.generate(),
      ...>     entity_id: Ecto.UUID.generate()
      ...>   )
      iex> %Ecto.Query{} = query
      true
  """
  @spec list_postings_for_reconciliation_query(Ecto.UUID.t(), [list_opt()]) :: Ecto.Query.t()
  def list_postings_for_reconciliation_query(account_id, opts \\ []) do
    opts = require_entity_scope!(opts, "list_postings_for_reconciliation_query/2")

    filter_query(
      {:postings,
       from(posting in Posting,
         join: transaction in Transaction,
         on: transaction.id == posting.transaction_id,
         left_join: state in PostingReconciliationState,
         on: state.posting_id == posting.id,
         where: posting.account_id == ^account_id,
         where: is_nil(transaction.voided_at)
       )},
      opts
    )
  end

  @doc """
  Lists account postings with their derived reconciliation status.

  Rows are ordered by transaction date descending so the reconciliation UI can
  show the newest statement candidates first.

  ## Examples

      iex> AurumFinance.Reconciliation.list_postings_for_reconciliation(
      ...>   Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate()
      ...> )
      []
  """
  @spec list_postings_for_reconciliation(Ecto.UUID.t(), [list_opt()]) :: [
          reconciliation_posting()
        ]
  def list_postings_for_reconciliation(account_id, opts \\ []) do
    list_postings_for_reconciliation_query(account_id, opts)
    |> order_by([posting, transaction, _state], desc: transaction.date, desc: posting.inserted_at)
    |> select([posting, transaction, state], %{
      id: posting.id,
      account_id: posting.account_id,
      transaction_id: posting.transaction_id,
      amount: posting.amount,
      inserted_at: posting.inserted_at,
      transaction_date: transaction.date,
      transaction_description: transaction.description,
      reconciliation_status: type(fragment("COALESCE(?, 'unreconciled')", state.status), :string),
      posting_reconciliation_state_id: state.id,
      reconciliation_session_id: state.reconciliation_session_id,
      reason: state.reason
    })
    |> Repo.all()
    |> Enum.map(&normalize_reconciliation_posting/1)
  end

  @doc """
  Returns the effective reconciliation status for a posting.

  The absence of an overlay row is treated as `:unreconciled`.

  ## Examples

      iex> AurumFinance.Reconciliation.get_posting_reconciliation_status(Ecto.UUID.generate())
      :unreconciled
  """
  @spec get_posting_reconciliation_status(Ecto.UUID.t()) :: posting_status()
  def get_posting_reconciliation_status(posting_id) do
    PostingReconciliationState
    |> where([state], state.posting_id == ^posting_id)
    |> select([state], state.status)
    |> Repo.one()
    |> normalize_posting_status()
  end

  @doc """
  Returns ranked imported-row match candidates for one posting within an entity scope.

  Candidate retrieval, scoring, and presentation are intentionally separated so
  the matching model can evolve without changing the public context contract.

  The returned candidates are read-only assistance. Inspecting them does not
  clear, reconcile, or persist any match suggestion.

  By default, the public API only returns useful above-threshold candidates.
  Internal scoring may still classify weaker rows as `:below_threshold`, and
  callers can opt in to include them.

  ## Examples

      iex> AurumFinance.Reconciliation.list_match_candidates_for_posting(
      ...>   Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate()
      ...> )
      {:error, :not_found}
  """
  @spec list_match_candidates_for_posting(Ecto.UUID.t(), [match_candidate_opt()]) ::
          {:ok, [match_candidate()]} | {:error, :not_found}
  def list_match_candidates_for_posting(posting_id, opts \\ []) do
    opts = require_entity_scope!(opts, "list_match_candidates_for_posting/2")

    with {:ok, posting_context} <-
           fetch_posting_match_context(Keyword.fetch!(opts, :entity_id), posting_id) do
      candidates =
        posting_context
        |> MatchCandidateFinder.find(opts)
        |> Enum.map(&MatchCandidateScorer.score(posting_context, &1, opts))
        |> maybe_reject_below_threshold(opts)
        |> Enum.sort_by(& &1.score, :desc)
        |> Enum.take(Keyword.get(opts, :limit, 5))
        |> Enum.map(&normalize_match_candidate/1)

      {:ok, candidates}
    end
  end

  @doc """
  Accepts one visible match candidate for a posting and marks that posting as cleared.

  This operation is still grounded in the reconciliation state machine: the
  posting becomes `:cleared`. The accepted imported-row reference is preserved
  in the reconciliation audit metadata for traceability.

  ## Examples

      iex> AurumFinance.Reconciliation.accept_match_candidate(
      ...>   Ecto.UUID.generate(),
      ...>   Ecto.UUID.generate(),
      ...>   Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate()
      ...> )
      {:error, :not_found}
  """
  @spec accept_match_candidate(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t(), [
          match_candidate_opt() | audit_opt()
        ]) ::
          {:ok, PostingReconciliationState.t()} | {:error, term()}
  def accept_match_candidate(posting_id, imported_row_id, session_id, opts \\ []) do
    opts = require_entity_scope!(opts, "accept_match_candidate/4")
    entity_id = Keyword.fetch!(opts, :entity_id)
    session = get_reconciliation_session!(entity_id, session_id)

    with {:ok, session} <- active_session(session),
         {:ok, candidate} <-
           fetch_acceptable_match_candidate(posting_id, imported_row_id, entity_id) do
      metadata_by_posting = %{
        posting_id => accepted_match_metadata(candidate)
      }

      case do_mark_postings_cleared([posting_id], session, opts, metadata_by_posting) do
        {:ok, [state]} -> {:ok, state}
        {:ok, []} -> {:error, :candidate_not_acceptable}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Marks unreconciled postings as cleared for the given session atomically.

  All posting ids must belong to the session account, remain unvoided, and have
  no existing overlay row.

  ## Examples

      iex> AurumFinance.Reconciliation.mark_postings_cleared([], Ecto.UUID.generate(), entity_id: Ecto.UUID.generate())
      {:ok, []}
  """
  @spec mark_postings_cleared([Ecto.UUID.t()], Ecto.UUID.t(), [list_opt() | audit_opt()]) ::
          {:ok, [PostingReconciliationState.t()]} | {:error, term()}
  def mark_postings_cleared(posting_ids, session_id, opts \\ [])

  def mark_postings_cleared([], _session_id, _opts), do: {:ok, []}

  def mark_postings_cleared(posting_ids, session_id, opts) do
    opts = require_entity_scope!(opts, "mark_postings_cleared/3")
    session = get_reconciliation_session!(Keyword.fetch!(opts, :entity_id), session_id)

    with {:ok, session} <- active_session(session) do
      do_mark_postings_cleared(Enum.uniq(posting_ids), session, opts)
    end
  end

  @doc """
  Un-clears cleared postings for the given session atomically.

  Only rows currently in `:cleared` state and belonging to the session may be
  removed.

  ## Examples

      iex> AurumFinance.Reconciliation.mark_postings_uncleared([], Ecto.UUID.generate(), entity_id: Ecto.UUID.generate())
      {:ok, []}
  """
  @spec mark_postings_uncleared([Ecto.UUID.t()], Ecto.UUID.t(), [list_opt() | audit_opt()]) ::
          {:ok, [Ecto.UUID.t()]} | {:error, term()}
  def mark_postings_uncleared(posting_ids, session_id, opts \\ [])

  def mark_postings_uncleared([], _session_id, _opts), do: {:ok, []}

  def mark_postings_uncleared(posting_ids, session_id, opts) do
    opts = require_entity_scope!(opts, "mark_postings_uncleared/3")
    session = get_reconciliation_session!(Keyword.fetch!(opts, :entity_id), session_id)

    with {:ok, session} <- active_session(session) do
      do_mark_postings_uncleared(Enum.uniq(posting_ids), session, opts)
    end
  end

  @doc """
  Returns true when the given posting currently has reconciled status.

  ## Examples

      iex> AurumFinance.Reconciliation.posting_has_reconciled_status?(Ecto.UUID.generate())
      false
  """
  @spec posting_has_reconciled_status?(Ecto.UUID.t()) :: boolean()
  def posting_has_reconciled_status?(posting_id) do
    any_posting_reconciled?([posting_id])
  end

  @doc """
  Returns true when any posting in the list currently has reconciled status.

  This function is intended for fast guard checks before destructive ledger
  workflows such as transaction voiding.

  ## Examples

      iex> AurumFinance.Reconciliation.any_posting_reconciled?([])
      false
  """
  @spec any_posting_reconciled?([Ecto.UUID.t()]) :: boolean()
  def any_posting_reconciled?([]), do: false

  def any_posting_reconciled?(posting_ids) do
    PostingReconciliationState
    |> where([state], state.posting_id in ^Enum.uniq(posting_ids))
    |> where([state], state.status == ^:reconciled)
    |> Repo.exists?()
  end

  @doc """
  Returns the derived cleared balance for one account within an entity scope.

  Both `:cleared` and `:reconciled` overlay rows contribute to the balance. Rows
  belonging to voided transactions are excluded.

  ## Examples

      iex> AurumFinance.Reconciliation.get_cleared_balance(
      ...>   Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate()
      ...> )
      Decimal.new("0")
  """
  @spec get_cleared_balance(Ecto.UUID.t(), [list_opt()]) :: Decimal.t()
  def get_cleared_balance(account_id, opts \\ []) do
    opts = require_entity_scope!(opts, "get_cleared_balance/2")

    filter_query(
      {:balance,
       from(posting in Posting,
         join: transaction in Transaction,
         on: transaction.id == posting.transaction_id,
         join: state in PostingReconciliationState,
         on: state.posting_id == posting.id,
         where: posting.account_id == ^account_id,
         where: state.status in ^[:cleared, :reconciled],
         where: is_nil(transaction.voided_at)
       )},
      opts
    )
    |> select([posting, _transaction, _state], sum(posting.amount))
    |> Repo.one()
    |> case do
      nil -> Decimal.new("0")
      %Decimal{} = amount -> amount
    end
  end

  # ---------------------------------------------------------------------------
  # Session completion
  # ---------------------------------------------------------------------------

  @dialyzer {:nowarn_function, do_complete_reconciliation_session: 2}
  defp do_complete_reconciliation_session(session, opts) do
    now = utc_now()
    audit_metadata = extract_audit_metadata(opts)
    before_snapshot = session_snapshot(session)

    new_multi()
    |> multi_run(:cleared_states, fn _repo, _changes ->
      {:ok, list_session_states_for_completion(session.id)}
    end)
    |> multi_run(:reconciled_states, fn repo, %{cleared_states: cleared_states} ->
      reconcile_session_states(repo, cleared_states, now)
    end)
    |> multi_run(:reconciliation_audit_logs, fn repo, %{cleared_states: cleared_states} ->
      insert_reconciliation_audit_logs(
        repo,
        build_completion_audit_log_entries(cleared_states, session.id, audit_metadata, now)
      )
    end)
    |> multi_update(
      :session,
      ReconciliationSession.changeset(session, %{completed_at: now})
    )
    |> AuditMulti.append_event(:session, before_snapshot, %{
      action: "completed",
      actor: audit_metadata.actor,
      channel: audit_metadata.channel,
      entity_type: @session_entity_type,
      serializer: &session_snapshot/1
    })
    |> Repo.transaction()
    |> normalize_session_multi_result()
  end

  defp list_session_states_for_completion(session_id) do
    PostingReconciliationState
    |> where(
      [state],
      state.reconciliation_session_id == ^session_id and state.status == ^:cleared
    )
    |> Repo.all()
  end

  defp reconcile_session_states(_repo, [], _now), do: {:ok, 0}

  defp reconcile_session_states(repo, cleared_states, now) do
    state_ids = Enum.map(cleared_states, & &1.id)

    {count, _rows} =
      PostingReconciliationState
      |> where([state], state.id in ^state_ids)
      |> repo.update_all(set: [status: @reconciled_status, updated_at: now])

    if count == length(state_ids) do
      {:ok, count}
    else
      {:error, :session_completion_conflict}
    end
  end

  defp build_completion_audit_log_entries(cleared_states, session_id, audit_metadata, now) do
    Enum.map(cleared_states, fn state ->
      %{
        posting_reconciliation_state_id: state.id,
        reconciliation_session_id: session_id,
        posting_id: state.posting_id,
        from_status: Atom.to_string(@cleared_status),
        to_status: Atom.to_string(@reconciled_status),
        actor: audit_metadata.actor,
        channel: Atom.to_string(audit_metadata.channel),
        occurred_at: now,
        metadata: nil,
        inserted_at: now
      }
    end)
  end

  # ---------------------------------------------------------------------------
  # Mark cleared / unclear
  # ---------------------------------------------------------------------------

  @dialyzer {:nowarn_function, do_mark_postings_cleared: 4, do_mark_postings_uncleared: 3}
  defp do_mark_postings_cleared(posting_ids, session, opts, metadata_by_posting \\ %{}) do
    now = utc_now()
    audit_metadata = extract_audit_metadata(opts)

    new_multi()
    |> multi_run(:clearable_postings, fn _repo, _changes ->
      validate_clearable_postings(posting_ids, session)
    end)
    |> multi_run(:posting_reconciliation_states, fn repo,
                                                    %{clearable_postings: clearable_postings} ->
      insert_posting_reconciliation_states(repo, clearable_postings, session, now)
    end)
    |> multi_run(:reconciliation_audit_logs, fn repo, %{posting_reconciliation_states: states} ->
      insert_reconciliation_audit_logs(
        repo,
        build_cleared_audit_log_entries(
          states,
          session.id,
          audit_metadata,
          now,
          metadata_by_posting
        )
      )
    end)
    |> Repo.transaction()
    |> normalize_states_multi_result()
  end

  defp do_mark_postings_uncleared(posting_ids, session, opts) do
    now = utc_now()
    audit_metadata = extract_audit_metadata(opts)

    new_multi()
    |> multi_run(:clearable_states, fn _repo, _changes ->
      validate_unclearable_states(posting_ids, session)
    end)
    |> multi_run(:deleted_states, fn repo, %{clearable_states: clearable_states} ->
      delete_cleared_states(repo, clearable_states)
    end)
    |> multi_run(:reconciliation_audit_logs, fn repo, %{clearable_states: clearable_states} ->
      insert_reconciliation_audit_logs(
        repo,
        build_uncleared_audit_log_entries(clearable_states, session.id, audit_metadata, now)
      )
    end)
    |> Repo.transaction()
    |> normalize_unclear_multi_result()
  end

  defp validate_clearable_postings(posting_ids, session) do
    clearable_postings =
      Posting
      |> join(:inner, [posting], transaction in Transaction,
        on: transaction.id == posting.transaction_id
      )
      |> join(:left, [posting, _transaction], state in PostingReconciliationState,
        on: state.posting_id == posting.id
      )
      |> where(
        [posting],
        posting.id in ^posting_ids and posting.account_id == ^session.account_id
      )
      |> where([_posting, transaction], transaction.entity_id == ^session.entity_id)
      |> where([_posting, transaction, _state], is_nil(transaction.voided_at))
      |> where([_posting, _transaction, state], is_nil(state.id))
      |> select([posting], %{posting_id: posting.id})
      |> Repo.all()

    if length(clearable_postings) == length(posting_ids) do
      {:ok, clearable_postings}
    else
      {:error, :postings_not_clearable}
    end
  end

  defp insert_posting_reconciliation_states(repo, clearable_postings, session, now) do
    posting_ids = Enum.map(clearable_postings, & &1.posting_id)

    entries =
      Enum.map(clearable_postings, fn %{posting_id: posting_id} ->
        %{
          entity_id: session.entity_id,
          posting_id: posting_id,
          reconciliation_session_id: session.id,
          status: @cleared_status,
          reason: nil,
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _inserted_rows} =
      repo.insert_all(
        PostingReconciliationState,
        entries,
        on_conflict: :nothing,
        conflict_target: [:posting_id]
      )

    if count == length(entries) do
      states =
        PostingReconciliationState
        |> where([state], state.posting_id in ^posting_ids)
        |> where([state], state.reconciliation_session_id == ^session.id)
        |> repo.all()

      {:ok, states}
    else
      {:error, :postings_not_clearable}
    end
  end

  defp build_cleared_audit_log_entries(
         states,
         session_id,
         audit_metadata,
         now,
         metadata_by_posting
       ) do
    Enum.map(states, fn state ->
      %{
        posting_reconciliation_state_id: nil,
        reconciliation_session_id: session_id,
        posting_id: state.posting_id,
        from_status: nil,
        to_status: Atom.to_string(@cleared_status),
        actor: audit_metadata.actor,
        channel: Atom.to_string(audit_metadata.channel),
        occurred_at: now,
        metadata: Map.get(metadata_by_posting, state.posting_id),
        inserted_at: now
      }
    end)
  end

  defp validate_unclearable_states(posting_ids, session) do
    clearable_states =
      PostingReconciliationState
      |> join(:inner, [state], posting in Posting, on: posting.id == state.posting_id)
      |> join(:inner, [_state, posting], transaction in Transaction,
        on: transaction.id == posting.transaction_id
      )
      |> where(
        [state],
        state.posting_id in ^posting_ids and state.reconciliation_session_id == ^session.id
      )
      |> where([state], state.status == ^:cleared)
      |> where([_state, posting], posting.account_id == ^session.account_id)
      |> where([_state, _posting, transaction], transaction.entity_id == ^session.entity_id)
      |> select([state], %{id: state.id, posting_id: state.posting_id})
      |> Repo.all()

    if length(clearable_states) == length(posting_ids) do
      {:ok, clearable_states}
    else
      {:error, :postings_not_unclearable}
    end
  end

  defp delete_cleared_states(_repo, []), do: {:ok, []}

  defp delete_cleared_states(repo, clearable_states) do
    state_ids = Enum.map(clearable_states, & &1.id)

    {count, _rows} =
      PostingReconciliationState
      |> where([state], state.id in ^state_ids)
      |> repo.delete_all()

    if count == length(state_ids) do
      {:ok, Enum.map(clearable_states, & &1.posting_id)}
    else
      {:error, :postings_not_unclearable}
    end
  end

  defp build_uncleared_audit_log_entries(states, session_id, audit_metadata, now) do
    Enum.map(states, fn state ->
      %{
        posting_reconciliation_state_id: nil,
        reconciliation_session_id: session_id,
        posting_id: state.posting_id,
        from_status: Atom.to_string(@cleared_status),
        to_status: nil,
        actor: audit_metadata.actor,
        channel: Atom.to_string(audit_metadata.channel),
        occurred_at: now,
        metadata: nil,
        inserted_at: now
      }
    end)
  end

  defp insert_reconciliation_audit_logs(_repo, []), do: {:ok, 0}

  defp insert_reconciliation_audit_logs(repo, entries) do
    {count, _rows} = repo.insert_all(ReconciliationAuditLog, entries)
    {:ok, count}
  end

  @dialyzer {:nowarn_function, new_multi: 0, multi_run: 3, multi_update: 3}

  @spec new_multi() :: any()
  defp new_multi, do: Ecto.Multi.new()

  @spec multi_run(any(), atom(), (any(), map() -> {:ok, any()} | {:error, term()})) :: any()
  defp multi_run(multi, name, fun), do: Ecto.Multi.run(multi, name, fun)

  @spec multi_update(any(), atom(), Ecto.Changeset.t()) :: any()
  defp multi_update(multi, name, changeset), do: Ecto.Multi.update(multi, name, changeset)

  # ---------------------------------------------------------------------------
  # Validation helpers
  # ---------------------------------------------------------------------------

  defp session_changeset(session, attrs) do
    ReconciliationSession.changeset(session, attrs)
  end

  defp validate_session_account_scope(changeset) do
    entity_id = Ecto.Changeset.get_field(changeset, :entity_id)
    account_id = Ecto.Changeset.get_field(changeset, :account_id)

    case load_institution_account(entity_id, account_id) do
      %Account{} -> changeset
      nil -> add_account_scope_error(changeset)
    end
  end

  defp load_institution_account(nil, _account_id), do: nil
  defp load_institution_account(_entity_id, nil), do: nil

  defp load_institution_account(entity_id, account_id) do
    Account
    |> where([account], account.id == ^account_id and account.entity_id == ^entity_id)
    |> where([account], account.management_group == ^:institution)
    |> Repo.one()
  end

  defp add_account_scope_error(changeset) do
    Ecto.Changeset.add_error(
      changeset,
      :account_id,
      Gettext.dgettext(
        AurumFinanceWeb.Gettext,
        "errors",
        "error_reconciliation_account_invalid"
      )
    )
  end

  defp validate_session_mutable(changeset, %ReconciliationSession{completed_at: nil}),
    do: changeset

  defp validate_session_mutable(changeset, %ReconciliationSession{}) do
    Ecto.Changeset.add_error(
      changeset,
      :completed_at,
      Gettext.dgettext(
        AurumFinanceWeb.Gettext,
        "errors",
        "error_reconciliation_session_completed"
      )
    )
  end

  defp active_session(%ReconciliationSession{completed_at: nil} = session), do: {:ok, session}
  defp active_session(%ReconciliationSession{}), do: {:error, :session_already_completed}

  defp fetch_posting_match_context(entity_id, posting_id) do
    Posting
    |> join(:inner, [posting], transaction in Transaction,
      on: transaction.id == posting.transaction_id
    )
    |> join(:inner, [posting, _transaction], account in Account,
      on: account.id == posting.account_id
    )
    |> where(
      [posting, transaction, account],
      posting.id == ^posting_id and transaction.entity_id == ^entity_id and
        account.entity_id == ^entity_id
    )
    |> select([posting, transaction, account], %{
      posting: posting,
      transaction_date: transaction.date,
      transaction_description: transaction.description,
      account: account
    })
    |> Repo.one()
    |> fetch_posting_match_context_result()
  end

  defp fetch_posting_match_context_result(nil), do: {:error, :not_found}
  defp fetch_posting_match_context_result(posting_context), do: {:ok, posting_context}

  defp maybe_reject_below_threshold(candidates, opts) do
    case Keyword.get(opts, :include_below_threshold, false) do
      true -> candidates
      false -> Enum.reject(candidates, &(&1.match_band == :below_threshold))
    end
  end

  defp fetch_acceptable_match_candidate(posting_id, imported_row_id, entity_id) do
    case list_match_candidates_for_posting(posting_id, entity_id: entity_id, limit: 10) do
      {:ok, candidates} ->
        candidates
        |> Enum.find(&(&1.imported_row_id == imported_row_id))
        |> fetch_acceptable_match_candidate_result()

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_acceptable_match_candidate_result(nil), do: {:error, :candidate_not_acceptable}
  defp fetch_acceptable_match_candidate_result(candidate), do: {:ok, candidate}

  defp accepted_match_metadata(candidate) do
    %{
      "accepted_imported_row_id" => candidate.imported_row_id,
      "accepted_imported_file_id" => candidate.imported_file_id,
      "match_band" => Atom.to_string(candidate.match_band),
      "score" => candidate.score,
      "reasons" => Enum.map(candidate.reasons, &Atom.to_string/1)
    }
  end

  defp normalize_match_candidate(candidate) do
    Map.update!(candidate, :reasons, &Enum.reverse/1)
  end

  # ---------------------------------------------------------------------------
  # Audit helpers
  # ---------------------------------------------------------------------------

  defp session_audit_meta(opts, overrides \\ []) do
    base = %{
      actor: audit_actor(opts),
      channel: audit_channel(opts),
      entity_type: @session_entity_type,
      serializer: &session_snapshot/1
    }

    Enum.reduce(overrides, base, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp extract_audit_metadata(opts) do
    %{
      actor: audit_actor(opts),
      channel: audit_channel(opts)
    }
  end

  defp audit_actor(opts) do
    opts
    |> Keyword.get(:actor, @default_actor)
    |> Audit.normalize_actor()
  end

  defp audit_channel(opts) do
    opts
    |> Keyword.get(:channel, :system)
    |> Audit.normalize_channel()
  end

  defp session_snapshot(%ReconciliationSession{} = session) do
    %{
      "id" => session.id,
      "account_id" => session.account_id,
      "entity_id" => session.entity_id,
      "statement_date" => maybe_date_to_iso8601(session.statement_date),
      "statement_balance" => decimal_to_string(session.statement_balance),
      "completed_at" => maybe_datetime_to_iso8601(session.completed_at),
      "inserted_at" => maybe_datetime_to_iso8601(session.inserted_at),
      "updated_at" => maybe_datetime_to_iso8601(session.updated_at)
    }
  end

  # ---------------------------------------------------------------------------
  # Query filters
  # ---------------------------------------------------------------------------

  defp require_entity_scope!(opts, function_name) do
    case Keyword.fetch(opts, :entity_id) do
      {:ok, entity_id} when not is_nil(entity_id) -> opts
      _ -> raise ArgumentError, "#{function_name} requires :entity_id"
    end
  end

  defp filter_query({:sessions, query}, []), do: query

  defp filter_query({:sessions, query}, [{:entity_id, entity_id} | rest]) do
    query
    |> where([session], session.entity_id == ^entity_id)
    |> then(&filter_query({:sessions, &1}, rest))
  end

  defp filter_query({:sessions, query}, [{:account_id, account_id} | rest]) do
    query
    |> where([session], session.account_id == ^account_id)
    |> then(&filter_query({:sessions, &1}, rest))
  end

  defp filter_query({:sessions, query}, [{:include_completed, true} | rest]) do
    filter_query({:sessions, query}, rest)
  end

  defp filter_query({:sessions, query}, [{:include_completed, false} | rest]) do
    query
    |> where([session], is_nil(session.completed_at))
    |> then(&filter_query({:sessions, &1}, rest))
  end

  defp filter_query({:sessions, query}, [_unknown | rest]) do
    filter_query({:sessions, query}, rest)
  end

  defp filter_query({:postings, query}, []), do: query

  defp filter_query({:postings, query}, [{:entity_id, entity_id} | rest]) do
    query
    |> where([_posting, transaction, _state], transaction.entity_id == ^entity_id)
    |> then(&filter_query({:postings, &1}, rest))
  end

  defp filter_query({:postings, query}, [_unknown | rest]) do
    filter_query({:postings, query}, rest)
  end

  defp filter_query({:balance, query}, []), do: query

  defp filter_query({:balance, query}, [{:entity_id, entity_id} | rest]) do
    query
    |> where([_posting, transaction, _state], transaction.entity_id == ^entity_id)
    |> then(&filter_query({:balance, &1}, rest))
  end

  defp filter_query({:balance, query}, [_unknown | rest]) do
    filter_query({:balance, query}, rest)
  end

  # ---------------------------------------------------------------------------
  # Result normalization
  # ---------------------------------------------------------------------------

  defp normalize_posting_status(nil), do: :unreconciled
  defp normalize_posting_status(:cleared), do: :cleared
  defp normalize_posting_status(:reconciled), do: :reconciled
  defp normalize_posting_status("cleared"), do: :cleared
  defp normalize_posting_status("reconciled"), do: :reconciled
  defp normalize_posting_status("unreconciled"), do: :unreconciled

  defp normalize_reconciliation_posting(posting) do
    Map.update!(posting, :reconciliation_status, &normalize_posting_status/1)
  end

  defp normalize_session_multi_result({:ok, %{session: session}}), do: {:ok, session}
  defp normalize_session_multi_result({:error, _step, reason, _changes}), do: {:error, reason}

  defp normalize_states_multi_result({:ok, %{posting_reconciliation_states: states}}),
    do: {:ok, states}

  defp normalize_states_multi_result({:error, _step, reason, _changes}), do: {:error, reason}

  defp normalize_unclear_multi_result({:ok, %{deleted_states: posting_ids}}),
    do: {:ok, posting_ids}

  defp normalize_unclear_multi_result({:error, _step, reason, _changes}), do: {:error, reason}

  # ---------------------------------------------------------------------------
  # Serialization helpers
  # ---------------------------------------------------------------------------

  defp decimal_to_string(nil), do: nil
  defp decimal_to_string(%Decimal{} = decimal), do: Decimal.to_string(decimal)

  defp maybe_date_to_iso8601(nil), do: nil
  defp maybe_date_to_iso8601(%Date{} = date), do: Date.to_iso8601(date)

  defp maybe_datetime_to_iso8601(nil), do: nil
  defp maybe_datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp utc_now do
    DateTime.utc_now() |> DateTime.truncate(:microsecond)
  end
end
