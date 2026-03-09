defmodule AurumFinance.LedgerTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Transaction

  describe "change_account/2" do
    test "requires canonical fields" do
      changeset = Ledger.change_account(%Account{}, %{})

      refute changeset.valid?
      assert "error_field_required" in errors_on(changeset).entity_id
      assert "error_field_required" in errors_on(changeset).name
      assert "error_field_required" in errors_on(changeset).account_type
      assert "error_field_required" in errors_on(changeset).management_group
      assert "error_field_required" in errors_on(changeset).currency_code
    end

    test "requires operational_subtype for asset/liability accounts" do
      changeset =
        Ledger.change_account(%Account{}, %{
          entity_id: Ecto.UUID.generate(),
          name: "Checking",
          account_type: :asset,
          management_group: :institution,
          currency_code: "USD"
        })

      refute changeset.valid?

      assert "Operational subtype is required for asset and liability accounts." in errors_on(
               changeset
             ).operational_subtype
    end

    test "rejects operational_subtype for income accounts" do
      changeset =
        Ledger.change_account(%Account{}, %{
          entity_id: Ecto.UUID.generate(),
          name: "Salary",
          account_type: :income,
          operational_subtype: :bank_checking,
          management_group: :category,
          currency_code: "USD"
        })

      refute changeset.valid?

      assert "Operational subtype is not allowed for this account type." in errors_on(changeset).operational_subtype
    end

    test "rejects invalid subtype for the selected account type" do
      changeset =
        Ledger.change_account(%Account{}, %{
          entity_id: Ecto.UUID.generate(),
          name: "Bad liability",
          account_type: :liability,
          operational_subtype: :bank_checking,
          management_group: :institution,
          currency_code: "USD"
        })

      refute changeset.valid?

      assert "Operational subtype is invalid for the selected account type." in errors_on(
               changeset
             ).operational_subtype
    end

    test "requires management_group to match canonical account shape" do
      changeset =
        Ledger.change_account(%Account{}, %{
          entity_id: Ecto.UUID.generate(),
          name: "Opening balances",
          account_type: :equity,
          management_group: :institution,
          currency_code: "USD"
        })

      refute changeset.valid?

      assert "Management group is inconsistent with account type and operational subtype." in errors_on(
               changeset
             ).management_group
    end

    test "classifies accounts into management groups with helpers" do
      institution = %Account{
        account_type: :asset,
        operational_subtype: :cash,
        management_group: :institution
      }

      category = %Account{
        account_type: :expense,
        operational_subtype: nil,
        management_group: :category
      }

      system_managed = %Account{
        account_type: :equity,
        operational_subtype: nil,
        management_group: :system_managed
      }

      unknown = %Account{
        account_type: :asset,
        operational_subtype: nil,
        management_group: :institution
      }

      assert Account.institution_account?(institution)
      refute Account.institution_account?(category)

      assert Account.category_account?(category)
      refute Account.category_account?(institution)

      assert Account.system_managed_account?(system_managed)
      refute Account.system_managed_account?(institution)

      assert Account.management_group(institution) == :institution
      assert Account.management_group(category) == :category
      assert Account.management_group(system_managed) == :system_managed
      assert Account.management_group(unknown) == :unknown
    end

    test "maps operational subtypes to canonical account types" do
      assert Account.account_type_for_operational_subtype(:bank_checking) == :asset
      assert Account.account_type_for_operational_subtype(:brokerage_securities) == :asset
      assert Account.account_type_for_operational_subtype(:credit_card) == :liability
      assert Account.account_type_for_operational_subtype(:loan) == :liability
      assert Account.account_type_for_operational_subtype(nil) == nil
    end
  end

  describe "account lifecycle" do
    test "list_accounts/1 requires entity scope" do
      assert_raise ArgumentError, "list_accounts/1 requires :entity_id", fn ->
        Ledger.list_accounts()
      end
    end

    test "list_accounts/1 is entity-scoped and excludes archived accounts by default" do
      entity_a = entity_fixture(%{name: "Entity A"})
      entity_b = entity_fixture(%{name: "Entity B"})

      account_a = account_fixture(entity_a, %{name: "Primary checking"})
      _account_b = account_fixture(entity_b, %{name: "Foreign checking"})

      assert {:ok, archived} = Ledger.archive_account(account_a)
      assert %DateTime{} = archived.archived_at

      assert [] == Ledger.list_accounts(entity_id: entity_a.id)

      assert [visible] =
               Ledger.list_accounts(entity_id: entity_b.id, include_archived: true)

      assert visible.entity_id == entity_b.id

      listed_with_archived =
        Ledger.list_accounts(entity_id: entity_a.id, include_archived: true)
        |> Enum.map(& &1.id)

      assert archived.id in listed_with_archived
      refute entity_b.id == archived.entity_id
    end

    test "lists accounts by management group using query-level filters" do
      entity = entity_fixture(%{name: "Grouped entity"})

      institution =
        account_fixture(entity, %{name: "Checking", operational_subtype: :bank_checking})

      category =
        account_fixture(entity, %{
          name: "Groceries",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      system_managed =
        account_fixture(entity, %{
          name: "Opening balances",
          account_type: :equity,
          operational_subtype: nil,
          management_group: :system_managed
        })

      assert [listed_institution] = Ledger.list_institution_accounts(entity_id: entity.id)
      assert listed_institution.id == institution.id

      assert [listed_category] = Ledger.list_category_accounts(entity_id: entity.id)
      assert listed_category.id == category.id

      assert [listed_system] = Ledger.list_system_managed_accounts(entity_id: entity.id)
      assert listed_system.id == system_managed.id

      assert [by_group] =
               Ledger.list_accounts_by_management_group(:category, entity_id: entity.id)

      assert by_group.id == category.id

      assert [same_by_filter] =
               Ledger.list_accounts(entity_id: entity.id, management_group: :category)

      assert same_by_filter.id == category.id
    end

    test "management group listing respects archived filter" do
      entity = entity_fixture(%{name: "Archived grouped entity"})

      account =
        account_fixture(entity, %{
          name: "Archived card",
          account_type: :liability,
          operational_subtype: :credit_card
        })

      assert {:ok, archived} = Ledger.archive_account(account)

      assert [] == Ledger.list_institution_accounts(entity_id: entity.id)

      assert [visible] =
               Ledger.list_institution_accounts(entity_id: entity.id, include_archived: true)

      assert visible.id == archived.id
    end

    test "list_accounts_by_management_group/2 rejects unsupported values" do
      assert_raise ArgumentError, "unsupported management group: :unknown", fn ->
        Ledger.list_accounts_by_management_group(:unknown, entity_id: Ecto.UUID.generate())
      end
    end

    test "get_account!/2 enforces the ownership boundary" do
      entity_a = entity_fixture(%{name: "Scoped entity A"})
      entity_b = entity_fixture(%{name: "Scoped entity B"})
      account = account_fixture(entity_a, %{name: "Scoped checking"})

      assert Ledger.get_account!(entity_a.id, account.id).id == account.id

      assert_raise Ecto.NoResultsError, fn ->
        Ledger.get_account!(entity_b.id, account.id)
      end
    end

    test "update_account/3 rejects immutable field changes" do
      entity = entity_fixture(%{name: "Immutability entity"})
      account = account_fixture(entity)

      assert {:error, changeset} =
               Ledger.update_account(account, %{
                 currency_code: "EUR",
                 account_type: :liability,
                 operational_subtype: :credit_card,
                 management_group: :category
               })

      assert "This field cannot be changed after the account is created." in errors_on(changeset).currency_code

      assert "This field cannot be changed after the account is created." in errors_on(changeset).account_type

      assert "This field cannot be changed after the account is created." in errors_on(changeset).operational_subtype

      assert "This field cannot be changed after the account is created." in errors_on(changeset).management_group
    end

    test "normal_balance/1 maps canonical account types" do
      assert :debit == Account.normal_balance(:asset)
      assert :debit == Account.normal_balance(:expense)
      assert :credit == Account.normal_balance(:liability)
      assert :credit == Account.normal_balance(:equity)
      assert :credit == Account.normal_balance(:income)
    end

    test "get_account_balance/2 returns an empty map for accounts with no postings" do
      assert %{} == Ledger.get_account_balance(Ecto.UUID.generate())
      assert %{} == Ledger.get_account_balance(Ecto.UUID.generate(), as_of_date: ~D[2026-03-07])
    end
  end

  describe "create_transaction/2" do
    test "creates a balanced transaction with preloaded postings and no default audit event" do
      %{entity: entity, checking: checking, groceries: groceries} = transaction_accounts_fixture()

      assert {:ok, transaction} =
               Ledger.create_transaction(
                 %{
                   entity_id: entity.id,
                   date: ~D[2026-03-01],
                   description: "Lunch",
                   source_type: :manual,
                   postings: [
                     %{account_id: checking.id, amount: Decimal.new("-12.50")},
                     %{account_id: groceries.id, amount: Decimal.new("12.50")}
                   ]
                 },
                 actor: "person",
                 channel: :web
               )

      assert %Transaction{} = transaction
      assert is_nil(transaction.voided_at)
      assert Enum.count(transaction.postings) == 2
      refute Enum.any?(transaction.postings, &Ecto.assoc_loaded?(&1.account))

      assert Audit.list_audit_events(entity_id: transaction.id) == []
      assert Audit.list_audit_events(entity_type: "posting") == []
    end

    test "creates a split transaction with three postings" do
      %{entity: entity, checking: checking, groceries: groceries} = transaction_accounts_fixture()

      household =
        account_fixture(entity, %{
          name: "Household",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      assert {:ok, transaction} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Superstore",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-30.00")},
                   %{account_id: groceries.id, amount: Decimal.new("12.50")},
                   %{account_id: household.id, amount: Decimal.new("17.50")}
                 ]
               })

      assert Enum.count(transaction.postings) == 3
    end

    test "creates a multi-currency transaction when each currency group balances" do
      entity = entity_fixture(%{name: "FX Entity"})
      usd_checking = account_fixture(entity, %{name: "USD Checking", currency_code: "USD"})

      usd_trading =
        account_fixture(entity, %{
          name: "USD Trading",
          account_type: :equity,
          operational_subtype: nil,
          management_group: :system_managed,
          currency_code: "USD"
        })

      eur_trading =
        account_fixture(entity, %{
          name: "EUR Trading",
          account_type: :equity,
          operational_subtype: nil,
          management_group: :system_managed,
          currency_code: "EUR"
        })

      eur_savings =
        account_fixture(entity, %{
          name: "EUR Savings",
          operational_subtype: :bank_savings,
          currency_code: "EUR"
        })

      assert {:ok, transaction} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-03],
                 description: "FX rebalance",
                 source_type: :system,
                 postings: [
                   %{account_id: usd_checking.id, amount: Decimal.new("-100.00")},
                   %{account_id: usd_trading.id, amount: Decimal.new("100.00")},
                   %{account_id: eur_trading.id, amount: Decimal.new("-92.00")},
                   %{account_id: eur_savings.id, amount: Decimal.new("92.00")}
                 ]
               })

      assert Enum.count(transaction.postings) == 4
      assert Ledger.get_account_balance(usd_checking.id) == %{"USD" => Decimal.new("-100.00")}
      assert Ledger.get_account_balance(eur_savings.id) == %{"EUR" => Decimal.new("92.00")}
    end

    test "rejects unbalanced postings" do
      %{entity: entity, checking: checking, groceries: groceries} = transaction_accounts_fixture()

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Broken lunch",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-12.50")},
                   %{account_id: groceries.id, amount: Decimal.new("10.00")}
                 ]
               })

      assert "Transaction postings must balance to zero within each currency." in errors_on(
               changeset
             ).postings
    end

    test "rejects fewer than two postings" do
      %{entity: entity, checking: checking} = transaction_accounts_fixture()

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Too small",
                 source_type: :manual,
                 postings: [%{account_id: checking.id, amount: Decimal.new("10.00")}]
               })

      assert "A transaction must contain at least two postings." in errors_on(changeset).postings
    end

    test "rejects empty postings list" do
      entity = entity_fixture()

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Empty",
                 source_type: :manual,
                 postings: []
               })

      assert "A transaction must contain at least two postings." in errors_on(changeset).postings
    end

    test "rejects posting accounts from another entity" do
      %{entity: entity, checking: checking} = transaction_accounts_fixture()
      other_entity = entity_fixture(%{name: "Foreign Entity"})

      foreign_expense =
        account_fixture(other_entity, %{
          name: "Foreign expense",
          account_type: :expense,
          operational_subtype: nil,
          management_group: :category
        })

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Cross entity",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-12.50")},
                   %{account_id: foreign_expense.id, amount: Decimal.new("12.50")}
                 ]
               })

      assert "All posting accounts must belong to the same entity as the transaction." in errors_on(
               changeset
             ).postings
    end

    test "rejects unknown account ids and leaves no partial writes" do
      %{entity: entity, checking: checking} = transaction_accounts_fixture()

      assert {:error, changeset} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Unknown account",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-12.50")},
                   %{account_id: Ecto.UUID.generate(), amount: Decimal.new("12.50")}
                 ]
               })

      assert "All postings must reference existing accounts." in errors_on(changeset).postings
      assert [] == Ledger.list_transactions(entity_id: entity.id, include_voided: true)
    end

    test "allows zero-amount postings when the transaction still balances" do
      %{entity: entity, checking: checking, groceries: groceries} = transaction_accounts_fixture()

      assert {:ok, transaction} =
               Ledger.create_transaction(%{
                 entity_id: entity.id,
                 date: ~D[2026-03-02],
                 description: "Memo split",
                 source_type: :manual,
                 postings: [
                   %{account_id: checking.id, amount: Decimal.new("-10.00")},
                   %{account_id: groceries.id, amount: Decimal.new("10.00")},
                   %{account_id: groceries.id, amount: Decimal.new("0.00")}
                 ]
               })

      assert Enum.any?(transaction.postings, &Decimal.eq?(&1.amount, Decimal.new("0.00")))
    end
  end

  describe "get_transaction!/2" do
    test "returns the transaction with postings preloaded" do
      %{entity: entity} = transaction_accounts_fixture()
      transaction = create_balanced_transaction(entity, %{description: "Visible Tx"})

      fetched = Ledger.get_transaction!(entity.id, transaction.id)

      assert fetched.id == transaction.id
      assert Enum.count(fetched.postings) == 2
      assert Enum.all?(fetched.postings, &match?(%Account{}, &1.account))
    end

    test "raises when the entity scope is wrong" do
      %{entity: entity} = transaction_accounts_fixture()
      other_entity = entity_fixture()
      transaction = create_balanced_transaction(entity, %{description: "Scoped"})

      assert_raise Ecto.NoResultsError, fn ->
        Ledger.get_transaction!(other_entity.id, transaction.id)
      end
    end

    test "raises when the transaction does not exist" do
      entity = entity_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Ledger.get_transaction!(entity.id, Ecto.UUID.generate())
      end
    end
  end

  describe "list_transactions/1" do
    test "requires entity_id" do
      assert_raise ArgumentError, "list_transactions/1 requires :entity_id", fn ->
        Ledger.list_transactions()
      end
    end

    test "is entity scoped and excludes voided rows by default" do
      entity = entity_fixture(%{name: "Listing Entity"})
      other_entity = entity_fixture(%{name: "Other Listing Entity"})
      transaction = create_balanced_transaction(entity, %{description: "Visible Tx"})
      _other = create_balanced_transaction(other_entity, %{description: "Hidden Tx"})

      assert [listed] = Ledger.list_transactions(entity_id: entity.id)
      assert listed.id == transaction.id

      assert {:ok, %{voided: _voided, reversal: reversal}} = Ledger.void_transaction(transaction)

      [active_reversal] = Ledger.list_transactions(entity_id: entity.id)
      assert active_reversal.id == reversal.id

      assert 2 == Enum.count(Ledger.list_transactions(entity_id: entity.id, include_voided: true))
      assert Enum.all?(Ledger.list_transactions(entity_id: entity.id), &is_nil(&1.voided_at))
    end

    test "filters by source_type, account_id, and date range" do
      %{entity: entity, checking: checking, groceries: groceries} = transaction_accounts_fixture()

      savings =
        account_fixture(entity, %{name: "Savings Filter", operational_subtype: :bank_savings})

      {:ok, import_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-10],
          description: "Imported groceries",
          source_type: :import,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-20.00")},
            %{account_id: groceries.id, amount: Decimal.new("20.00")}
          ]
        })

      {:ok, manual_tx} =
        Ledger.create_transaction(%{
          entity_id: entity.id,
          date: ~D[2026-03-11],
          description: "Savings transfer",
          source_type: :manual,
          postings: [
            %{account_id: checking.id, amount: Decimal.new("-50.00")},
            %{account_id: savings.id, amount: Decimal.new("50.00")}
          ]
        })

      assert [result] = Ledger.list_transactions(entity_id: entity.id, source_type: :import)
      assert result.id == import_tx.id

      assert [result] = Ledger.list_transactions(entity_id: entity.id, account_id: groceries.id)
      assert result.id == import_tx.id

      results =
        Ledger.list_transactions(
          entity_id: entity.id,
          date_from: ~D[2026-03-11],
          date_to: ~D[2026-03-11]
        )

      assert Enum.map(results, & &1.id) == [manual_tx.id]

      assert Enum.all?(
               results,
               &(Ecto.assoc_loaded?(&1.postings) and
                   Enum.all?(&1.postings, fn posting -> Ecto.assoc_loaded?(posting.account) end))
             )
    end

    test "orders by date desc then inserted_at desc" do
      %{entity: entity} = transaction_accounts_fixture()
      older = create_balanced_transaction(entity, %{description: "Older", date: ~D[2026-03-10]})
      newer = create_balanced_transaction(entity, %{description: "Newer", date: ~D[2026-03-11]})

      assert [first, second] = Ledger.list_transactions(entity_id: entity.id)
      assert [first.id, second.id] == [newer.id, older.id]
    end
  end

  describe "void_transaction/2" do
    test "marks the original voided, creates a reversal, and emits a void audit event" do
      %{checking: checking, groceries: groceries} = transaction_accounts_fixture()
      transaction = create_balanced_transaction(checking, groceries, %{description: "Dinner"})

      assert {:ok, %{voided: voided, reversal: reversal}} =
               Ledger.void_transaction(transaction, actor: "person", channel: :web)

      assert voided.id == transaction.id
      assert %DateTime{} = voided.voided_at
      assert is_nil(reversal.voided_at)
      assert reversal.source_type == :system
      assert voided.correlation_id == reversal.correlation_id

      assert Enum.map(reversal.postings, &{&1.account_id, &1.amount}) ==
               Enum.map(transaction.postings, &{&1.account_id, Decimal.negate(&1.amount)})

      [event] = Audit.list_audit_events(entity_id: transaction.id)
      assert event.action == "voided"
      assert event.actor == "person"
      assert event.channel == :web
      assert event.before["voided_at"] == nil
      assert event.after["voided_at"]
      assert Audit.list_audit_events(entity_id: reversal.id) == []
      assert Audit.list_audit_events(entity_type: "posting") == []
      assert Ledger.get_account_balance(checking.id) == %{"USD" => Decimal.new("0.00")}
    end

    test "rejects double void" do
      %{entity: entity} = transaction_accounts_fixture()
      transaction = create_balanced_transaction(entity, %{description: "Void once"})

      assert {:ok, %{voided: _voided, reversal: _reversal}} = Ledger.void_transaction(transaction)
      voided = Ledger.get_transaction!(entity.id, transaction.id)

      assert {:error, changeset} = Ledger.void_transaction(voided)
      assert "This transaction has already been voided." in errors_on(changeset).voided_at
    end
  end

  describe "get_account_balance/2" do
    test "derives balances from postings and filters by as_of_date" do
      %{checking: checking, groceries: groceries} = transaction_accounts_fixture()

      _first =
        create_balanced_transaction(checking, groceries, %{
          description: "First",
          date: ~D[2026-03-01]
        })

      _second =
        create_balanced_transaction(checking, groceries, %{
          description: "Second",
          date: ~D[2026-03-05]
        })

      assert Ledger.get_account_balance(checking.id) == %{"USD" => Decimal.new("-20.00")}

      assert Ledger.get_account_balance(checking.id, as_of_date: ~D[2026-03-01]) == %{
               "USD" => Decimal.new("-10.00")
             }
    end

    test "returns exactly one currency key for a populated account" do
      %{checking: checking, groceries: groceries} = transaction_accounts_fixture()

      _transaction =
        create_balanced_transaction(checking, groceries, %{description: "Single currency"})

      assert %{"USD" => balance} = Ledger.get_account_balance(checking.id)
      assert Decimal.eq?(balance, Decimal.new("-10.00"))
      assert map_size(Ledger.get_account_balance(checking.id)) == 1
    end
  end

  describe "audit events integration" do
    test "create/update/archive/unarchive emit redacted account audit events" do
      entity = entity_fixture(%{name: "Audited entity"})

      assert {:ok, account} =
               Ledger.create_account(
                 %{
                   entity_id: entity.id,
                   name: "Audited account",
                   account_type: :asset,
                   operational_subtype: :bank_checking,
                   management_group: :institution,
                   currency_code: "usd",
                   institution_name: "Bank Example",
                   institution_account_ref: "1234"
                 },
                 actor: "person",
                 channel: :web
               )

      assert {:ok, account} =
               Ledger.update_account(
                 account,
                 %{notes: "updated"},
                 actor: "scheduler",
                 channel: :system
               )

      assert {:ok, account} = Ledger.archive_account(account, actor: "person", channel: :mcp)
      assert {:ok, account} = Ledger.unarchive_account(account, actor: "person", channel: :web)

      events =
        Audit.list_audit_events(entity_id: account.id)
        |> Enum.sort_by(& &1.occurred_at, {:asc, DateTime})

      assert length(events) == 4

      [created, updated, archived, unarchived] = events

      assert created.entity_type == "account"
      assert created.action == "created"
      assert created.actor == "person"
      assert created.channel == :web
      assert created.before == nil
      assert created.after["currency_code"] == "USD"
      assert created.after["management_group"] == "institution"
      assert created.after["institution_account_ref"] == "[REDACTED]"

      assert updated.action == "updated"
      assert updated.actor == "scheduler"
      assert updated.channel == :system
      assert updated.before["notes"] == nil
      assert updated.after["notes"] == "updated"
      assert updated.before["institution_account_ref"] == "[REDACTED]"
      assert updated.after["institution_account_ref"] == "[REDACTED]"

      assert archived.action == "archived"
      assert archived.channel == :mcp
      assert archived.before["archived_at"] == nil
      refute is_nil(archived.after["archived_at"])

      assert unarchived.action == "unarchived"
      assert unarchived.channel == :web
      refute is_nil(unarchived.before["archived_at"])
      assert unarchived.after["archived_at"] == nil
    end
  end

  defp transaction_accounts_fixture do
    entity = entity_fixture()
    checking = account_fixture(entity, %{name: "Checking #{System.unique_integer([:positive])}"})

    groceries =
      account_fixture(entity, %{
        name: "Groceries #{System.unique_integer([:positive])}",
        account_type: :expense,
        operational_subtype: nil,
        management_group: :category
      })

    %{entity: entity, checking: checking, groceries: groceries}
  end

  defp create_balanced_transaction(entity, attrs) when is_map(entity) do
    checking =
      account_fixture(entity, %{
        name: "Test Checking #{System.unique_integer([:positive])}",
        account_type: :asset,
        operational_subtype: :bank_checking,
        management_group: :institution
      })

    expense =
      account_fixture(entity, %{
        name: "Test Expense #{System.unique_integer([:positive])}",
        account_type: :expense,
        operational_subtype: nil,
        management_group: :category
      })

    create_balanced_transaction(checking, expense, attrs)
  end

  defp create_balanced_transaction(checking, expense, attrs) do
    params =
      %{
        entity_id: checking.entity_id,
        date: Date.utc_today(),
        description: "Fixture transaction",
        source_type: :manual,
        postings: [
          %{account_id: checking.id, amount: Decimal.new("-10.00")},
          %{account_id: expense.id, amount: Decimal.new("10.00")}
        ]
      }
      |> Map.merge(attrs)

    {:ok, transaction} = Ledger.create_transaction(params)
    transaction
  end
end
