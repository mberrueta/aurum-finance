defmodule AurumFinance.LedgerTest do
  use AurumFinance.DataCase, async: true

  alias AurumFinance.Audit
  alias AurumFinance.Entities
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account

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

    test "get_account_balance/2 returns an empty map placeholder" do
      assert %{} == Ledger.get_account_balance(Ecto.UUID.generate())
      assert %{} == Ledger.get_account_balance(Ecto.UUID.generate(), as_of_date: ~D[2026-03-07])
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

  defp entity_fixture(attrs) do
    base = %{
      name: "Entity #{System.unique_integer([:positive])}",
      type: :individual,
      country_code: "BR"
    }

    {:ok, entity} = base |> Map.merge(attrs) |> Entities.create_entity()
    entity
  end

  defp account_fixture(entity, attrs \\ %{}) do
    base = %{
      entity_id: entity.id,
      name: "Account #{System.unique_integer([:positive])}",
      account_type: :asset,
      operational_subtype: :bank_checking,
      management_group: :institution,
      currency_code: "USD"
    }

    {:ok, account} = base |> Map.merge(attrs) |> Ledger.create_account()
    account
  end
end
