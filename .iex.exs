import Ecto.Query

alias AurumFinance.Audit
alias AurumFinance.Audit.AuditEvent
alias AurumFinance.Auth
alias AurumFinance.Classification
alias AurumFinance.Classification.ClassificationRecord
alias AurumFinance.Classification.Rule
alias AurumFinance.Classification.RuleAction
alias AurumFinance.Classification.RuleGroup
alias AurumFinance.Currency
alias AurumFinance.Entities
alias AurumFinance.Entities.Entity
alias AurumFinance.Ingestion
alias AurumFinance.Ingestion.ImportMaterialization
alias AurumFinance.Ingestion.ImportRowMaterialization
alias AurumFinance.Ingestion.ImportedFile
alias AurumFinance.Ingestion.ImportedRow
alias AurumFinance.Ledger
alias AurumFinance.Ledger.Account
alias AurumFinance.Ledger.Posting
alias AurumFinance.Ledger.Transaction
alias AurumFinance.Reconciliation
alias AurumFinance.Reconciliation.PostingReconciliationState
alias AurumFinance.Reconciliation.ReconciliationAuditLog
alias AurumFinance.Reconciliation.ReconciliationSession
alias AurumFinance.Repo

defmodule Dev do
  @moduledoc false

  import Ecto.Query

  alias AurumFinance.Audit
  alias AurumFinance.Classification
  alias AurumFinance.Classification.RuleGroup
  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ingestion
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Reconciliation
  alias AurumFinance.Repo

  require Logger

  # Repo shortcuts for quick querying from the console.
  def all(queryable), do: Repo.all(queryable)

  def one(queryable), do: Repo.one(queryable)

  def count(queryable), do: Repo.aggregate(queryable, :count)

  def get(schema, id), do: Repo.get(schema, id)

  def get!(schema, id), do: Repo.get!(schema, id)

  def reload(struct), do: Repo.reload(struct)

  def reload!(struct), do: Repo.reload!(struct)

  # Fetch the newest records by a timestamp field, usually :inserted_at.
  def recent(queryable, limit \\ 10, field \\ :inserted_at) do
    queryable
    |> order_by([record], desc: field(record, ^field))
    |> limit(^limit)
    |> Repo.all()
  end

  def last(queryable, field \\ :inserted_at) do
    queryable
    |> recent(1, field)
    |> List.first()
  end

  # Inspect the SQL Ecto would send without executing the query.
  def sql(queryable), do: Ecto.Adapters.SQL.to_sql(:all, Repo, queryable)

  # Pull ids from a list of schemas to chain into other calls.
  def ids(records), do: Enum.map(records, & &1.id)

  # Quick schema introspection for table/fields/associations.
  def describe(schema) when is_atom(schema) do
    if function_exported?(schema, :__schema__, 1) do
      %{
        source: schema.__schema__(:source),
        fields: schema.__schema__(:fields),
        associations: schema.__schema__(:associations)
      }
    else
      {:error, :not_an_ecto_schema}
    end
  end

  def describe(_schema), do: {:error, :not_a_module}

  # Domain helpers for the main persisted Aurum flows.
  def entities(opts \\ []), do: Entities.list_entities(opts)

  def entity!(id), do: Entities.get_entity!(id)

  def latest_entity do
    Entity
    |> order_by([entity], desc: entity.inserted_at, desc: entity.id)
    |> limit(1)
    |> Repo.one()
  end

  def accounts(opts \\ []) do
    case with_default_entity_scope(opts) do
      {:ok, scoped_opts} -> Ledger.list_accounts(scoped_opts)
      :error -> []
    end
  end

  def account!(entity_id, account_id), do: Ledger.get_account!(entity_id, account_id)

  def latest_account(entity_id \\ nil)

  def latest_account(nil) do
    case latest_entity() do
      nil -> nil
      entity -> latest_account(entity.id)
    end
  end

  def latest_account(entity_id) do
    Account
    |> where([account], account.entity_id == ^entity_id)
    |> order_by([account], desc: account.inserted_at, desc: account.id)
    |> limit(1)
    |> Repo.one()
  end

  def transactions(opts \\ []) do
    case with_default_entity_scope(opts) do
      {:ok, scoped_opts} -> Ledger.list_transactions(scoped_opts)
      :error -> []
    end
  end

  def transaction!(entity_id, transaction_id),
    do: Ledger.get_transaction!(entity_id, transaction_id)

  def imported_files(opts \\ []) do
    case with_default_account_scope(opts) do
      {:ok, scoped_opts} -> Ingestion.list_imported_files(scoped_opts)
      :error -> []
    end
  end

  def imported_rows(opts \\ []) do
    case with_default_account_scope(opts) do
      {:ok, scoped_opts} -> Ingestion.list_imported_rows(scoped_opts)
      :error -> []
    end
  end

  def materializations(opts \\ []) do
    case with_default_account_scope(opts) do
      {:ok, scoped_opts} -> Ingestion.list_import_materializations(scoped_opts)
      :error -> []
    end
  end

  def rule_groups(opts \\ []), do: Classification.list_rule_groups(opts)

  def latest_rule_group do
    RuleGroup
    |> order_by([rule_group], desc: rule_group.inserted_at, desc: rule_group.id)
    |> limit(1)
    |> Repo.one()
  end

  def rules(opts \\ []) do
    case with_default_rule_group_scope(opts) do
      {:ok, scoped_opts} -> Classification.list_rules(scoped_opts)
      :error -> []
    end
  end

  def reconciliation_sessions(opts \\ []) do
    case with_default_entity_scope(opts) do
      {:ok, scoped_opts} -> Reconciliation.list_reconciliation_sessions(scoped_opts)
      :error -> []
    end
  end

  def audit_events(opts \\ []), do: Audit.list_audit_events(opts)

  # Recompile the project from the current IEx session.
  def recompile!, do: IEx.Helpers.recompile()

  # Logger helpers for noisy dev sessions. Query logs are emitted at :debug,
  # so switching between :info and :debug is usually enough.
  def log_level, do: Logger.level()

  def log_get, do: log_level()

  def logs(level) when level in [:debug, :info, :warning, :error] do
    :ok = Logger.configure(level: level)
    IO.puts("Logger level set to #{level}.")
    level
  end

  def log_set(level), do: logs(level)

  def verbose_logs, do: logs(:debug)

  def quiet_logs, do: logs(:info)

  def log_verbose, do: verbose_logs()

  def log_quiet, do: quiet_logs()

  def examples do
    IO.puts("""
    Copy/paste examples:

      Dev.quiet_logs()
      Dev.log_level()

      Dev.entities()
      Dev.latest_entity()
      Dev.latest_account()
      Dev.accounts()
      Dev.transactions()
      Dev.imported_files()
      Dev.rule_groups()
      Dev.reconciliation_sessions()

      from(a in Account, where: a.currency_code == "USD") |> Dev.sql()
    """)
  end

  def help do
    IO.puts("""
    AurumFinance IEx helpers

    Logs:
      Dev.log_level()      current level
      Dev.log_get()        alias of Dev.log_level()
      Dev.logs(:info)      set level (:debug | :info | :warning | :error)
      Dev.log_set(:info)   alias of Dev.logs/1
      Dev.quiet_logs()     hide verbose query/debug logs
      Dev.verbose_logs()   show query/debug logs again
      Dev.log_quiet()      alias of Dev.quiet_logs()
      Dev.log_verbose()    alias of Dev.verbose_logs()

    Data:
      Dev.all(query)              run Entity or from(...)
      Dev.one(query)              fetch one result
      Dev.count(query)            count rows
      Dev.recent(query)           newest rows
      Dev.last(query)             latest row
      Dev.get(Schema, id)         fetch by id
      Dev.describe(Schema)        fields + associations
      Dev.sql(query)              inspect SQL

    Aurum:
      Dev.entities()
      Dev.latest_entity()
      Dev.latest_account()
      Dev.accounts()
      Dev.transactions()
      Dev.imported_files()
      Dev.rule_groups()
      Dev.reconciliation_sessions()
      Dev.audit_events()

    Examples:
      Dev.log_get()
      Dev.log_set(:info)
      Dev.latest_entity()
      Dev.latest_account()
      Dev.accounts()
      Dev.transactions()
      Dev.imported_files()
      from(a in Account, where: a.currency_code == "USD") |> Dev.sql()

    Tip:
      Startup logs appear before `.iex.exs` runs, so these helpers only affect
      logs after you reach the IEx prompt.
      Run `Dev.examples()` for copy/paste-ready commands.
    """)
  end

  defp with_default_entity_scope(opts) do
    case Keyword.get(opts, :entity_id) do
      nil ->
        case latest_entity() do
          nil -> :error
          entity -> {:ok, Keyword.put(opts, :entity_id, entity.id)}
        end

      _entity_id ->
        {:ok, opts}
    end
  end

  defp with_default_account_scope(opts) do
    case Keyword.get(opts, :account_id) do
      nil ->
        case latest_account() do
          nil -> :error
          account -> {:ok, Keyword.put(opts, :account_id, account.id)}
        end

      _account_id ->
        {:ok, opts}
    end
  end

  defp with_default_rule_group_scope(opts) do
    case Keyword.get(opts, :rule_group_id) do
      nil ->
        case latest_rule_group() do
          nil -> :error
          rule_group -> {:ok, Keyword.put(opts, :rule_group_id, rule_group.id)}
        end

      _rule_group_id ->
        {:ok, opts}
    end
  end
end

IEx.configure(
  inspect: [
    pretty: true,
    limit: 200,
    printable_limit: 4_000,
    charlists: :as_lists
  ]
)

IO.puts("AurumFinance IEx loaded. Run Dev.help() for shortcuts and examples.")
IO.puts("Try Dev.accounts(), Dev.quiet_logs(), or Dev.examples().")
