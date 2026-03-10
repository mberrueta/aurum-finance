defmodule AurumFinance.AuditTest do
  use AurumFinance.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias AurumFinance.Audit
  alias AurumFinance.Audit.AuditEvent
  alias AurumFinance.Audit.Multi, as: AuditMulti
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Repo

  describe "helper API" do
    test "S06: insert_and_log/2 creates the record and a redacted audit event" do
      name = unique_name("Insert and log")

      changeset =
        Entity.changeset(%Entity{}, %{
          name: name,
          type: :individual,
          country_code: "US",
          tax_identifier: "123-45-6789"
        })

      assert {:ok, entity} =
               Audit.insert_and_log(changeset, %{
                 actor: "root",
                 channel: :web,
                 entity_type: "entity",
                 redact_fields: [:tax_identifier],
                 metadata: %{request_id: "req-1"}
               })

      event = fetch_event(entity.id, "created")

      assert event.action == "created"
      assert event.actor == "root"
      assert event.channel == :web
      assert event.before == nil
      assert event.after["name"] == name
      assert event.after["tax_identifier"] == "[REDACTED]"
      assert event.metadata == %{"request_id" => "req-1"}
      assert Repo.get(Entity, entity.id)
    end

    test "S07: insert_and_log/2 returns the domain changeset error and writes nothing on domain failure" do
      changeset = Entity.changeset(%Entity{}, %{country_code: "US"})
      before_entity_count = Repo.aggregate(Entity, :count, :id)
      before_event_count = Repo.aggregate(AuditEvent, :count, :id)

      assert {:error, changeset} = Audit.insert_and_log(changeset, valid_entity_meta())
      refute changeset.valid?
      assert Repo.aggregate(Entity, :count, :id) == before_entity_count
      assert Repo.aggregate(AuditEvent, :count, :id) == before_event_count
    end

    test "S08: insert_and_log/2 rolls back the domain write when audit insertion fails" do
      name = unique_name("Audit rollback insert")

      changeset =
        Entity.changeset(%Entity{}, %{
          name: name,
          type: :individual,
          country_code: "US"
        })

      assert {:error, {:audit_failed, %Ecto.Changeset{} = changeset}} =
               Audit.insert_and_log(changeset, %{valid_entity_meta() | entity_type: nil})

      refute changeset.valid?
      assert Repo.get_by(Entity, name: name) == nil
      assert Audit.list_audit_events(entity_type: "entity", action: "created") == []
    end

    test "S09: update_and_log/3 records before and after snapshots with redaction" do
      entity =
        insert_entity(%{name: unique_name("Update before after"), tax_identifier: "OLD-TAX-ID"})

      changeset =
        Entity.changeset(entity, %{
          notes: "changed",
          tax_identifier: "NEW-TAX-ID"
        })

      assert {:ok, updated} =
               Audit.update_and_log(entity, changeset, %{
                 actor: "scheduler",
                 channel: :system,
                 entity_type: "entity",
                 action: "updated",
                 redact_fields: [:tax_identifier]
               })

      event = fetch_event(entity.id, "updated")

      assert updated.notes == "changed"
      assert event.action == "updated"
      assert event.actor == "scheduler"
      assert event.channel == :system
      assert event.before["notes"] == entity.notes
      assert event.after["notes"] == "changed"
      assert event.before["tax_identifier"] == "[REDACTED]"
      assert event.after["tax_identifier"] == "[REDACTED]"
    end

    test "S10: update_and_log/3 returns the domain changeset error when the update is invalid" do
      entity = insert_entity(%{name: unique_name("Invalid update")})
      changeset = Entity.changeset(entity, %{name: nil})
      before_event_count = length(Audit.list_audit_events(entity_id: entity.id))

      assert {:error, changeset} = Audit.update_and_log(entity, changeset, valid_entity_meta())
      refute changeset.valid?
      assert length(Audit.list_audit_events(entity_id: entity.id)) == before_event_count
      assert Repo.get(Entity, entity.id).name == entity.name
    end

    test "S11: update_and_log/3 rolls back the persisted update when audit insertion fails" do
      entity = insert_entity(%{name: unique_name("Update rollback")})
      changeset = Entity.changeset(entity, %{notes: "should rollback"})
      before_event_count = length(Audit.list_audit_events(entity_id: entity.id))

      assert {:error, {:audit_failed, %Ecto.Changeset{} = changeset}} =
               Audit.update_and_log(entity, changeset, %{valid_entity_meta() | entity_type: nil})

      refute changeset.valid?
      assert Repo.get(Entity, entity.id).notes == entity.notes
      assert length(Audit.list_audit_events(entity_id: entity.id)) == before_event_count
    end

    test "S12: archive_and_log/3 records an archived action and archived_at in the after snapshot" do
      entity = insert_entity(%{name: unique_name("Archive helper")})

      changeset = Entity.changeset(entity, %{archived_at: ~U[2026-03-05 12:00:00Z]})

      assert {:ok, archived} =
               Audit.archive_and_log(entity, changeset, %{
                 actor: "root",
                 channel: :mcp,
                 entity_type: "entity",
                 redact_fields: [:tax_identifier]
               })

      event = fetch_event(entity.id, "archived")

      assert event.action == "archived"
      assert event.channel == :mcp
      assert event.before["archived_at"] == nil
      assert event.after["archived_at"] == DateTime.to_iso8601(archived.archived_at)
    end
  end

  describe "Audit.Multi.append_event/4" do
    test "S13: appends an audit event to a successful Multi transaction" do
      name = unique_name("Multi success")

      changeset =
        Entity.changeset(%Entity{}, %{
          name: name,
          type: :individual,
          country_code: "US",
          tax_identifier: "TOP-SECRET"
        })

      assert {:ok, %{entity: entity}} =
               Ecto.Multi.new()
               |> Ecto.Multi.insert(:entity, changeset)
               |> AuditMulti.append_event(:entity, nil, %{
                 actor: "root",
                 channel: :web,
                 entity_type: "entity",
                 action: "created",
                 redact_fields: [:tax_identifier],
                 metadata: %{request_id: "multi-1"},
                 serializer: &entity_snapshot/1
               })
               |> Repo.transaction()

      event = fetch_event(entity.id, "created")

      assert event.after["name"] == name
      assert event.after["tax_identifier"] == "[REDACTED]"
      assert event.metadata == %{"request_id" => "multi-1"}
    end

    test "S14: does not create an audit event when a prior Multi step fails" do
      changeset = Entity.changeset(%Entity{}, %{country_code: "US"})
      before_entity_count = Repo.aggregate(Entity, :count, :id)
      before_event_count = Repo.aggregate(AuditEvent, :count, :id)

      assert {:error, :entity, %Ecto.Changeset{} = changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.insert(:entity, changeset)
               |> AuditMulti.append_event(:entity, nil, %{
                 actor: "root",
                 channel: :web,
                 entity_type: "entity",
                 action: "created"
               })
               |> Repo.transaction()

      refute changeset.valid?
      assert Repo.aggregate(AuditEvent, :count, :id) == before_event_count
      assert Repo.aggregate(Entity, :count, :id) == before_entity_count
    end

    test "S15: rolls back a successful Multi write when the audit append is invalid" do
      name = unique_name("Multi rollback")

      changeset =
        Entity.changeset(%Entity{}, %{
          name: name,
          type: :individual,
          country_code: "US"
        })

      assert {:error, {:audit, :entity}, %Ecto.Changeset{} = changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.insert(:entity, changeset)
               |> AuditMulti.append_event(:entity, nil, %{
                 actor: "root",
                 channel: :web,
                 entity_type: nil,
                 action: "created"
               })
               |> Repo.transaction()

      refute changeset.valid?
      assert Repo.get_by(Entity, name: name) == nil
      assert Audit.list_audit_events(entity_type: "entity", action: "created") == []
    end
  end

  describe "raw SQL immutability enforcement" do
    test "S16: audit_events is append-only while INSERT still works" do
      event = audit_event_fixture()
      dumped_id = Ecto.UUID.dump!(event.id)

      assert_raise Postgrex.Error, ~r/append-only/, fn ->
        SQL.query!(Repo, "UPDATE audit_events SET action = 'tampered' WHERE id = $1", [dumped_id])
      end

      assert_raise Postgrex.Error, ~r/append-only/, fn ->
        SQL.query!(Repo, "DELETE FROM audit_events WHERE id = $1", [dumped_id])
      end

      inserted =
        audit_event_fixture(%{
          entity_type: "entity",
          entity_id: Ecto.UUID.generate(),
          action: "created",
          actor: "root",
          channel: :web,
          occurred_at: ~U[2026-03-01 00:00:00Z]
        })

      assert Repo.get(AuditEvent, inserted.id)
    end

    test "S17: postings is append-only while normal posting inserts still work" do
      transaction = create_balanced_transaction()
      posting = List.first(transaction.postings)
      dumped_id = Ecto.UUID.dump!(posting.id)

      assert_raise Postgrex.Error, ~r/append-only/, fn ->
        SQL.query!(Repo, "UPDATE postings SET amount = $2 WHERE id = $1", [
          dumped_id,
          Decimal.new("99.99")
        ])
      end

      assert_raise Postgrex.Error, ~r/append-only/, fn ->
        SQL.query!(Repo, "DELETE FROM postings WHERE id = $1", [dumped_id])
      end

      assert Repo.aggregate(Posting, :count, :id) == 2
    end

    test "S18: transactions blocks DELETE and immutable fact updates" do
      transaction = create_balanced_transaction()
      dumped_id = Ecto.UUID.dump!(transaction.id)

      assert_raise Postgrex.Error, ~r/protected ledger facts/, fn ->
        SQL.query!(Repo, "DELETE FROM transactions WHERE id = $1", [dumped_id])
      end

      assert_raise Postgrex.Error, ~r/immutable/, fn ->
        SQL.query!(Repo, "UPDATE transactions SET description = 'tampered' WHERE id = $1", [
          dumped_id
        ])
      end

      assert_raise Postgrex.Error, ~r/immutable/, fn ->
        SQL.query!(Repo, "UPDATE transactions SET entity_id = $2 WHERE id = $1", [
          dumped_id,
          Ecto.UUID.dump!(Ecto.UUID.generate())
        ])
      end

      assert_raise Postgrex.Error, ~r/immutable/, fn ->
        SQL.query!(Repo, "UPDATE transactions SET date = $2::date WHERE id = $1", [
          dumped_id,
          ~D[2026-03-15]
        ])
      end

      assert_raise Postgrex.Error, ~r/immutable/, fn ->
        SQL.query!(Repo, "UPDATE transactions SET source_type = 'import' WHERE id = $1", [
          dumped_id
        ])
      end

      assert Repo.get(Transaction, transaction.id)
    end

    test "S19: transactions allows lifecycle updates for voided_at and correlation_id only" do
      transaction = create_balanced_transaction()
      dumped_id = Ecto.UUID.dump!(transaction.id)
      first_voided_at = ~U[2026-03-03 10:00:00Z]
      second_voided_at = ~U[2026-03-03 11:00:00Z]

      assert {:ok, _result} =
               SQL.query(
                 Repo,
                 "UPDATE transactions SET voided_at = $2::timestamptz WHERE id = $1",
                 [dumped_id, first_voided_at]
               )

      assert Repo.get(Transaction, transaction.id).voided_at

      assert_raise Postgrex.Error, ~r/set-once/, fn ->
        SQL.query!(
          Repo,
          "UPDATE transactions SET voided_at = $2::timestamptz WHERE id = $1",
          [dumped_id, second_voided_at]
        )
      end

      transaction = create_balanced_transaction()
      dumped_id = Ecto.UUID.dump!(transaction.id)
      correlation_id = Ecto.UUID.generate()

      assert {:ok, _result} =
               SQL.query(
                 Repo,
                 "UPDATE transactions SET correlation_id = $2 WHERE id = $1",
                 [dumped_id, Ecto.UUID.dump!(correlation_id)]
               )

      assert Repo.get(Transaction, transaction.id).correlation_id == correlation_id
    end
  end

  describe "caller migration coverage" do
    test "S20: legacy audit entry points are gone" do
      refute function_exported?(Audit, :with_event, 3)
      refute function_exported?(Audit, :log_event, 1)
    end

    test "S21: ledger transaction callers skip create events and keep void audit events with actor/channel" do
      %{entity: entity, checking: checking, expense: expense} = transaction_accounts_fixture()

      assert {:ok, transaction} =
               Ledger.create_transaction(
                 %{
                   entity_id: entity.id,
                   date: ~D[2026-03-08],
                   description: "Caller coverage",
                   source_type: :manual,
                   postings: [
                     %{account_id: checking.id, amount: Decimal.new("-10.00")},
                     %{account_id: expense.id, amount: Decimal.new("10.00")}
                   ]
                 },
                 actor: "person",
                 channel: :mcp
               )

      assert Audit.list_audit_events(entity_id: transaction.id) == []

      assert {:ok, %{voided: voided, reversal: reversal}} =
               Ledger.void_transaction(transaction, actor: "scheduler", channel: :system)

      [voided_event] = Audit.list_audit_events(entity_id: voided.id)

      assert voided_event.actor == "scheduler"
      assert voided_event.channel == :system
      assert voided_event.before["voided_at"] == nil
      assert voided_event.after["voided_at"]
      assert Audit.list_audit_events(entity_id: reversal.id) == []
    end
  end

  describe "query extensions" do
    test "S22: list_audit_events/1 filters by inclusive occurred_at range" do
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

      ids = Enum.map(events, & &1.id)

      assert ids == [at_end.id, in_range.id, at_start.id]
      refute older.id in ids
      refute newer.id in ids
    end

    test "S23: list_audit_events/1 applies offset together with limit for pagination" do
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

    test "S24: list_audit_events/1 silently ignores unknown filters" do
      event = audit_event_fixture()

      events = Audit.list_audit_events(not_a_real_filter: "ignored")

      assert Enum.map(events, & &1.id) == [event.id]
    end

    test "S25: distinct_entity_types/0 returns sorted unique values and [] when empty" do
      assert Audit.distinct_entity_types() == []

      audit_event_fixture(%{entity_type: "transaction"})
      audit_event_fixture(%{entity_type: "entity"})
      audit_event_fixture(%{entity_type: "account"})
      audit_event_fixture(%{entity_type: "transaction"})

      assert Audit.distinct_entity_types() == ["account", "entity", "transaction"]
    end
  end

  defp valid_entity_meta do
    %{
      actor: "root",
      channel: :web,
      entity_type: "entity",
      redact_fields: [:tax_identifier],
      serializer: &entity_snapshot/1
    }
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

  defp fetch_event(entity_id, action) do
    Audit.list_audit_events(entity_id: entity_id)
    |> Enum.find(&(&1.action == action))
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

    attrs = Map.merge(defaults, attrs)

    {:ok, event} =
      %AuditEvent{}
      |> AuditEvent.changeset(attrs)
      |> Repo.insert()

    event
  end

  defp transaction_accounts_fixture do
    entity = insert_entity(%{name: unique_name("Audit transaction entity")})
    checking = insert_account(entity, %{name: unique_name("Checking")})

    expense =
      insert_account(entity, %{
        name: unique_name("Expense"),
        account_type: :expense,
        operational_subtype: nil,
        management_group: :category
      })

    %{entity: entity, checking: checking, expense: expense}
  end

  defp create_balanced_transaction do
    %{entity: entity, checking: checking, expense: expense} = transaction_accounts_fixture()

    {:ok, transaction} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: ~D[2026-03-02],
        description: unique_name("Protected tx"),
        source_type: :manual,
        postings: [
          %{account_id: checking.id, amount: Decimal.new("-10.00")},
          %{account_id: expense.id, amount: Decimal.new("10.00")}
        ]
      })

    transaction
  end

  defp unique_name(prefix) do
    "#{prefix} #{System.unique_integer([:positive])}"
  end
end
