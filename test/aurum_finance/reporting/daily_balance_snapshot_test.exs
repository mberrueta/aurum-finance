defmodule AurumFinance.Reporting.DailyBalanceSnapshotTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Ledger
  alias AurumFinance.Reporting.DailyBalanceSnapshot
  alias AurumFinance.Reporting.Projections.DailyBalanceSnapshots.V1
  alias AurumFinance.Repo

  describe "changeset/2" do
    test "requires the persisted snapshot fields" do
      changeset = DailyBalanceSnapshot.changeset(%DailyBalanceSnapshot{}, %{})

      refute changeset.valid?
      assert "This field is required." in errors_on(changeset).account_id
      assert "This field is required." in errors_on(changeset).entity_id
      assert "This field is required." in errors_on(changeset).snapshot_date
      assert "This field is required." in errors_on(changeset).closing_balance
      assert "This field is required." in errors_on(changeset).daily_delta
      assert "This field is required." in errors_on(changeset).computed_at
      assert "This field is required." in errors_on(changeset).projection_version
    end

    test "enforces the unique account/date persisted row constraint" do
      account = insert(:account)

      attrs = %{
        account_id: account.id,
        entity_id: account.entity_id,
        snapshot_date: ~D[2026-03-10],
        closing_balance: Decimal.new("100.0000"),
        daily_delta: Decimal.new("5.0000"),
        computed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
        projection_version: 1
      }

      assert {:ok, _snapshot} =
               %DailyBalanceSnapshot{}
               |> DailyBalanceSnapshot.changeset(attrs)
               |> Repo.insert()

      assert {:error, changeset} =
               %DailyBalanceSnapshot{}
               |> DailyBalanceSnapshot.changeset(attrs)
               |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).account_id
    end
  end

  describe "V1.changeset/3" do
    test "derives entity_id and projection_version from the resolved account" do
      account = insert(:account)
      other_entity_id = Ecto.UUID.generate()

      changeset =
        V1.changeset(%DailyBalanceSnapshot{}, account, %{
          account_id: Ecto.UUID.generate(),
          entity_id: other_entity_id,
          snapshot_date: ~D[2026-03-10],
          closing_balance: Decimal.new("100.0000"),
          daily_delta: Decimal.new("5.0000"),
          computed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
          projection_version: 99
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :account_id) == account.id
      assert Ecto.Changeset.get_field(changeset, :entity_id) == account.entity_id
      assert Ecto.Changeset.get_field(changeset, :entity_id) != other_entity_id
      assert Ecto.Changeset.get_field(changeset, :projection_version) == 1
    end

    test "exposes the persisted projection version" do
      assert V1.projection_version() == 1
    end
  end

  describe "V1.rebuild/2" do
    test "bootstraps from the first movement date and carries balances through gap days" do
      entity = insert(:entity)
      checking = insert_account(entity)

      expense =
        insert_account(entity,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      create_transaction!(entity, ~D[2026-03-10], [
        %{account_id: checking.id, amount: Decimal.new("-10.0000")},
        %{account_id: expense.id, amount: Decimal.new("10.0000")}
      ])

      create_transaction!(entity, ~D[2026-03-12], [
        %{account_id: checking.id, amount: Decimal.new("-5.5000")},
        %{account_id: expense.id, amount: Decimal.new("5.5000")}
      ])

      assert {:ok, result} = V1.rebuild(checking)
      assert result.status == :rebuilt
      assert result.effective_from_date == ~D[2026-03-10]
      assert result.last_effective_date == ~D[2026-03-12]
      assert result.inserted_count == 3

      snapshots = snapshots_for_account(checking.id)

      assert Enum.map(snapshots, & &1.snapshot_date) == [
               ~D[2026-03-10],
               ~D[2026-03-11],
               ~D[2026-03-12]
             ]

      assert_decimal(
        snapshots |> Enum.at(0) |> Map.fetch!(:daily_delta),
        "10.0000" |> Decimal.new() |> Decimal.negate()
      )

      assert_decimal(Enum.at(snapshots, 0).closing_balance, Decimal.new("-10.0000"))
      assert_decimal(Enum.at(snapshots, 1).daily_delta, Decimal.new("0.0000"))
      assert_decimal(Enum.at(snapshots, 1).closing_balance, Decimal.new("-10.0000"))
      assert_decimal(Enum.at(snapshots, 2).daily_delta, Decimal.new("-5.5000"))
      assert_decimal(Enum.at(snapshots, 2).closing_balance, Decimal.new("-15.5000"))
    end

    test "rebuilds from the first effective date when from_date is nil or older" do
      entity = insert(:entity)

      income =
        insert_account(entity,
          account_type: :income,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      checking = insert_account(entity)

      create_transaction!(entity, ~D[2026-03-05], [
        %{account_id: checking.id, amount: Decimal.new("20.0000")},
        %{account_id: income.id, amount: Decimal.new("-20.0000")}
      ])

      assert {:ok, nil_result} = V1.rebuild(income, nil)
      assert nil_result.effective_from_date == ~D[2026-03-05]

      assert {:ok, older_result} = V1.rebuild(income, ~D[2026-03-01])
      assert older_result.effective_from_date == ~D[2026-03-05]

      [snapshot] = snapshots_for_account(income.id)
      assert snapshot.entity_id == income.entity_id
      assert_decimal(snapshot.daily_delta, Decimal.new("-20.0000"))
      assert_decimal(snapshot.closing_balance, Decimal.new("-20.0000"))
    end

    test "rebuilds liability accounts with the same base projection semantics" do
      entity = insert(:entity)

      credit_card =
        insert_account(entity,
          account_type: :liability,
          operational_subtype: :credit_card,
          management_group: :institution,
          institution_name: "Card issuer",
          institution_account_ref: "9999"
        )

      dining =
        insert_account(entity,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      create_transaction!(entity, ~D[2026-03-08], [
        %{account_id: credit_card.id, amount: Decimal.new("-12.3400")},
        %{account_id: dining.id, amount: Decimal.new("12.3400")}
      ])

      assert {:ok, result} = V1.rebuild(credit_card)
      assert result.status == :rebuilt
      assert result.effective_from_date == ~D[2026-03-08]

      [snapshot] = snapshots_for_account(credit_card.id)
      assert snapshot.entity_id == credit_card.entity_id
      assert_decimal(snapshot.daily_delta, Decimal.new("-12.3400"))
      assert_decimal(snapshot.closing_balance, Decimal.new("-12.3400"))
    end

    test "uses prior ledger balance when rebuilding from a later date and replaces the full forward range" do
      entity = insert(:entity)
      checking = insert_account(entity)

      expense =
        insert_account(entity,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      create_transaction!(entity, ~D[2026-03-10], [
        %{account_id: checking.id, amount: Decimal.new("-10.0000")},
        %{account_id: expense.id, amount: Decimal.new("10.0000")}
      ])

      create_transaction!(entity, ~D[2026-03-12], [
        %{account_id: checking.id, amount: Decimal.new("-5.0000")},
        %{account_id: expense.id, amount: Decimal.new("5.0000")}
      ])

      assert {:ok, _result} = V1.rebuild(checking)

      stale_snapshot =
        Repo.get_by!(DailyBalanceSnapshot, account_id: checking.id, snapshot_date: ~D[2026-03-12])

      stale_snapshot
      |> DailyBalanceSnapshot.changeset(%{
        closing_balance: Decimal.new("-999.0000"),
        daily_delta: Decimal.new("-999.0000"),
        computed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })
      |> Repo.update!()

      create_transaction!(entity, ~D[2026-03-13], [
        %{account_id: checking.id, amount: Decimal.new("-1.2500")},
        %{account_id: expense.id, amount: Decimal.new("1.2500")}
      ])

      assert {:ok, result} = V1.rebuild(checking, ~D[2026-03-12])
      assert result.status == :rebuilt
      assert result.effective_from_date == ~D[2026-03-12]

      snapshots = snapshots_for_account(checking.id)

      assert Enum.map(snapshots, & &1.snapshot_date) == [
               ~D[2026-03-10],
               ~D[2026-03-11],
               ~D[2026-03-12],
               ~D[2026-03-13]
             ]

      assert_decimal(Enum.at(snapshots, 2).closing_balance, Decimal.new("-15.0000"))
      assert_decimal(Enum.at(snapshots, 2).daily_delta, Decimal.new("-5.0000"))
      assert_decimal(Enum.at(snapshots, 3).closing_balance, Decimal.new("-16.2500"))
      assert_decimal(Enum.at(snapshots, 3).daily_delta, Decimal.new("-1.2500"))
    end

    test "returns a no-op when from_date is after the last effective date" do
      entity = insert(:entity)
      checking = insert_account(entity)

      expense =
        insert_account(entity,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      create_transaction!(entity, ~D[2026-03-10], [
        %{account_id: checking.id, amount: Decimal.new("-10.0000")},
        %{account_id: expense.id, amount: Decimal.new("10.0000")}
      ])

      assert {:ok, _result} = V1.rebuild(checking)

      computed_at_before_noop =
        snapshots_for_account(checking.id) |> List.first() |> Map.fetch!(:computed_at)

      assert {:ok, result} = V1.rebuild(checking, ~D[2026-03-11])
      assert result.status == :noop
      assert result.inserted_count == 0
      assert result.deleted_count == 0

      [snapshot] = snapshots_for_account(checking.id)
      assert snapshot.computed_at == computed_at_before_noop
    end

    test "matches ledger void semantics by summing persisted postings only" do
      entity = insert(:entity)
      checking = insert_account(entity)

      expense =
        insert_account(entity,
          account_type: :expense,
          management_group: :category,
          operational_subtype: nil,
          institution_name: nil,
          institution_account_ref: nil
        )

      transaction =
        create_transaction!(entity, ~D[2026-03-10], [
          %{account_id: checking.id, amount: Decimal.new("-10.0000")},
          %{account_id: expense.id, amount: Decimal.new("10.0000")}
        ])

      assert {:ok, %{reversal: reversal}} = Ledger.void_transaction(transaction)
      assert reversal.date == ~D[2026-03-10]

      assert {:ok, result} = V1.rebuild(checking)
      assert result.inserted_count == 1

      [snapshot] = snapshots_for_account(checking.id)
      assert_decimal(snapshot.daily_delta, Decimal.new("0.0000"))
      assert_decimal(snapshot.closing_balance, Decimal.new("0.0000"))
    end

    test "deletes stale snapshots when an account no longer has effective transactions" do
      account = insert(:account)

      %DailyBalanceSnapshot{}
      |> DailyBalanceSnapshot.changeset(%{
        account_id: account.id,
        entity_id: account.entity_id,
        snapshot_date: ~D[2026-03-10],
        closing_balance: Decimal.new("1.0000"),
        daily_delta: Decimal.new("1.0000"),
        computed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
        projection_version: 1
      })
      |> Repo.insert!()

      assert {:ok, result} = V1.rebuild(account)
      assert result.status == :deleted_stale
      assert result.deleted_count == 1
      assert snapshots_for_account(account.id) == []
    end
  end

  defp snapshots_for_account(account_id) do
    DailyBalanceSnapshot
    |> Ecto.Query.where([snapshot], snapshot.account_id == ^account_id)
    |> Ecto.Query.order_by([snapshot], asc: snapshot.snapshot_date)
    |> Repo.all()
  end

  defp create_transaction!(entity, date, postings) do
    {:ok, transaction} =
      Ledger.create_transaction(%{
        entity_id: entity.id,
        date: date,
        description: "Reporting test transaction",
        source_type: :manual,
        postings: postings
      })

    transaction
  end

  defp assert_decimal(%Decimal{} = left, %Decimal{} = right) do
    assert Decimal.eq?(left, right)
  end
end
