defmodule AurumFinance.AuditTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit

  describe "list_audit_events/1" do
    test "filters by inclusive occurred_at range" do
      base_time = ~U[2026-03-01 12:00:00Z]

      older = audit_event_fixture(%{occurred_at: DateTime.add(base_time, -1, :second)})
      at_start = audit_event_fixture(%{occurred_at: base_time})
      in_range = audit_event_fixture(%{occurred_at: DateTime.add(base_time, 60, :second)})
      at_end = audit_event_fixture(%{occurred_at: DateTime.add(base_time, 120, :second)})
      newer = audit_event_fixture(%{occurred_at: DateTime.add(base_time, 121, :second)})

      events =
        Audit.list_audit_events(
          occurred_after: base_time,
          occurred_before: DateTime.add(base_time, 120, :second)
        )

      assert Enum.map(events, & &1.id) == [at_end.id, in_range.id, at_start.id]
      refute older.id in Enum.map(events, & &1.id)
      refute newer.id in Enum.map(events, & &1.id)
    end

    test "applies offset together with limit for pagination" do
      base_time = ~U[2026-03-02 09:00:00Z]

      ids =
        for offset <- 0..4 do
          audit_event_fixture(%{occurred_at: DateTime.add(base_time, offset, :second)}).id
        end

      page =
        Audit.list_audit_events(limit: 2, offset: 1)
        |> Enum.map(& &1.id)

      assert page == Enum.slice(Enum.reverse(ids), 1, 2)
    end

    test "silently ignores unknown filters" do
      event = audit_event_fixture()

      events = Audit.list_audit_events(not_a_real_filter: "ignored")

      assert Enum.map(events, & &1.id) == [event.id]
    end
  end

  describe "distinct_entity_types/0" do
    test "returns sorted unique entity types" do
      audit_event_fixture(%{entity_type: "transaction"})
      audit_event_fixture(%{entity_type: "entity"})
      audit_event_fixture(%{entity_type: "account"})
      audit_event_fixture(%{entity_type: "transaction"})

      assert Audit.distinct_entity_types() == ["account", "entity", "transaction"]
    end

    test "returns an empty list when no audit events exist" do
      assert Audit.distinct_entity_types() == []
    end
  end

  defp audit_event_fixture(attrs \\ %{}) do
    defaults = %{
      entity_type: "entity",
      entity_id: Ecto.UUID.generate(),
      action: "updated",
      actor: "person",
      channel: :web,
      before: %{"name" => "before"},
      after: %{"name" => "after"},
      occurred_at: DateTime.utc_now()
    }

    {:ok, event} =
      defaults
      |> Map.merge(attrs)
      |> Audit.create_audit_event()

    event
  end
end
