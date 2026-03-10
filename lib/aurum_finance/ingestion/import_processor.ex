defmodule AurumFinance.Ingestion.ImportProcessor do
  @moduledoc """
  Asynchronous orchestrator for one imported file processing run.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Audit.AuditEvent
  alias AurumFinance.Helpers
  alias AurumFinance.Ingestion
  alias AurumFinance.Ingestion.Fingerprint
  alias AurumFinance.Ingestion.ImportedFile
  alias AurumFinance.Ingestion.ParserError
  alias AurumFinance.Ingestion.RowNormalizer
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Repo

  @chunk_size 500
  @max_concurrency System.schedulers_online()
  @duplicate_skip_reason "already imported"
  @audit_entity_type "imported_file"
  @audit_actor "system"
  @audit_channel :system

  @type run_result :: {:ok, ImportedFile.t()} | {:error, term()}

  @doc """
  Processes one imported file end-to-end.

  Files already in `processing` or `complete` are left unchanged.
  """
  @spec run(ImportedFile.t()) :: run_result()
  def run(%ImportedFile{} = imported_file) do
    try do
      imported_file
      |> claim_import()
      |> process_claimed_import()
    rescue
      exception ->
        fail_import(imported_file, Exception.message(exception))
    end
  end

  defp claim_import(%ImportedFile{} = imported_file) do
    Repo.transaction(fn ->
      imported_file
      |> get_imported_file_for_update!()
      |> claim_locked_import()
    end)
    |> normalize_claim_result()
  end

  defp process_claimed_import({:skip, %ImportedFile{} = imported_file}), do: {:ok, imported_file}
  defp process_claimed_import({:error, reason}), do: {:error, reason}

  defp process_claimed_import({:ok, %ImportedFile{} = imported_file}) do
    imported_file
    |> Ingestion.parse_imported_file()
    |> handle_parse_result(imported_file)
  end

  defp process_parsed_import(%ImportedFile{} = imported_file, parsed_import) do
    account = Repo.get!(Account, imported_file.account_id)

    Repo.transaction(fn ->
      summary =
        imported_file
        |> initial_state(account, parsed_import)
        |> persist_rows(parsed_import.rows)
        |> finalize_summary(parsed_import)

      imported_file
      |> reload_imported_file()
      |> complete_import(summary)
    end)
    |> handle_processing_transaction_result(imported_file)
  end

  defp initial_state(imported_file, account, parsed_import) do
    %{
      imported_file: imported_file,
      account: account,
      seen_ready_fingerprints: MapSet.new(),
      imported_row_count: 0,
      skipped_row_count: 0,
      invalid_row_count: 0,
      row_count: parsed_import.row_count,
      warnings: warnings_map(parsed_import.warnings)
    }
  end

  defp persist_rows(state, rows) do
    rows
    |> Stream.zip(RowNormalizer.normalize_rows(rows, account: state.account))
    |> Stream.chunk_every(@chunk_size)
    |> Enum.reduce(state, &persist_chunk/2)
  end

  defp persist_chunk(chunk, state) do
    prepared_rows =
      chunk
      |> Task.async_stream(
        &prepare_row(&1, state.imported_file, state.account),
        max_concurrency: min(length(chunk), @max_concurrency),
        ordered: true,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, prepared_row} -> prepared_row end)

    duplicate_fingerprints =
      prepared_rows
      |> ready_fingerprints()
      |> merge_duplicate_fingerprints(state)

    Enum.reduce(
      prepared_rows,
      %{state | seen_ready_fingerprints: duplicate_fingerprints},
      fn prepared_row, acc ->
        persist_prepared_row(prepared_row, acc)
      end
    )
  end

  defp prepare_row({original_row, normalized_row}, imported_file, account) do
    description = normalize_optional_text(Map.get(original_row.canonical_data, :description))

    normalized_description =
      normalize_optional_text(Map.get(normalized_row.canonical_data, :description))

    currency = normalize_optional_text(Map.get(normalized_row.canonical_data, :currency))
    posted_on = parse_posted_on(Map.get(normalized_row.canonical_data, :posted_on))
    amount = parse_amount(Map.get(normalized_row.canonical_data, :amount))

    base_attrs = %{
      imported_file_id: imported_file.id,
      account_id: account.id,
      row_index: normalized_row.row_index,
      raw_data: normalized_row.raw_data,
      description: description,
      normalized_description: normalized_description,
      currency: currency
    }

    validation_errors(description, posted_on, amount)
    |> build_prepared_row(base_attrs, normalized_row, posted_on, amount)
  end

  defp ready_row_attrs(normalized_row, {:ok, posted_on}, {:ok, amount}) do
    %{
      posted_on: posted_on,
      amount: amount,
      fingerprint: Fingerprint.build(normalized_row.canonical_data),
      status: :ready
    }
  end

  defp validation_errors(description, posted_on, amount) do
    []
    |> maybe_add_error(Helpers.blank?(description), "missing description")
    |> maybe_add_error(not match?({:ok, _posted_on}, posted_on), "invalid posted_on")
    |> maybe_add_error(not match?({:ok, _amount}, amount), "invalid amount")
  end

  defp maybe_add_error(errors, true, error), do: [error | errors]
  defp maybe_add_error(errors, false, _error), do: errors

  defp parse_posted_on(value) when is_binary(value), do: Date.from_iso8601(value)
  defp parse_posted_on(_value), do: {:error, :invalid_posted_on}

  defp parse_amount(value) when is_binary(value) do
    case Decimal.parse(value) do
      {amount, ""} -> {:ok, amount}
      _ -> {:error, :invalid_amount}
    end
  end

  defp parse_amount(_value), do: {:error, :invalid_amount}

  defp normalize_optional_text(value) when is_binary(value) do
    value
    |> Helpers.normalize_string()
    |> Helpers.blank_to_nil()
  end

  defp normalize_optional_text(value), do: value

  defp ready_fingerprints(prepared_rows) do
    prepared_rows
    |> Enum.filter(&match?(%{status: :ready}, &1))
    |> Enum.map(& &1.attrs.fingerprint)
    |> Enum.uniq()
  end

  defp existing_duplicate_fingerprints(account_id, fingerprints) do
    Ingestion.list_duplicate_fingerprints(account_id: account_id, fingerprints: fingerprints)
  end

  defp persist_prepared_row(%{status: :invalid, attrs: attrs}, state) do
    attrs
    |> Ingestion.create_imported_row()
    |> handle_invalid_insert_result(state)
  end

  defp persist_prepared_row(%{status: :ready, attrs: attrs}, state) do
    persist_ready_row(
      attrs,
      state,
      MapSet.member?(state.seen_ready_fingerprints, attrs.fingerprint)
    )
  end

  defp handle_ready_insert_error(attrs, changeset, state) do
    handle_ready_insert_error(attrs, changeset, state, ready_fingerprint_conflict?(changeset))
  end

  defp handle_ready_insert_error(attrs, _changeset, state, true),
    do: persist_duplicate_row(duplicate_attrs(attrs), state)

  defp handle_ready_insert_error(_attrs, changeset, _state, false), do: Repo.rollback(changeset)

  defp persist_duplicate_row(attrs, state) do
    attrs
    |> Ingestion.create_imported_row()
    |> handle_duplicate_insert_result(state)
  end

  defp duplicate_attrs(attrs) do
    attrs
    |> Map.put(:status, :duplicate)
    |> Map.put(:skip_reason, @duplicate_skip_reason)
  end

  defp ready_fingerprint_conflict?(changeset) do
    Enum.any?(changeset.errors, fn
      {:fingerprint, {_message, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end

  defp finalize_summary(state, parsed_import) do
    %{
      row_count: parsed_import.row_count,
      imported_row_count: state.imported_row_count,
      skipped_row_count: state.skipped_row_count,
      invalid_row_count: state.invalid_row_count,
      warnings: state.warnings
    }
  end

  defp completed_import_attrs(summary) do
    %{
      status: :complete,
      row_count: summary.row_count,
      imported_row_count: summary.imported_row_count,
      skipped_row_count: summary.skipped_row_count,
      invalid_row_count: summary.invalid_row_count,
      warnings: summary.warnings,
      error_message: nil,
      processed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }
  end

  defp fail_import(%ImportedFile{} = imported_file, message) do
    imported_file
    |> reload_imported_file()
    |> transition_with_audit(
      %{
        status: :failed,
        error_message: message,
        processed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      },
      "processing_failed"
    )
  end

  defp transition_to_processing(imported_file),
    do:
      transition_with_audit!(
        imported_file,
        %{
          status: :processing,
          row_count: 0,
          imported_row_count: 0,
          skipped_row_count: 0,
          invalid_row_count: 0,
          warnings: %{},
          error_message: nil,
          processed_at: nil
        },
        "processing_started"
      )

  defp complete_import(imported_file, summary),
    do:
      transition_with_audit!(
        imported_file,
        completed_import_attrs(summary),
        "processing_completed"
      )

  defp get_imported_file_for_update!(%ImportedFile{id: imported_file_id}) do
    ImportedFile
    |> where([imported_file], imported_file.id == ^imported_file_id)
    |> lock("FOR UPDATE")
    |> Repo.one!()
  end

  defp reload_imported_file(%ImportedFile{id: imported_file_id}),
    do: Repo.get!(ImportedFile, imported_file_id)

  defp warnings_map(_warnings), do: %{}

  defp format_failure(%ParserError{message: message}), do: message
  defp format_failure(%Ecto.Changeset{} = changeset), do: inspect(changeset.errors)
  defp format_failure(reason) when is_binary(reason), do: reason
  defp format_failure(reason), do: inspect(reason)

  defp transition_with_audit!(imported_file, attrs, action) do
    imported_file
    |> transition_with_audit(attrs, action)
    |> unwrap_transition_result()
  end

  defp transition_with_audit(imported_file, attrs, action) do
    before_snapshot = Audit.default_snapshot(imported_file)
    changeset = ImportedFile.changeset(imported_file, attrs)

    Repo.transaction(fn ->
      updated_import = Repo.update!(changeset)

      %AuditEvent{}
      |> Audit.change_audit_event(import_audit_attrs(updated_import, before_snapshot, action))
      |> Repo.insert!()

      updated_import
    end)
    |> normalize_repo_transaction_result()
  end

  defp import_audit_attrs(imported_file, before_snapshot, action) do
    %{
      entity_type: @audit_entity_type,
      entity_id: imported_file.id,
      action: action,
      actor: Audit.normalize_actor(@audit_actor),
      channel: Audit.normalize_channel(@audit_channel),
      before: before_snapshot,
      after: Audit.default_snapshot(imported_file),
      metadata: %{
        account_id: imported_file.account_id
      },
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }
  end

  defp claim_locked_import(%ImportedFile{status: status} = imported_file)
       when status in [:pending, :failed],
       do: {:ok, transition_to_processing(imported_file)}

  defp claim_locked_import(%ImportedFile{status: status} = imported_file)
       when status in [:processing, :complete],
       do: {:skip, imported_file}

  defp handle_processing_transaction_result({:ok, completed_import}, _imported_file),
    do: {:ok, completed_import}

  defp handle_processing_transaction_result({:error, reason}, imported_file),
    do: fail_import(imported_file, format_failure(reason))

  defp handle_parse_result({:ok, parsed_import}, imported_file),
    do: process_parsed_import(imported_file, parsed_import)

  defp handle_parse_result({:error, reason}, imported_file),
    do: fail_import(imported_file, format_failure(reason))

  defp merge_duplicate_fingerprints([], state), do: state.seen_ready_fingerprints

  defp merge_duplicate_fingerprints(fingerprints, state) do
    state.account.id
    |> existing_duplicate_fingerprints(fingerprints)
    |> MapSet.union(state.seen_ready_fingerprints)
  end

  defp build_prepared_row([], base_attrs, normalized_row, {:ok, posted_on}, {:ok, amount}) do
    %{
      attrs:
        Map.merge(base_attrs, ready_row_attrs(normalized_row, {:ok, posted_on}, {:ok, amount})),
      status: :ready
    }
  end

  defp build_prepared_row(errors, base_attrs, _normalized_row, _posted_on, _amount) do
    %{
      attrs:
        Map.merge(base_attrs, %{
          status: :invalid,
          validation_error: Enum.join(errors, "; ")
        }),
      status: :invalid
    }
  end

  defp persist_ready_row(attrs, state, true),
    do: persist_duplicate_row(duplicate_attrs(attrs), state)

  defp persist_ready_row(attrs, state, false) do
    attrs
    |> Ingestion.create_imported_row()
    |> handle_ready_insert_result(attrs, state)
  end

  defp unwrap_transition_result({:ok, updated_import}), do: updated_import
  defp unwrap_transition_result({:error, reason}), do: Repo.rollback(reason)

  defp normalize_claim_result({:ok, result}), do: result
  defp normalize_claim_result({:error, reason}), do: {:error, reason}

  defp normalize_repo_transaction_result({:ok, result}), do: {:ok, result}
  defp normalize_repo_transaction_result({:error, reason}), do: {:error, reason}

  defp handle_invalid_insert_result({:ok, _row}, state),
    do: %{state | invalid_row_count: state.invalid_row_count + 1}

  defp handle_invalid_insert_result({:error, changeset}, _state), do: Repo.rollback(changeset)

  defp handle_duplicate_insert_result({:ok, _row}, state),
    do: %{state | skipped_row_count: state.skipped_row_count + 1}

  defp handle_duplicate_insert_result({:error, changeset}, _state), do: Repo.rollback(changeset)

  defp handle_ready_insert_result({:ok, _row}, attrs, state) do
    %{
      state
      | seen_ready_fingerprints: MapSet.put(state.seen_ready_fingerprints, attrs.fingerprint),
        imported_row_count: state.imported_row_count + 1
    }
  end

  defp handle_ready_insert_result({:error, changeset}, attrs, state),
    do: handle_ready_insert_error(attrs, changeset, state)
end
