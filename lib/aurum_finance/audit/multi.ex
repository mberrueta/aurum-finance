defmodule AurumFinance.Audit.Multi do
  @moduledoc """
  Helpers for appending audit events to an existing `Ecto.Multi` pipeline.

  Used by domain contexts that orchestrate multiple steps in a single transaction
  (e.g., voiding a transaction or applying a manual override). The audit event is
  appended as a named step so it commits atomically with the rest of the pipeline.
  """

  alias AurumFinance.Audit
  alias AurumFinance.Audit.AuditEvent

  @doc """
  Appends an audit event insert step to an existing `Ecto.Multi`.

  The `after` snapshot is derived by calling `meta.serializer` on the result of
  the named `step_name` in the Multi. The `before_snapshot` is captured by the
  caller before the Multi is built (already redacted if needed).

  ## Parameters

    - `multi` - the `Ecto.Multi` pipeline to extend
    - `step_name` - the atom name of the prior Multi step whose result provides the `after` state
    - `before_snapshot` - pre-operation snapshot (`nil` for inserts), already serialized
    - `meta` - audit metadata map with keys:
      - `:actor` (required) - who triggered the change
      - `:channel` (required) - how the change was initiated
      - `:entity_type` (required) - lowercase singular name of the audited schema
      - `:entity_id` (optional) - UUID of the audited record; if omitted, derived from step result
      - `:action` (required) - verb describing the operation
      - `:redact_fields` (optional) - keys to redact in snapshots, default `[]`
      - `:metadata` (optional) - catch-all map for context-specific data
      - `:serializer` (optional) - function to convert result struct to snapshot map

  ## Returns

  The extended `Ecto.Multi` with the audit event step appended.

  ## Examples

      meta = %{
        actor: "root",
        channel: :web,
        entity_type: "transaction",
        action: "voided"
      }

      {:ok, %{voided: transaction}} =
        Ecto.Multi.new()
        |> Ecto.Multi.update(:voided, changeset)
        |> Audit.Multi.append_event(:voided, before_snapshot, meta)
        |> Repo.transaction()

  With a `before` snapshot (update scenario):

      before_snapshot = Audit.default_snapshot(account)
      meta = %{actor: "root", channel: :web, entity_type: "account", action: "updated"}

      {:ok, %{account: updated}} =
        Ecto.Multi.new()
        |> Ecto.Multi.update(:account, changeset)
        |> Audit.Multi.append_event(:account, before_snapshot, meta)
        |> Repo.transaction()
  """
  @spec append_event(Ecto.Multi.t(), atom(), map() | nil, map()) :: Ecto.Multi.t()
  def append_event(multi, step_name, before_snapshot, meta) do
    audit_step_name = {:audit, step_name}
    redact_fields = Map.get(meta, :redact_fields, [])
    serializer = Map.get(meta, :serializer, &Audit.default_snapshot/1)

    redacted_before = Audit.redact_snapshot(before_snapshot, redact_fields)

    Ecto.Multi.insert(multi, audit_step_name, fn changes ->
      step_result = Map.fetch!(changes, step_name)
      after_snapshot = serializer.(step_result)
      redacted_after = Audit.redact_snapshot(after_snapshot, redact_fields)

      entity_id = Map.get(meta, :entity_id) || infer_entity_id(step_result)

      # Audit metadata is not redacted. Do not store secrets, tokens, tax IDs,
      # account refs, or other sensitive values in metadata.
      # Future enhancement: add allowlisting and/or redaction for selected
      # metadata keys before wider audit-domain adoption.
      attrs = %{
        entity_type: meta.entity_type,
        entity_id: entity_id,
        action: meta.action,
        actor: Audit.normalize_actor(meta[:actor]),
        channel: Audit.normalize_channel(meta[:channel]),
        before: redacted_before,
        after: redacted_after,
        metadata: Map.get(meta, :metadata),
        occurred_at: DateTime.utc_now()
      }

      AuditEvent.changeset(%AuditEvent{}, attrs)
    end)
  end

  defp infer_entity_id(%{id: id}) when not is_nil(id), do: id
  defp infer_entity_id(_), do: nil
end
