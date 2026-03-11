defmodule AurumFinance.Ingestion.MaterializationRunner do
  @moduledoc """
  Executes one durable CSV import materialization run.

  This module owns the row-by-row orchestration for one
  `ImportMaterialization`. It evaluates every imported row that belongs to the
  target imported file and persists one durable
  `ImportRowMaterialization` outcome for each evaluated row.

  The runner applies the v1 CSV materialization rules directly from imported-row
  evidence. There is no manual row approval overlay.

  The row evaluation policy is:

  - `:ready` rows are candidates for ledger materialization
  - `:duplicate` rows are persisted as `:skipped`
  - `:invalid` rows are persisted as `:skipped`
  - rows already committed in any prior run are persisted as `:skipped`
  - currency mismatches are persisted as `:failed`
  - rows missing required ledger fields are persisted as `:failed`
  - successful ready rows create one ledger transaction and are persisted as
    `:committed`

  For committed rows, the runner creates an `:import` ledger transaction with:

  - one posting against the imported account
  - one balancing posting against the system-managed import clearing account for
    the same `entity_id` and `currency_code`

  The runner also guarantees:

  - durable row-level traceability for every evaluated row, including `:skipped`
  - idempotency across reruns through the committed-row uniqueness constraint
  - deterministic clearing-account reuse or creation per entity/currency
  - run-level summary counters and terminal status updates

  If the run hits a non-row-specific orchestration error, the materialization is
  marked as `:failed`. If row-level failures occurred but the run completed, the
  materialization is marked as `:completed_with_errors`.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Ingestion.ImportMaterialization
  alias AurumFinance.Ingestion.ImportRowMaterialization
  alias AurumFinance.Ingestion.ImportedRow
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Repo

  @already_committed_reason "already committed"
  @default_duplicate_reason "already imported"
  @default_invalid_reason "invalid imported row"
  @missing_amount_reason "missing amount"
  @missing_description_reason "missing description"
  @missing_posted_on_reason "missing posted_on"

  @doc """
  Executes one materialization run for one imported file.

  The runner first validates that the materialization belongs to the given
  account/imported-file pair, then moves the run to `:processing` unless it was
  already finished. From there it loads all imported rows for the file and
  evaluates them one by one.

  Row handling is deterministic:

  - `:duplicate` and `:invalid` rows become durable `:skipped` outcomes
  - previously committed rows become durable `:skipped` outcomes
  - currency mismatch becomes a durable `:failed` outcome
  - materially valid `:ready` rows create ledger transactions and durable
    `:committed` outcomes

  The function is safe to rerun for the same materialization. If the run already
  finished, it returns `:ok` without doing more work. If the worker is retried
  mid-run, existing row outcomes for that materialization are reused for
  counters, while the committed-row uniqueness constraint prevents double
  materialization of the same imported row across runs.

  Returns `:ok` when the run completes or was already finalized. Returns
  `{:error, reason}` when the run cannot be completed and is marked as
  `:failed`.

  ## Examples

  ```elixir
  :ok =
    AurumFinance.Ingestion.MaterializationRunner.run(
      account.id,
      imported_file.id,
      materialization.id
    )
  ```
  """
  @spec run(Ecto.UUID.t(), Ecto.UUID.t(), Ecto.UUID.t()) :: :ok | {:error, term()}
  def run(account_id, imported_file_id, import_materialization_id) do
    with {:ok, materialization} <-
           fetch_materialization(account_id, imported_file_id, import_materialization_id),
         {:ok, materialization} <- ensure_processing(materialization),
         {:ok, summary} <- process_rows(materialization),
         {:ok, _materialization} <- finalize_success(materialization, summary) do
      :ok
    else
      {:ok, :already_finished} ->
        :ok

      {:error, reason, %ImportMaterialization{} = materialization} ->
        finalize_failure(materialization, reason)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_materialization(account_id, imported_file_id, import_materialization_id) do
    ImportMaterialization
    |> join(:inner, [materialization], imported_file in assoc(materialization, :imported_file),
      as: :imported_file
    )
    |> where(
      [materialization, imported_file: imported_file],
      materialization.id == ^import_materialization_id and
        materialization.account_id == ^account_id and
        materialization.imported_file_id == ^imported_file_id and
        imported_file.id == ^imported_file_id and
        imported_file.account_id == ^account_id
    )
    |> preload([imported_file: imported_file], imported_file: imported_file)
    |> Repo.one()
    |> fetch_materialization_result()
  end

  defp fetch_materialization_result(%ImportMaterialization{} = materialization),
    do: {:ok, materialization}

  defp fetch_materialization_result(nil), do: {:error, :not_found}

  defp ensure_processing(%ImportMaterialization{status: status})
       when status in [:completed, :completed_with_errors],
       do: {:ok, :already_finished}

  defp ensure_processing(%ImportMaterialization{} = materialization) do
    materialization
    |> ImportMaterialization.changeset(%{
      status: :processing,
      started_at: materialization.started_at || now(),
      finished_at: nil,
      error_message: nil
    })
    |> Repo.update()
  end

  defp process_rows(%ImportMaterialization{} = materialization) do
    rows = list_materialization_rows(materialization)

    state = %{
      clearing_accounts: %{},
      committed_rows_by_id: committed_rows_by_id(rows),
      existing_outcomes_by_row_id: existing_outcomes_by_row_id(materialization),
      rows_considered: 0,
      rows_failed: 0,
      rows_materialized: 0,
      rows_skipped_duplicate: 0
    }

    rows
    |> Enum.reduce_while({:ok, state}, fn row, {:ok, acc} ->
      row
      |> evaluate_row(materialization, acc)
      |> reduce_row_result()
    end)
    |> process_rows_result()
  end

  defp list_materialization_rows(%ImportMaterialization{} = materialization) do
    ImportedRow
    |> where([imported_row], imported_row.imported_file_id == ^materialization.imported_file_id)
    |> preload([:account])
    |> order_by([imported_row], asc: imported_row.row_index, asc: imported_row.inserted_at)
    |> Repo.all()
  end

  defp committed_rows_by_id(rows) do
    rows
    |> Enum.map(& &1.id)
    |> committed_rows_by_id_query()
    |> Repo.all()
    |> Map.new()
  end

  defp committed_rows_by_id_query([]) do
    from(row_materialization in ImportRowMaterialization, where: false)
  end

  defp committed_rows_by_id_query(row_ids) do
    from(row_materialization in ImportRowMaterialization,
      where:
        row_materialization.imported_row_id in ^row_ids and
          row_materialization.status == :committed,
      select: {row_materialization.imported_row_id, row_materialization.transaction_id}
    )
  end

  defp existing_outcomes_by_row_id(%ImportMaterialization{} = materialization) do
    from(row_materialization in ImportRowMaterialization,
      where: row_materialization.import_materialization_id == ^materialization.id,
      select:
        {row_materialization.imported_row_id,
         %{
           outcome_reason: row_materialization.outcome_reason,
           status: row_materialization.status,
           transaction_id: row_materialization.transaction_id
         }}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp evaluate_row(%ImportedRow{id: row_id} = row, materialization, state) do
    state.existing_outcomes_by_row_id
    |> Map.get(row_id)
    |> evaluate_existing_or_new_row(row, materialization, state)
  end

  defp evaluate_existing_or_new_row(nil, row, materialization, state) do
    evaluate_new_row(row, materialization, state)
  end

  defp evaluate_existing_or_new_row(existing_outcome, row, _materialization, state) do
    {:ok, count_existing_outcome(row, existing_outcome, state)}
  end

  defp evaluate_new_row(%ImportedRow{status: :duplicate} = row, materialization, state) do
    row
    |> duplicate_reason()
    |> record_skipped_row(materialization, row, state)
  end

  defp evaluate_new_row(%ImportedRow{status: :invalid} = row, materialization, state) do
    row
    |> invalid_reason()
    |> record_skipped_row(materialization, row, state)
  end

  defp evaluate_new_row(%ImportedRow{status: :ready} = row, materialization, state) do
    evaluate_ready_row(row, materialization, state)
  end

  defp evaluate_ready_row(%ImportedRow{id: row_id} = row, materialization, state) do
    state.committed_rows_by_id
    |> Map.get(row_id)
    |> evaluate_committed_or_materializable_row(row, materialization, state)
  end

  defp evaluate_committed_or_materializable_row(nil, row, materialization, state) do
    with :ok <- validate_materializable_currency(row),
         :ok <- validate_materializable_fields(row),
         {:ok, clearing_account, state} <-
           resolve_clearing_account(row.account, materialization, state),
         {:ok, state} <- commit_ready_row(materialization, row, clearing_account, state) do
      {:ok, state}
    else
      {:error, :currency_mismatch, reason} ->
        record_failed_row(reason, materialization, row, state)

      {:error, :missing_fields, reason} ->
        record_failed_row(reason, materialization, row, state)

      {:error, :already_committed} ->
        record_skipped_row(@already_committed_reason, materialization, row, state)

      {:error, reason} ->
        record_failed_row(format_reason(reason), materialization, row, state)
    end
  end

  defp evaluate_committed_or_materializable_row(_transaction_id, row, materialization, state) do
    record_skipped_row(@already_committed_reason, materialization, row, state)
  end

  defp validate_materializable_currency(%ImportedRow{currency: nil}), do: :ok

  defp validate_materializable_currency(%ImportedRow{
         currency: currency,
         account: %Account{} = account
       }) do
    currency
    |> String.upcase()
    |> validate_materializable_currency_result(account.currency_code)
  end

  defp validate_materializable_currency_result(currency, currency), do: :ok

  defp validate_materializable_currency_result(row_currency, account_currency) do
    reason = "currency mismatch: row #{row_currency} vs account #{account_currency}"
    {:error, :currency_mismatch, reason}
  end

  defp validate_materializable_fields(%ImportedRow{amount: nil}),
    do: {:error, :missing_fields, @missing_amount_reason}

  defp validate_materializable_fields(%ImportedRow{description: nil}),
    do: {:error, :missing_fields, @missing_description_reason}

  defp validate_materializable_fields(%ImportedRow{posted_on: nil}),
    do: {:error, :missing_fields, @missing_posted_on_reason}

  defp validate_materializable_fields(%ImportedRow{}), do: :ok

  defp resolve_clearing_account(%Account{} = account, materialization, state) do
    cache_key = {account.entity_id, account.currency_code}

    state.clearing_accounts
    |> Map.get(cache_key)
    |> resolve_cached_or_new_clearing_account(cache_key, account, materialization, state)
  end

  defp resolve_cached_or_new_clearing_account(
         %Account{} = clearing_account,
         _cache_key,
         _account,
         _materialization,
         state
       ) do
    {:ok, clearing_account, state}
  end

  defp resolve_cached_or_new_clearing_account(nil, cache_key, account, materialization, state) do
    with {:ok, clearing_account} <- find_or_create_clearing_account(account, materialization) do
      {:ok, clearing_account, put_in(state.clearing_accounts[cache_key], clearing_account)}
    end
  end

  defp find_or_create_clearing_account(
         %Account{} = account,
         %ImportMaterialization{} = materialization
       ) do
    account
    |> list_matching_clearing_accounts()
    |> find_or_create_clearing_account_result(account, materialization)
  end

  defp list_matching_clearing_accounts(%Account{} = account) do
    from(clearing_account in Account,
      where:
        clearing_account.entity_id == ^account.entity_id and
          clearing_account.currency_code == ^account.currency_code and
          clearing_account.management_group == :system_managed and
          clearing_account.account_type == :equity and
          is_nil(clearing_account.operational_subtype) and
          is_nil(clearing_account.archived_at),
      order_by: [asc: clearing_account.inserted_at]
    )
    |> Repo.all()
  end

  defp find_or_create_clearing_account_result(
         [%Account{} = clearing_account],
         _account,
         _materialization
       ),
       do: {:ok, clearing_account}

  defp find_or_create_clearing_account_result([], account, materialization) do
    Ledger.create_account(
      %{
        entity_id: account.entity_id,
        name: "Import clearing (#{account.currency_code})",
        account_type: :equity,
        management_group: :system_managed,
        currency_code: account.currency_code,
        notes: "System-managed clearing account for CSV import materialization"
      },
      actor: materialization.requested_by,
      channel: :system
    )
  end

  defp find_or_create_clearing_account_result(_accounts, _account, _materialization) do
    {:error, "multiple import clearing accounts matched the same entity/currency"}
  end

  defp create_transaction(%ImportedRow{} = row, %Account{} = clearing_account) do
    Ledger.create_transaction(%{
      entity_id: row.account.entity_id,
      date: row.posted_on,
      description: row.description,
      source_type: :import,
      postings: [
        %{account_id: row.account_id, amount: row.amount},
        %{account_id: clearing_account.id, amount: Decimal.negate(row.amount)}
      ]
    })
  end

  defp commit_ready_row(materialization, row, clearing_account, state) do
    Repo.transaction(fn ->
      with {:ok, transaction} <- create_transaction(row, clearing_account),
           {:ok, row_outcome} <-
             insert_row_materialization(%{
               import_materialization_id: materialization.id,
               imported_row_id: row.id,
               transaction_id: transaction.id,
               status: :committed
             }) do
        {transaction, row_outcome}
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          maybe_rollback_already_committed(changeset)

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
    |> commit_ready_row_result(row, state)
  end

  defp commit_ready_row_result({:ok, {transaction, _row_outcome}}, row, state) do
    {:ok,
     state
     |> count_materialized_row()
     |> count_row_considered()
     |> put_committed_row(row.id, transaction.id)}
  end

  defp commit_ready_row_result({:error, :already_committed}, _row, _state) do
    {:error, :already_committed}
  end

  defp commit_ready_row_result({:error, reason}, _row, _state), do: {:error, reason}

  defp maybe_rollback_already_committed(%Ecto.Changeset{errors: errors} = changeset) do
    changeset
    |> already_committed_constraint_error?(errors)
    |> maybe_rollback_already_committed(changeset)
  end

  defp maybe_rollback_already_committed(true, _changeset), do: Repo.rollback(:already_committed)
  defp maybe_rollback_already_committed(false, changeset), do: Repo.rollback(changeset)

  defp already_committed_constraint_error?(changeset, errors) do
    Enum.any?(errors, fn
      {:imported_row_id, {_message, [constraint: :unique, constraint_name: constraint_name]}} ->
        constraint_name == "import_row_materializations_imported_row_committed_index"

      _other ->
        false
    end) or
      Enum.any?(changeset.constraints, fn
        %{
          field: :imported_row_id,
          constraint: "import_row_materializations_imported_row_committed_index"
        } ->
          true

        _constraint ->
          false
      end)
  end

  defp record_skipped_row(reason, materialization, row, state) do
    materialization
    |> row_outcome_attrs(row, :skipped, reason)
    |> insert_row_materialization()
    |> record_skipped_row_result(row, state)
  end

  defp record_failed_row(reason, materialization, row, state) do
    materialization
    |> row_outcome_attrs(row, :failed, reason)
    |> insert_row_materialization()
    |> record_failed_row_result(state)
  end

  defp row_outcome_attrs(
         %ImportMaterialization{} = materialization,
         %ImportedRow{} = row,
         status,
         reason
       ) do
    %{
      import_materialization_id: materialization.id,
      imported_row_id: row.id,
      outcome_reason: reason,
      status: status
    }
  end

  defp insert_row_materialization(attrs) do
    %ImportRowMaterialization{}
    |> ImportRowMaterialization.changeset(attrs)
    |> Repo.insert()
  end

  defp record_skipped_row_result({:ok, _row_outcome}, row, state) do
    {:ok,
     state
     |> count_duplicate_skip(row)
     |> count_row_considered()}
  end

  defp record_skipped_row_result({:error, reason}, _row, _state), do: {:error, reason}

  defp record_failed_row_result({:ok, _row_outcome}, state) do
    {:ok,
     state
     |> count_failed_row()
     |> count_row_considered()}
  end

  defp record_failed_row_result({:error, reason}, _state), do: {:error, reason}

  defp count_existing_outcome(
         %ImportedRow{} = row,
         %{status: :committed, transaction_id: transaction_id},
         state
       ) do
    state
    |> count_materialized_row()
    |> count_row_considered()
    |> put_committed_row(row.id, transaction_id)
  end

  defp count_existing_outcome(%ImportedRow{} = row, %{status: :failed}, state) do
    state
    |> count_failed_row()
    |> count_row_considered()
    |> count_duplicate_skip(row)
  end

  defp count_existing_outcome(%ImportedRow{} = row, %{status: :skipped}, state) do
    state
    |> count_row_considered()
    |> count_duplicate_skip(row)
  end

  defp count_row_considered(state), do: %{state | rows_considered: state.rows_considered + 1}

  defp count_materialized_row(state),
    do: %{state | rows_materialized: state.rows_materialized + 1}

  defp count_failed_row(state), do: %{state | rows_failed: state.rows_failed + 1}

  defp count_duplicate_skip(state, %ImportedRow{status: :duplicate}) do
    %{state | rows_skipped_duplicate: state.rows_skipped_duplicate + 1}
  end

  defp count_duplicate_skip(state, %ImportedRow{}), do: state

  defp put_committed_row(state, row_id, transaction_id) do
    put_in(state.committed_rows_by_id[row_id], transaction_id)
  end

  defp reduce_row_result({:ok, state}), do: {:cont, {:ok, state}}
  defp reduce_row_result({:error, reason}), do: {:halt, {:error, reason}}

  defp process_rows_result({:ok, state}), do: {:ok, Map.take(state, summary_keys())}
  defp process_rows_result({:error, reason}), do: {:error, reason}

  defp summary_keys do
    [:rows_considered, :rows_failed, :rows_materialized, :rows_skipped_duplicate]
  end

  defp finalize_success(%ImportMaterialization{} = materialization, summary) do
    materialization
    |> ImportMaterialization.changeset(%{
      error_message: nil,
      finished_at: now(),
      rows_considered: summary.rows_considered,
      rows_failed: summary.rows_failed,
      rows_materialized: summary.rows_materialized,
      rows_skipped_duplicate: summary.rows_skipped_duplicate,
      status: final_status(summary)
    })
    |> Repo.update()
  end

  defp final_status(%{rows_failed: 0}), do: :completed
  defp final_status(%{rows_failed: rows_failed}) when rows_failed > 0, do: :completed_with_errors

  defp finalize_failure(%ImportMaterialization{} = materialization, reason) do
    materialization
    |> ImportMaterialization.changeset(%{
      error_message: format_reason(reason),
      finished_at: now(),
      status: :failed
    })
    |> Repo.update()
    |> finalize_failure_result(reason)
  end

  defp finalize_failure_result({:ok, _materialization}, reason), do: {:error, reason}
  defp finalize_failure_result({:error, reason}, _original_reason), do: {:error, reason}

  defp duplicate_reason(%ImportedRow{skip_reason: nil}), do: @default_duplicate_reason
  defp duplicate_reason(%ImportedRow{skip_reason: reason}), do: reason

  defp invalid_reason(%ImportedRow{validation_error: nil}), do: @default_invalid_reason
  defp invalid_reason(%ImportedRow{validation_error: reason}), do: reason

  defp format_reason(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.map_join(", ", fn {field, messages} ->
      "#{field} #{Enum.join(messages, ", ")}"
    end)
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
