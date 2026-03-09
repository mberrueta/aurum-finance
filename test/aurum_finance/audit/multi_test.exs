defmodule AurumFinance.Audit.MultiTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit
  alias AurumFinance.Audit.AuditEvent
  alias AurumFinance.Audit.Multi
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Repo

  describe "append_event/4 insert flows" do
    test "S26: records an audit event for a successful insert using inferred entity_id" do
      name = unique_name("Multi insert success")

      changeset =
        Entity.changeset(%Entity{}, %{
          name: name,
          type: :individual,
          country_code: "US",
          tax_identifier: "SECRET-INSERT"
        })

      assert {:ok, %{entity: entity}} =
               Ecto.Multi.new()
               |> Ecto.Multi.insert(:entity, changeset)
               |> Multi.append_event(:entity, nil, %{
                 actor: "root",
                 channel: :web,
                 entity_type: "entity",
                 action: "created",
                 redact_fields: [:tax_identifier],
                 serializer: &entity_snapshot/1
               })
               |> Repo.transaction()

      event = fetch_event(entity.id, "created")

      assert event.before == nil
      assert event.after["name"] == name
      assert event.after["tax_identifier"] == "[REDACTED]"
      assert event.entity_id == entity.id
    end

    test "S27: rolls back the insert when the audit append is invalid" do
      name = unique_name("Multi insert rollback")

      changeset =
        Entity.changeset(%Entity{}, %{
          name: name,
          type: :individual,
          country_code: "US"
        })

      assert {:error, {:audit, :entity}, %Ecto.Changeset{} = changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.insert(:entity, changeset)
               |> Multi.append_event(:entity, nil, %{
                 actor: "root",
                 channel: :web,
                 entity_type: nil,
                 action: "created"
               })
               |> Repo.transaction()

      refute changeset.valid?
      assert Repo.get_by(Entity, name: name) == nil
      assert Repo.aggregate(AuditEvent, :count, :id) == 0
    end

    test "S28: rolls back when entity_id cannot be inferred and none is provided" do
      assert {:error, {:audit, :payload}, %Ecto.Changeset{} = changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.put(:payload, %{name: "payload without id"})
               |> Multi.append_event(:payload, nil, %{
                 actor: "root",
                 channel: :web,
                 entity_type: "entity",
                 action: "created"
               })
               |> Repo.transaction()

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).entity_id
      assert Repo.aggregate(AuditEvent, :count, :id) == 0
    end

    test "S29: supports explicit entity_id when the step result has no id" do
      explicit_id = Ecto.UUID.generate()

      assert {:ok, %{payload: payload}} =
               Ecto.Multi.new()
               |> Ecto.Multi.put(:payload, %{name: "synthetic payload"})
               |> Multi.append_event(:payload, nil, %{
                 actor: "root",
                 channel: :mcp,
                 entity_type: "synthetic_entity",
                 entity_id: explicit_id,
                 action: "created",
                 serializer: &Map.new/1
               })
               |> Repo.transaction()

      event = fetch_event(explicit_id, "created")

      assert payload == %{name: "synthetic payload"}
      assert event.entity_type == "synthetic_entity"
      assert event.channel == :mcp
      assert event.after == %{"name" => "synthetic payload"}
    end
  end

  describe "append_event/4 update flows" do
    test "S30: records before and after snapshots for a successful update" do
      entity = entity_fixture(%{name: unique_name("Multi update"), tax_identifier: "OLD-UPDATE"})
      before_snapshot = entity_snapshot(entity)
      changeset = Entity.changeset(entity, %{notes: "updated", tax_identifier: "NEW-UPDATE"})

      assert {:ok, %{entity: updated}} =
               Ecto.Multi.new()
               |> Ecto.Multi.update(:entity, changeset)
               |> Multi.append_event(:entity, before_snapshot, %{
                 actor: "scheduler",
                 channel: :system,
                 entity_type: "entity",
                 action: "updated",
                 redact_fields: [:tax_identifier],
                 serializer: &entity_snapshot/1
               })
               |> Repo.transaction()

      event = fetch_event(entity.id, "updated")

      assert updated.notes == "updated"
      assert event.before["notes"] == entity.notes
      assert event.after["notes"] == "updated"
      assert event.before["tax_identifier"] == "[REDACTED]"
      assert event.after["tax_identifier"] == "[REDACTED]"
    end

    test "S31: does not append an audit event when the update step fails" do
      entity = entity_fixture(%{name: unique_name("Multi invalid update")})
      before_snapshot = entity_snapshot(entity)
      changeset = Entity.changeset(entity, %{name: nil})
      before_event_count = length(Audit.list_audit_events(entity_id: entity.id))

      assert {:error, :entity, %Ecto.Changeset{} = changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.update(:entity, changeset)
               |> Multi.append_event(:entity, before_snapshot, %{
                 actor: "scheduler",
                 channel: :system,
                 entity_type: "entity",
                 action: "updated",
                 serializer: &entity_snapshot/1
               })
               |> Repo.transaction()

      refute changeset.valid?
      assert Repo.get(Entity, entity.id).name == entity.name
      assert length(Audit.list_audit_events(entity_id: entity.id)) == before_event_count
    end

    test "S32: rolls back a successful update when the audit append fails" do
      entity = entity_fixture(%{name: unique_name("Multi update rollback")})
      before_snapshot = entity_snapshot(entity)
      changeset = Entity.changeset(entity, %{notes: "rolled back"})

      assert {:error, {:audit, :entity}, %Ecto.Changeset{} = changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.update(:entity, changeset)
               |> Multi.append_event(:entity, before_snapshot, %{
                 actor: "scheduler",
                 channel: :system,
                 entity_type: nil,
                 action: "updated",
                 serializer: &entity_snapshot/1
               })
               |> Repo.transaction()

      refute changeset.valid?
      assert Repo.get(Entity, entity.id).notes == entity.notes
      assert length(Audit.list_audit_events(entity_id: entity.id)) == 1
    end
  end

  describe "append_event/4 archive-style flows" do
    test "S33: supports archive-style updates with explicit archived action" do
      entity = entity_fixture(%{name: unique_name("Multi archive")})
      before_snapshot = entity_snapshot(entity)
      archived_at = ~U[2026-03-06 10:00:00Z]
      changeset = Entity.changeset(entity, %{archived_at: archived_at})

      assert {:ok, %{entity: archived}} =
               Ecto.Multi.new()
               |> Ecto.Multi.update(:entity, changeset)
               |> Multi.append_event(:entity, before_snapshot, %{
                 actor: "root",
                 channel: :mcp,
                 entity_type: "entity",
                 action: "archived",
                 serializer: &entity_snapshot/1
               })
               |> Repo.transaction()

      event = fetch_event(entity.id, "archived")

      assert DateTime.truncate(archived.archived_at, :second) ==
               DateTime.truncate(archived_at, :second)

      assert event.before["archived_at"] == nil
      assert event.after["archived_at"] == DateTime.to_iso8601(archived.archived_at)
      assert event.channel == :mcp
    end

    test "S34: rolls back an archive-style update when the audit append fails" do
      entity = entity_fixture(%{name: unique_name("Multi archive rollback")})
      before_snapshot = entity_snapshot(entity)
      changeset = Entity.changeset(entity, %{archived_at: ~U[2026-03-06 11:00:00Z]})

      assert {:error, {:audit, :entity}, %Ecto.Changeset{} = changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.update(:entity, changeset)
               |> Multi.append_event(:entity, before_snapshot, %{
                 actor: "root",
                 channel: :mcp,
                 entity_type: "entity",
                 action: nil,
                 serializer: &entity_snapshot/1
               })
               |> Repo.transaction()

      refute changeset.valid?
      assert Repo.get(Entity, entity.id).archived_at == nil
      assert length(Audit.list_audit_events(entity_id: entity.id)) == 1
    end
  end

  defp fetch_event(entity_id, action) do
    Audit.list_audit_events(entity_id: entity_id)
    |> Enum.find(&(&1.action == action))
  end

  defp entity_snapshot(%Entity{} = entity) do
    %{
      "id" => entity.id,
      "name" => entity.name,
      "type" => entity.type,
      "tax_identifier" => entity.tax_identifier,
      "country_code" => entity.country_code,
      "fiscal_residency_country_code" => entity.fiscal_residency_country_code,
      "default_tax_rate_type" => entity.default_tax_rate_type,
      "notes" => entity.notes,
      "archived_at" => entity.archived_at,
      "inserted_at" => entity.inserted_at,
      "updated_at" => entity.updated_at
    }
  end

  defp unique_name(prefix) do
    "#{prefix} #{System.unique_integer([:positive])}"
  end
end
