defmodule AurumFinance.Factory do
  @moduledoc """
  Shared ExMachina factories for deterministic test setup.
  """

  use ExMachina.Ecto, repo: AurumFinance.Repo

  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Classification.Rule
  alias AurumFinance.Classification.RuleAction
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Classification
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Reconciliation
  alias AurumFinance.Reconciliation.PostingReconciliationState
  alias AurumFinance.Reconciliation.ReconciliationAuditLog
  alias AurumFinance.Reconciliation.ReconciliationSession
  alias AurumFinance.Repo

  def entity_factory do
    %Entity{
      name: sequence(:entity_name, fn n -> "#{Faker.Person.name()} #{n}" end),
      type: :individual,
      country_code: "US",
      fiscal_residency_country_code: "US",
      default_tax_rate_type: "irs_official",
      notes: Faker.Lorem.sentence()
    }
  end

  def account_factory do
    entity = insert(:entity)

    %Account{
      entity: entity,
      entity_id: entity.id,
      name: sequence(:account_name, fn n -> "#{Faker.Company.bs()} #{n}" end),
      account_type: :asset,
      operational_subtype: :bank_checking,
      management_group: :institution,
      currency_code: "USD",
      institution_name: Faker.Company.name(),
      institution_account_ref: sequence(:account_ref, fn n -> Integer.to_string(1000 + n) end),
      notes: Faker.Lorem.sentence()
    }
  end

  def rule_group_factory do
    entity = insert(:entity)

    %RuleGroup{
      scope_type: :entity,
      entity: entity,
      entity_id: entity.id,
      account: nil,
      account_id: nil,
      name: sequence(:rule_group_name, fn n -> "Rule Group #{n}" end),
      description: Faker.Lorem.sentence(),
      priority: sequence(:rule_group_priority, & &1),
      target_fields: [],
      is_active: true
    }
  end

  def rule_factory do
    rule_group = insert(:rule_group)

    %Rule{
      rule_group: rule_group,
      rule_group_id: rule_group.id,
      name: sequence(:rule_name, fn n -> "Rule #{n}" end),
      description: Faker.Lorem.sentence(),
      position: sequence(:rule_position, & &1),
      is_active: true,
      stop_processing: true,
      expression: ~s(description contains "Uber"),
      actions: [
        %RuleAction{
          field: :tags,
          operation: :add,
          value: "ride"
        }
      ]
    }
  end

  def insert_rule_group(attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      :rule_group
      |> params_for()
      |> Map.merge(attrs)

    {:ok, rule_group} = Classification.create_rule_group(params)
    rule_group
  end

  def insert_rule(rule_group, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      %{
        rule_group_id: rule_group.id,
        name: sequence(:insert_rule_name, fn n -> "Inserted Rule #{n}" end),
        position: sequence(:insert_rule_position, & &1),
        expression: ~s(description contains "Uber"),
        actions: [%{field: :tags, operation: :add, value: "ride"}]
      }
      |> Map.merge(attrs)

    {:ok, rule} = Classification.create_rule(params)
    rule
  end

  def transaction_factory do
    entity = insert(:entity)

    %Transaction{
      entity: entity,
      entity_id: entity.id,
      date: Date.utc_today(),
      description: sequence(:transaction_description, fn n -> "Transaction #{n}" end),
      source_type: :manual,
      correlation_id: nil,
      voided_at: nil
    }
  end

  def posting_factory do
    entity = insert(:entity)
    transaction = insert(:transaction, entity: entity, entity_id: entity.id)
    account = insert(:account, entity: entity, entity_id: entity.id)

    %Posting{
      transaction: transaction,
      transaction_id: transaction.id,
      account: account,
      account_id: account.id,
      amount: Decimal.new("10.00")
    }
  end

  def reconciliation_session_factory do
    entity = insert(:entity)
    account = insert(:account, entity: entity, entity_id: entity.id)

    %ReconciliationSession{
      entity: entity,
      entity_id: entity.id,
      account: account,
      account_id: account.id,
      statement_date: Date.utc_today(),
      statement_balance: Decimal.new("1000.00"),
      completed_at: nil
    }
  end

  def posting_reconciliation_state_factory do
    entity = insert(:entity)
    account = insert(:account, entity: entity, entity_id: entity.id)
    transaction = insert(:transaction, entity: entity, entity_id: entity.id)

    posting =
      insert(:posting,
        transaction: transaction,
        transaction_id: transaction.id,
        account: account,
        account_id: account.id
      )

    session =
      insert(
        :reconciliation_session,
        entity: entity,
        entity_id: entity.id,
        account: account,
        account_id: account.id
      )

    %PostingReconciliationState{
      entity: entity,
      entity_id: entity.id,
      posting: posting,
      posting_id: posting.id,
      reconciliation_session: session,
      reconciliation_session_id: session.id,
      status: :cleared,
      reason: nil
    }
  end

  def reconciliation_audit_log_factory do
    state = insert(:posting_reconciliation_state)

    %ReconciliationAuditLog{
      posting_reconciliation_state: nil,
      posting_reconciliation_state_id: nil,
      reconciliation_session: state.reconciliation_session,
      reconciliation_session_id: state.reconciliation_session_id,
      posting: state.posting,
      posting_id: state.posting_id,
      from_status: nil,
      to_status: "cleared",
      actor: sequence(:reconciliation_actor, fn n -> "actor-#{n}" end),
      channel: "web",
      occurred_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      metadata: %{"source" => "factory"}
    }
  end

  def insert_entity(attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      :entity
      |> params_for()
      |> Map.merge(attrs)

    {:ok, entity} = Entities.create_entity(params)
    entity
  end

  def insert_account(entity, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    params =
      %{
        entity_id: entity.id,
        name: sequence(:insert_account_name, fn n -> "Account #{n}" end),
        account_type: :asset,
        operational_subtype: :bank_checking,
        management_group: :institution,
        currency_code: "USD",
        institution_name: "Institution",
        institution_account_ref: sequence(:insert_account_ref, &"REF-#{&1}"),
        notes: "factory account"
      }
      |> Map.merge(attrs)

    {:ok, account} = Ledger.create_account(params)
    account
  end

  def insert_reconciliation_session(entity, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    account =
      case {Map.get(attrs, :account), Map.get(attrs, :account_id)} do
        {%Account{} = account, _account_id} ->
          account

        {nil, account_id} when is_binary(account_id) ->
          Ledger.get_account!(entity.id, account_id)

        _ ->
          insert_account(entity)
      end

    params =
      %{
        entity_id: entity.id,
        account_id: account.id,
        statement_date: Date.utc_today(),
        statement_balance: Decimal.new("1000.00")
      }
      |> Map.merge(Map.drop(attrs, [:entity, :account]))

    {:ok, session} =
      Reconciliation.create_reconciliation_session(params, entity_id: entity.id)

    session
  end

  def insert_posting_reconciliation_state(entity, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    account =
      case Map.get(attrs, :account) do
        %Account{} = account -> account
        _ -> insert_account(entity)
      end

    transaction =
      case Map.get(attrs, :transaction) do
        %Transaction{} = transaction -> transaction
        _ -> insert(:transaction, entity: entity, entity_id: entity.id)
      end

    posting =
      case Map.get(attrs, :posting) do
        %Posting{} = posting ->
          posting

        _ ->
          insert(
            :posting,
            transaction: transaction,
            transaction_id: transaction.id,
            account: account,
            account_id: account.id
          )
      end

    session =
      case Map.get(attrs, :reconciliation_session) do
        %ReconciliationSession{} = session -> session
        _ -> insert_reconciliation_session(entity, account: account)
      end

    params =
      %{
        entity_id: entity.id,
        posting_id: posting.id,
        reconciliation_session_id: session.id,
        status: :cleared,
        reason: nil
      }
      |> Map.merge(
        Map.drop(attrs, [:entity, :account, :transaction, :posting, :reconciliation_session])
      )

    %PostingReconciliationState{}
    |> PostingReconciliationState.changeset(params)
    |> Repo.insert!()
  end

  def insert_reconciliation_audit_log(entity, attrs \\ %{}) do
    attrs = normalize_attrs(attrs)

    state =
      case Map.get(attrs, :posting_reconciliation_state) do
        %PostingReconciliationState{} = state -> state
        _ -> insert_posting_reconciliation_state(entity)
      end

    params =
      %{
        posting_reconciliation_state_id:
          Map.get(attrs, :posting_reconciliation_state_id, state.id),
        reconciliation_session_id: state.reconciliation_session_id,
        posting_id: state.posting_id,
        from_status: nil,
        to_status: "cleared",
        actor: sequence(:insert_reconciliation_actor, &"actor-#{&1}"),
        channel: "web",
        occurred_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
        metadata: %{"source" => "factory"}
      }
      |> Map.merge(Map.drop(attrs, [:posting_reconciliation_state]))

    %ReconciliationAuditLog{}
    |> ReconciliationAuditLog.changeset(params)
    |> Repo.insert!()
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)
  defp normalize_attrs(attrs), do: attrs
end
