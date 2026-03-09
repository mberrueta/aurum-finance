defmodule AurumFinance.Audit.AuditEventTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit.AuditEvent

  describe "changeset/2" do
    test "S01: accepts all required fields plus metadata" do
      changeset =
        AuditEvent.changeset(%AuditEvent{}, %{
          entity_type: "entity",
          entity_id: Ecto.UUID.generate(),
          action: "created",
          actor: "root",
          channel: :web,
          occurred_at: ~U[2026-03-01 00:00:00Z],
          metadata: %{request_id: "req-1"}
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :metadata) == %{request_id: "req-1"}
    end

    test "S02: accepts a valid changeset without metadata" do
      changeset =
        AuditEvent.changeset(%AuditEvent{}, %{
          entity_type: "entity",
          entity_id: Ecto.UUID.generate(),
          action: "created",
          actor: "root",
          channel: :web,
          occurred_at: ~U[2026-03-01 00:00:00Z]
        })

      assert changeset.valid?
      refute Map.has_key?(changeset.changes, :metadata)
    end

    test "S03: rejects missing required fields" do
      changeset = AuditEvent.changeset(%AuditEvent{}, %{})

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).entity_type
      assert "error_field_required" in errors_on(changeset).entity_id
      assert "error_field_required" in errors_on(changeset).action
      assert "error_field_required" in errors_on(changeset).actor
      assert "error_field_required" in errors_on(changeset).channel
      assert "error_field_required" in errors_on(changeset).occurred_at
    end

    test "S04: enforces max length for entity_type and action" do
      long_value = String.duplicate("a", 121)

      changeset =
        AuditEvent.changeset(%AuditEvent{}, %{
          entity_type: long_value,
          entity_id: Ecto.UUID.generate(),
          action: long_value,
          actor: "root",
          channel: :web,
          occurred_at: ~U[2026-03-01 00:00:00Z]
        })

      refute changeset.valid?
      assert "error_audit_entity_type_length_invalid" in errors_on(changeset).entity_type
      assert "error_audit_action_length_invalid" in errors_on(changeset).action
    end

    test "S05: omits updated_at from the schema struct" do
      refute Map.has_key?(%AuditEvent{}, :updated_at)
    end
  end
end
