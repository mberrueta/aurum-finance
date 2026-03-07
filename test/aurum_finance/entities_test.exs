defmodule AurumFinance.EntitiesTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit
  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity

  describe "change_entity/2" do
    test "requires name, type, and country_code" do
      changeset = Entities.change_entity(%Entity{}, %{})

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).name
      assert "error_field_required" in errors_on(changeset).type
      assert "error_field_required" in errors_on(changeset).country_code
    end

    test "accepts only canonical entity types" do
      changeset =
        Entities.change_entity(%Entity{}, %{
          name: "Invalid type entity",
          type: :company,
          country_code: "US"
        })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).type
    end

    test "exposes multiple default tax rate type options per country" do
      options = Entity.default_tax_rate_type_options("US")

      assert "irs_official" in options
      assert "us_market_close" in options
      assert "us_tax_specific" in options
      assert "us_bank_settlement" in options
    end
  end

  describe "create_entity/2" do
    test "defaults fiscal_residency_country_code from country_code when omitted" do
      assert {:ok, entity} =
               Entities.create_entity(%{
                 name: "Personal #{System.unique_integer([:positive])}",
                 type: :individual,
                 country_code: "cl"
               })

      assert entity.country_code == "CL"
      assert entity.fiscal_residency_country_code == "CL"
      assert entity.default_tax_rate_type == "sii_official"
    end

    test "allows repeated tax_identifier values" do
      attrs = %{
        tax_identifier: "SAME-TAX-ID-001",
        country_code: "US",
        type: :individual
      }

      assert {:ok, _first} = Entities.create_entity(Map.put(attrs, :name, "Entity One"))
      assert {:ok, second} = Entities.create_entity(Map.put(attrs, :name, "Entity Two"))
      assert second.tax_identifier == "SAME-TAX-ID-001"
    end
  end

  describe "archive and list behavior" do
    test "archive_entity/2 sets archived_at and excludes archived records by default" do
      entity = entity_fixture(name: "Archive target")
      assert {:ok, archived} = Entities.archive_entity(entity, actor: "person", channel: :web)
      assert %DateTime{} = archived.archived_at

      listed_active_ids = Entities.list_entities() |> Enum.map(& &1.id)
      refute archived.id in listed_active_ids

      listed_with_archived =
        Entities.list_entities(include_archived: true)
        |> Enum.map(& &1.id)

      assert archived.id in listed_with_archived
      assert Entities.get_entity!(archived.id).archived_at
    end

    test "archived entities remain editable" do
      entity = entity_fixture(name: "Editable archived")
      assert {:ok, archived} = Entities.archive_entity(entity)

      assert {:ok, updated} =
               Entities.update_entity(archived, %{
                 notes: "Updated after archive",
                 tax_identifier: "ARCH-EDIT-001"
               })

      assert updated.notes == "Updated after archive"
      assert updated.tax_identifier == "ARCH-EDIT-001"
      assert %DateTime{} = updated.archived_at
    end

    test "unarchive_entity/2 clears archived_at and returns entity to active list" do
      entity = entity_fixture(name: "Unarchive target")
      assert {:ok, archived} = Entities.archive_entity(entity)
      assert %DateTime{} = archived.archived_at

      assert {:ok, unarchived} =
               Entities.unarchive_entity(archived, actor: "person", channel: :web)

      assert is_nil(unarchived.archived_at)
      assert unarchived.id in Enum.map(Entities.list_entities(), & &1.id)
    end
  end

  describe "audit events integration" do
    test "create/update/archive/unarchive emit required audit event shape" do
      assert {:ok, entity} =
               Entities.create_entity(
                 %{
                   name: "Audit subject",
                   type: :legal_entity,
                   country_code: "AR",
                   tax_identifier: "TAX-SECRET-OLD"
                 },
                 actor: "person",
                 channel: :web
               )

      assert {:ok, entity} =
               Entities.update_entity(
                 entity,
                 %{notes: "changed", tax_identifier: "TAX-SECRET-NEW"},
                 actor: "scheduler",
                 channel: :system
               )

      assert {:ok, entity} = Entities.archive_entity(entity, actor: "person", channel: :mcp)
      assert {:ok, entity} = Entities.unarchive_entity(entity, actor: "person", channel: :web)

      events =
        Audit.list_audit_events(entity_id: entity.id)
        |> Enum.sort_by(& &1.occurred_at, {:asc, DateTime})

      assert length(events) == 4

      [created, updated, archived, unarchived] = events

      assert created.entity_type == "entity"
      assert created.entity_id == entity.id
      assert created.action == "created"
      assert created.actor == "person"
      assert created.channel == :web
      assert created.before == nil
      assert is_map(created.after)
      assert created.after["tax_identifier"] == "[REDACTED]"
      assert %DateTime{} = created.occurred_at

      assert updated.action == "updated"
      assert updated.actor == "scheduler"
      assert updated.channel == :system
      assert is_map(updated.before)
      assert is_map(updated.after)
      assert updated.before["notes"] == nil
      assert updated.after["notes"] == "changed"
      assert updated.before["tax_identifier"] == "[REDACTED]"
      assert updated.after["tax_identifier"] == "[REDACTED]"
      assert %DateTime{} = updated.occurred_at

      assert archived.action == "archived"
      assert archived.actor == "person"
      assert archived.channel == :mcp
      assert is_map(archived.before)
      assert is_map(archived.after)
      assert archived.before["archived_at"] == nil
      refute is_nil(archived.after["archived_at"])
      assert archived.before["tax_identifier"] == "[REDACTED]"
      assert archived.after["tax_identifier"] == "[REDACTED]"
      assert %DateTime{} = archived.occurred_at

      assert unarchived.action == "unarchived"
      assert unarchived.actor == "person"
      assert unarchived.channel == :web
      refute is_nil(unarchived.before["archived_at"])
      assert unarchived.after["archived_at"] == nil
      assert unarchived.before["tax_identifier"] == "[REDACTED]"
      assert unarchived.after["tax_identifier"] == "[REDACTED]"
      assert %DateTime{} = unarchived.occurred_at
    end
  end
end
