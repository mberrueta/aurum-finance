defmodule AurumFinance.Ledger do
  @moduledoc """
  The Ledger context, responsible for canonical account records and derived balances.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Ledger.Posting
  alias AurumFinance.Ledger.Transaction
  alias AurumFinance.Repo

  @entity_type "account"
  @transaction_entity_type "transaction"
  @default_actor "system"
  @audit_redact_fields [:institution_account_ref]

  @type list_opt ::
          {:entity_id, Ecto.UUID.t()}
          | {:include_archived, boolean()}
          | {:management_group, :institution | :category | :system_managed}
          | {:account_type, :asset | :liability | :equity | :income | :expense}
          | {:operational_subtype,
             :bank_checking
             | :bank_savings
             | :cash
             | :brokerage_cash
             | :brokerage_securities
             | :crypto_wallet
             | :credit_card
             | :loan
             | :other_asset
             | :other_liability}
          | {:source_type, :manual | :import | :system}
          | {:account_id, Ecto.UUID.t()}
          | {:date_from, Date.t()}
          | {:date_to, Date.t()}

  @type management_group :: :institution | :category | :system_managed

  @type audit_opt ::
          {:actor, String.t()}
          | {:channel, :web | :system | :mcp | :ai_assistant}

  @type balance_opt :: {:as_of_date, Date.t()}

  @doc """
  Lists accounts within one entity scope with optional filters.

  By default, archived accounts are excluded.

  ## Examples

  Happy path:

  ```elixir
  accounts = AurumFinance.Ledger.list_accounts(entity_id: entity.id, management_group: :institution)
  ```

  Error path:

      iex> AurumFinance.Ledger.list_accounts()
      ** (ArgumentError) list_accounts/1 requires :entity_id
  """
  @spec list_accounts([list_opt()]) :: [Account.t()]
  def list_accounts(opts \\ []) do
    opts =
      opts
      |> require_entity_scope!("list_accounts/1")
      |> Keyword.put_new(:include_archived, false)

    Account
    |> filter_query(opts)
    |> order_by([account], asc: account.name)
    |> Repo.all()
  end

  @doc """
  Lists accounts for a specific management group within one entity scope.

  ## Examples

  Happy path:

  ```elixir
  institution_accounts =
    AurumFinance.Ledger.list_accounts_by_management_group(:institution, entity_id: entity.id)
  ```

  Error path:

      iex> AurumFinance.Ledger.list_accounts_by_management_group(:unknown, entity_id: Ecto.UUID.generate())
      ** (ArgumentError) unsupported management group: :unknown
  """
  def list_accounts_by_management_group(management_group, opts \\ [])

  @spec list_accounts_by_management_group(management_group(), [list_opt()]) :: [Account.t()]
  def list_accounts_by_management_group(management_group, opts)
      when management_group in [:institution, :category, :system_managed] do
    opts =
      opts
      |> require_entity_scope!("list_accounts_by_management_group/2")
      |> Keyword.put_new(:include_archived, false)
      |> Keyword.put(:management_group, management_group)

    Account
    |> filter_query(opts)
    |> order_by([account], asc: account.name)
    |> Repo.all()
  end

  def list_accounts_by_management_group(management_group, _opts) do
    raise ArgumentError, "unsupported management group: #{inspect(management_group)}"
  end

  @doc """
  Lists institution-backed accounts within one entity scope.

  ## Examples

  ```elixir
  accounts = AurumFinance.Ledger.list_institution_accounts(entity_id: entity.id)
  ```
  """
  @spec list_institution_accounts([list_opt()]) :: [Account.t()]
  def list_institution_accounts(opts \\ []) do
    list_accounts_by_management_group(:institution, opts)
  end

  @doc """
  Lists category accounts within one entity scope.

  ## Examples

  ```elixir
  accounts = AurumFinance.Ledger.list_category_accounts(entity_id: entity.id)
  ```
  """
  @spec list_category_accounts([list_opt()]) :: [Account.t()]
  def list_category_accounts(opts \\ []) do
    list_accounts_by_management_group(:category, opts)
  end

  @doc """
  Lists system-managed accounts within one entity scope.

  ## Examples

  ```elixir
  accounts = AurumFinance.Ledger.list_system_managed_accounts(entity_id: entity.id)
  ```
  """
  @spec list_system_managed_accounts([list_opt()]) :: [Account.t()]
  def list_system_managed_accounts(opts \\ []) do
    list_accounts_by_management_group(:system_managed, opts)
  end

  @doc """
  Fetches one account by id within an explicit entity scope.

  Raises `Ecto.NoResultsError` when the account does not exist inside that
  entity boundary.

  ## Examples

  Happy path:

  ```elixir
  account = AurumFinance.Ledger.get_account!(entity.id, account.id)
  ```

  Error path:

  ```elixir
  AurumFinance.Ledger.get_account!(entity.id, Ecto.UUID.generate())
  # raises Ecto.NoResultsError
  ```
  """
  @spec get_account!(Ecto.UUID.t(), Ecto.UUID.t()) :: Account.t()
  def get_account!(entity_id, account_id) do
    get_account(entity_id, account_id) || raise Ecto.NoResultsError, queryable: Account
  end

  @doc false
  @spec get_account(Ecto.UUID.t(), Ecto.UUID.t()) :: Account.t() | nil
  def get_account(entity_id, account_id) do
    Account
    |> where([account], account.id == ^account_id and account.entity_id == ^entity_id)
    |> Repo.one()
  end

  @doc """
  Creates an account and emits an audit event.

  ## Examples

  Happy path:

  ```elixir
  {:ok, account} =
    AurumFinance.Ledger.create_account(%{
      entity_id: entity.id,
      name: "Checking",
      account_type: :asset,
      operational_subtype: :bank_checking,
      management_group: :institution,
      currency_code: "USD"
    })
  ```
  """
  @spec create_account(map()) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  @spec create_account(map(), [audit_opt()]) ::
          {:ok, Account.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, Ecto.Changeset.t(), Account.t()}}
  def create_account(attrs, opts \\ []) do
    audit_metadata = extract_audit_metadata(opts)

    Audit.with_event(
      %{
        event: "created",
        target: nil,
        entity_type: @entity_type,
        actor: audit_metadata.actor,
        channel: audit_metadata.channel,
        redact_fields: @audit_redact_fields
      },
      fn -> Repo.insert(Account.changeset(%Account{}, attrs)) end,
      serializer: &account_snapshot/1
    )
  end

  @doc """
  Updates an existing account and emits an audit event.

  ## Examples

  Happy path:

  ```elixir
  {:ok, account} =
    AurumFinance.Ledger.update_account(account, %{
      notes: "Imported from OFX"
    })
  ```

  Error path:

  ```elixir
  {:error, changeset} =
    AurumFinance.Ledger.update_account(account, %{
      currency_code: "EUR"
    })
  ```
  """
  @spec update_account(Account.t(), map()) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  @spec update_account(Account.t(), map(), [audit_opt()]) ::
          {:ok, Account.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, Ecto.Changeset.t(), Account.t()}}
  def update_account(%Account{} = account, attrs, opts \\ []) do
    update_account_with_action(account, attrs, "updated", opts)
  end

  @doc """
  Soft-archives an account by setting `archived_at` and emits an audit event.

  ## Examples

  ```elixir
  {:ok, archived_account} = AurumFinance.Ledger.archive_account(account)
  ```
  """
  @spec archive_account(Account.t()) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  @spec archive_account(Account.t(), [audit_opt()]) ::
          {:ok, Account.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, Ecto.Changeset.t(), Account.t()}}
  def archive_account(%Account{} = account, opts \\ []) do
    update_account_with_action(account, %{archived_at: DateTime.utc_now()}, "archived", opts)
  end

  @doc """
  Removes archive state from an account by setting `archived_at` to `nil`.

  ## Examples

  ```elixir
  {:ok, active_account} = AurumFinance.Ledger.unarchive_account(account)
  ```
  """
  @spec unarchive_account(Account.t()) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  @spec unarchive_account(Account.t(), [audit_opt()]) ::
          {:ok, Account.t()}
          | {:error, Ecto.Changeset.t()}
          | {:error, {:audit_failed, Ecto.Changeset.t(), Account.t()}}
  def unarchive_account(%Account{} = account, opts \\ []) do
    update_account_with_action(account, %{archived_at: nil}, "unarchived", opts)
  end

  @doc """
  Returns a changeset for account form handling.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Ledger.change_account(%AurumFinance.Ledger.Account{}, %{
      ...>     entity_id: Ecto.UUID.generate(),
      ...>     name: "Wallet",
      ...>     account_type: :asset,
      ...>     operational_subtype: :cash,
      ...>     management_group: :institution,
      ...>     currency_code: "USD"
      ...>   })
      iex> changeset.valid?
      true
  """
  @spec change_account(Account.t(), map()) :: Ecto.Changeset.t()
  def change_account(%Account{} = account, attrs \\ %{}) do
    Account.changeset(account, attrs)
  end

  @doc """
  Creates a balanced transaction with nested postings atomically.

  ## Examples

  ```elixir
  {:ok, transaction} =
    AurumFinance.Ledger.create_transaction(%{
      entity_id: entity.id,
      date: ~D[2026-03-07],
      description: "Groceries",
      source_type: :manual,
      postings: [
        %{account_id: checking.id, amount: Decimal.new("-45.00")},
        %{account_id: groceries.id, amount: Decimal.new("45.00")}
      ]
    })
  ```
  """
  @spec create_transaction(map()) :: {:ok, Transaction.t()} | {:error, Ecto.Changeset.t()}
  @spec create_transaction(map(), [audit_opt()]) ::
          {:ok, Transaction.t()} | {:error, Ecto.Changeset.t()}
  def create_transaction(attrs, opts \\ []) do
    audit_metadata = extract_audit_metadata(opts)
    transaction_changeset = Transaction.changeset(%Transaction{}, attrs)
    posting_attrs = posting_attrs(attrs)

    case validate_transaction_for_insert(transaction_changeset, posting_attrs) do
      {:ok, validated_changeset, _accounts_by_id} ->
        persist_transaction(validated_changeset, posting_attrs, audit_metadata)

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Fetches one transaction by id within an explicit entity scope.

  ## Examples

  ```elixir
  transaction = AurumFinance.Ledger.get_transaction!(entity.id, transaction.id)
  ```
  """
  @spec get_transaction!(Ecto.UUID.t(), Ecto.UUID.t()) :: Transaction.t()
  def get_transaction!(entity_id, transaction_id) do
    Transaction
    |> where(
      [transaction],
      transaction.entity_id == ^entity_id and transaction.id == ^transaction_id
    )
    |> preload(postings: :account)
    |> Repo.one!()
  end

  @doc """
  Lists transactions within one entity scope with optional filters.

  ## Examples

  ```elixir
  transactions =
    AurumFinance.Ledger.list_transactions(
      entity_id: entity.id,
      source_type: :manual,
      include_voided: true
    )
  ```
  """
  @spec list_transactions([list_opt()]) :: [Transaction.t()]
  def list_transactions(opts \\ []) do
    opts =
      opts
      |> require_entity_scope!("list_transactions/1")
      |> Keyword.put_new(:include_voided, false)

    Transaction
    |> filter_query(opts)
    |> preload(postings: :account)
    |> order_by([transaction], desc: transaction.date, desc: transaction.inserted_at)
    |> Repo.all()
  end

  @doc """
  Voids a transaction by marking the original voided and inserting a reversal.

  ## Examples

  ```elixir
  {:ok, %{voided: voided, reversal: reversal}} =
    AurumFinance.Ledger.void_transaction(transaction)
  ```
  """
  @spec void_transaction(Transaction.t()) ::
          {:ok, %{voided: Transaction.t(), reversal: Transaction.t()}}
          | {:error, Ecto.Changeset.t()}
  @spec void_transaction(Transaction.t(), [audit_opt()]) ::
          {:ok, %{voided: Transaction.t(), reversal: Transaction.t()}}
          | {:error, Ecto.Changeset.t()}
  def void_transaction(%Transaction{} = transaction, opts \\ []) do
    audit_metadata = extract_audit_metadata(opts)
    transaction = Repo.preload(transaction, :postings)

    if transaction.voided_at do
      {:error,
       Transaction.void_changeset(transaction, %{
         voided_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
       })}
    else
      persist_void_transaction(transaction, audit_metadata)
    end
  end

  @doc """
  Returns the derived account balance.

  ## Examples

  ```elixir
  current_balance = AurumFinance.Ledger.get_account_balance(account.id)

  historical_balance =
    AurumFinance.Ledger.get_account_balance(account.id, as_of_date: ~D[2026-03-01])
  ```
  """
  @spec get_account_balance(Ecto.UUID.t(), [balance_opt()]) :: %{String.t() => Decimal.t()}
  def get_account_balance(account_id, opts \\ []) do
    as_of_date = Keyword.get(opts, :as_of_date)

    Posting
    |> join(:inner, [posting], account in Account, on: account.id == posting.account_id)
    |> join(:inner, [posting, _account], transaction in Transaction,
      on: transaction.id == posting.transaction_id
    )
    |> where([posting], posting.account_id == ^account_id)
    |> maybe_filter_balance_as_of_date(as_of_date)
    |> group_by([_posting, account], account.currency_code)
    |> select([posting, account], {account.currency_code, sum(posting.amount)})
    |> Repo.all()
    |> Map.new()
  end

  defp update_account_with_action(%Account{} = account, attrs, action, opts) do
    audit_metadata = extract_audit_metadata(opts)

    Audit.with_event(
      %{
        event: action,
        target: account,
        entity_type: @entity_type,
        actor: audit_metadata.actor,
        channel: audit_metadata.channel,
        redact_fields: @audit_redact_fields
      },
      fn -> Repo.update(Account.changeset(account, attrs)) end,
      serializer: &account_snapshot/1
    )
  end

  defp account_snapshot(account) when is_struct(account, Account) do
    %{
      "id" => account.id,
      "entity_id" => account.entity_id,
      "name" => account.name,
      "account_type" => account.account_type,
      "operational_subtype" => account.operational_subtype,
      "management_group" => account.management_group,
      "currency_code" => account.currency_code,
      "institution_name" => account.institution_name,
      "institution_account_ref" => account.institution_account_ref,
      "notes" => account.notes,
      "archived_at" => account.archived_at,
      "inserted_at" => account.inserted_at,
      "updated_at" => account.updated_at
    }
  end

  defp account_snapshot(value), do: value

  defp transaction_snapshot(%Transaction{} = transaction) do
    transaction = Repo.preload(transaction, :postings)

    %{
      "id" => transaction.id,
      "entity_id" => transaction.entity_id,
      "date" => transaction.date && Date.to_iso8601(transaction.date),
      "description" => transaction.description,
      "source_type" => transaction.source_type,
      "correlation_id" => transaction.correlation_id,
      "voided_at" => datetime_to_iso8601(transaction.voided_at),
      "inserted_at" => datetime_to_iso8601(transaction.inserted_at),
      "postings" =>
        Enum.map(transaction.postings, fn posting ->
          %{
            "id" => posting.id,
            "account_id" => posting.account_id,
            "amount" => Decimal.to_string(posting.amount)
          }
        end)
    }
  end

  defp transaction_snapshot(value), do: value

  defp extract_audit_metadata(opts) do
    actor =
      opts
      |> Keyword.get(:actor, @default_actor)
      |> normalize_actor()

    channel =
      case Keyword.get(opts, :channel, :system) do
        channel when channel in [:web, :system, :mcp, :ai_assistant] -> channel
        _ -> :system
      end

    %{actor: actor, channel: channel}
  end

  defp normalize_actor(actor) when is_binary(actor) do
    actor
    |> String.trim()
    |> case do
      "" -> @default_actor
      value -> value
    end
  end

  defp normalize_actor(_actor), do: @default_actor

  defp require_entity_scope!(opts, function_name) do
    case Keyword.fetch(opts, :entity_id) do
      {:ok, entity_id} when not is_nil(entity_id) -> opts
      _ -> raise ArgumentError, "#{function_name} requires :entity_id"
    end
  end

  defp filter_management_group(query, :institution) do
    where(query, [account], account.management_group == :institution)
  end

  defp filter_management_group(query, :category) do
    where(query, [account], account.management_group == :category)
  end

  defp filter_management_group(query, :system_managed) do
    where(query, [account], account.management_group == :system_managed)
  end

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:entity_id, entity_id} | rest]) do
    query
    |> where([account], account.entity_id == ^entity_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:include_archived, true} | rest]) do
    filter_query(query, rest)
  end

  defp filter_query(query, [{:include_archived, false} | rest]) do
    query
    |> where([account], is_nil(account.archived_at))
    |> filter_query(rest)
  end

  defp filter_query(query, [{:management_group, management_group} | rest]) do
    query
    |> filter_management_group(management_group)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:account_type, account_type} | rest]) do
    query
    |> where([account], account.account_type == ^account_type)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:operational_subtype, operational_subtype} | rest]) do
    query
    |> where([account], account.operational_subtype == ^operational_subtype)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:source_type, source_type} | rest]) do
    query
    |> where([transaction], transaction.source_type == ^source_type)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:include_voided, true} | rest]) do
    filter_query(query, rest)
  end

  defp filter_query(query, [{:include_voided, false} | rest]) do
    query
    |> where([transaction], is_nil(transaction.voided_at))
    |> filter_query(rest)
  end

  defp filter_query(query, [{:account_id, account_id} | rest]) do
    transaction_ids_query =
      from posting in Posting,
        where: posting.account_id == ^account_id,
        select: posting.transaction_id

    query
    |> where([transaction], transaction.id in subquery(transaction_ids_query))
    |> filter_query(rest)
  end

  defp filter_query(query, [{:date_from, %Date{} = date_from} | rest]) do
    query
    |> where([transaction], transaction.date >= ^date_from)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:date_to, %Date{} = date_to} | rest]) do
    query
    |> where([transaction], transaction.date <= ^date_to)
    |> filter_query(rest)
  end

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end

  defp posting_attrs(attrs) when is_map(attrs) do
    Map.get(attrs, :postings) || Map.get(attrs, "postings") || []
  end

  defp validate_transaction_for_insert(transaction_changeset, posting_attrs) do
    transaction_changeset =
      transaction_changeset
      |> validate_minimum_postings(posting_attrs)
      |> validate_posting_attrs(posting_attrs)

    account_ids = extract_account_ids(posting_attrs)
    accounts_by_id = load_accounts(account_ids)

    transaction_changeset =
      transaction_changeset
      |> validate_accounts_found(account_ids, accounts_by_id)
      |> validate_entity_isolation(posting_attrs, accounts_by_id)
      |> validate_zero_sum(posting_attrs, accounts_by_id)

    if transaction_changeset.valid? do
      {:ok, transaction_changeset, accounts_by_id}
    else
      {:error, transaction_changeset}
    end
  end

  defp validate_minimum_postings(changeset, posting_attrs) do
    if length(posting_attrs) < 2 do
      Ecto.Changeset.add_error(
        changeset,
        :postings,
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_transaction_minimum_postings"
        )
      )
    else
      changeset
    end
  end

  defp validate_posting_attrs(changeset, posting_attrs) do
    Enum.reduce(posting_attrs, changeset, fn posting_attr, acc ->
      acc
      |> validate_posting_field(posting_attr, :account_id)
      |> validate_posting_field(posting_attr, :amount)
      |> validate_posting_amount(posting_attr)
    end)
  end

  defp validate_posting_field(changeset, posting_attr, field) do
    value = posting_value(posting_attr, field)

    if is_nil(value) do
      Ecto.Changeset.add_error(
        changeset,
        :postings,
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
      )
    else
      changeset
    end
  end

  defp validate_posting_amount(changeset, posting_attr) do
    case posting_decimal(posting_attr) do
      {:ok, _amount} ->
        changeset

      :error ->
        Ecto.Changeset.add_error(
          changeset,
          :postings,
          Gettext.dgettext(
            AurumFinanceWeb.Gettext,
            "errors",
            "error_posting_amount_invalid"
          )
        )
    end
  end

  defp extract_account_ids(posting_attrs) do
    posting_attrs
    |> Enum.map(&posting_value(&1, :account_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp load_accounts([]), do: %{}

  defp load_accounts(account_ids) do
    from(account in Account,
      where: account.id in ^account_ids,
      select: %{
        id: account.id,
        entity_id: account.entity_id,
        currency_code: account.currency_code
      }
    )
    |> Repo.all()
    |> Map.new(fn account -> {account.id, account} end)
  end

  defp validate_accounts_found(changeset, account_ids, accounts_by_id) do
    if Enum.all?(account_ids, &Map.has_key?(accounts_by_id, &1)) do
      changeset
    else
      Ecto.Changeset.add_error(
        changeset,
        :postings,
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_transaction_account_not_found"
        )
      )
    end
  end

  defp validate_entity_isolation(changeset, posting_attrs, accounts_by_id) do
    entity_id = Ecto.Changeset.get_field(changeset, :entity_id)

    invalid_account? =
      Enum.any?(posting_attrs, fn posting_attr ->
        case Map.get(accounts_by_id, posting_value(posting_attr, :account_id)) do
          %{entity_id: ^entity_id} -> false
          nil -> false
          _account -> true
        end
      end)

    if invalid_account? do
      Ecto.Changeset.add_error(
        changeset,
        :postings,
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_transaction_cross_entity_account"
        )
      )
    else
      changeset
    end
  end

  defp validate_zero_sum(changeset, posting_attrs, accounts_by_id) do
    totals_by_currency =
      Enum.reduce_while(posting_attrs, %{}, fn posting_attr, acc ->
        account_id = posting_value(posting_attr, :account_id)

        with %{currency_code: currency_code} <- Map.get(accounts_by_id, account_id),
             {:ok, amount} <- posting_decimal(posting_attr) do
          total = Map.get(acc, currency_code, Decimal.new("0"))
          {:cont, Map.put(acc, currency_code, Decimal.add(total, amount))}
        else
          _ -> {:cont, acc}
        end
      end)

    if Enum.all?(totals_by_currency, fn {_currency, total} ->
         Decimal.eq?(total, Decimal.new("0"))
       end) do
      changeset
    else
      Ecto.Changeset.add_error(
        changeset,
        :postings,
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_transaction_unbalanced"
        )
      )
    end
  end

  defp insert_transaction(transaction_changeset, posting_attrs) do
    with {:ok, transaction} <- Repo.insert(transaction_changeset),
         {:ok, _postings} <- insert_postings(transaction, posting_attrs) do
      {:ok, Repo.preload(transaction, :postings)}
    end
  end

  defp persist_transaction(validated_changeset, posting_attrs, audit_metadata) do
    Repo.transaction(fn ->
      validated_changeset
      |> insert_transaction(posting_attrs)
      |> maybe_log_transaction_created(audit_metadata)
    end)
    |> normalize_repo_result()
  end

  defp insert_postings(transaction, posting_attrs) do
    Enum.reduce_while(posting_attrs, {:ok, []}, fn posting_attr, {:ok, postings} ->
      attrs = %{
        transaction_id: transaction.id,
        account_id: posting_value(posting_attr, :account_id),
        amount: normalize_posting_amount!(posting_attr)
      }

      case Repo.insert(Posting.changeset(%Posting{}, attrs)) do
        {:ok, posting} -> {:cont, {:ok, [posting | postings]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp insert_reversal_transaction(transaction, correlation_id) do
    reversal_attrs = %{
      entity_id: transaction.entity_id,
      date: transaction.date,
      description: "Reversal of #{transaction.description}",
      source_type: :system,
      correlation_id: correlation_id
    }

    posting_attrs =
      Enum.map(transaction.postings, fn posting ->
        %{account_id: posting.account_id, amount: Decimal.negate(posting.amount)}
      end)

    transaction_changeset = Transaction.system_changeset(%Transaction{}, reversal_attrs)

    case validate_transaction_for_insert(transaction_changeset, posting_attrs) do
      {:ok, validated_changeset, _accounts_by_id} ->
        insert_transaction(validated_changeset, posting_attrs)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp persist_void_transaction(transaction, audit_metadata) do
    voided_at = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    correlation_id = Ecto.UUID.generate()

    Repo.transaction(fn ->
      case update_voided_transaction(transaction, voided_at, correlation_id) do
        {:ok, voided} ->
          finalize_void_transaction(transaction, voided, correlation_id, audit_metadata)

        {:error, %Ecto.Changeset{} = changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> normalize_repo_result()
  end

  defp update_voided_transaction(transaction, voided_at, correlation_id) do
    transaction
    |> Transaction.void_changeset(%{voided_at: voided_at, correlation_id: correlation_id})
    |> Repo.update()
  end

  defp finalize_void_transaction(transaction, voided, correlation_id, audit_metadata) do
    case log_transaction_voided(transaction, voided, audit_metadata) do
      :ok ->
        transaction
        |> insert_reversal_transaction(correlation_id)
        |> maybe_finish_void_transaction(voided, audit_metadata)

      {:error, %Ecto.Changeset{} = changeset} ->
        Repo.rollback(changeset)
    end
  end

  defp log_transaction_created(transaction, audit_metadata) do
    Audit.log_event(%{
      entity_type: @transaction_entity_type,
      entity_id: transaction.id,
      action: "created",
      actor: audit_metadata.actor,
      channel: audit_metadata.channel,
      before: nil,
      after: transaction_snapshot(transaction)
    })
  end

  defp log_transaction_voided(before_transaction, after_transaction, audit_metadata) do
    Audit.log_event(%{
      entity_type: @transaction_entity_type,
      entity_id: after_transaction.id,
      action: "voided",
      actor: audit_metadata.actor,
      channel: audit_metadata.channel,
      before: transaction_snapshot(before_transaction),
      after: transaction_snapshot(Repo.preload(after_transaction, :postings))
    })
  end

  defp maybe_filter_balance_as_of_date(query, nil), do: query

  defp maybe_filter_balance_as_of_date(query, %Date{} = as_of_date) do
    where(query, [_posting, _account, transaction], transaction.date <= ^as_of_date)
  end

  defp posting_value(posting_attr, key) when is_map(posting_attr) do
    Map.get(posting_attr, key) || Map.get(posting_attr, Atom.to_string(key))
  end

  defp posting_decimal(posting_attr) do
    case Decimal.cast(posting_value(posting_attr, :amount)) do
      {:ok, amount} -> {:ok, amount}
      :error -> :error
    end
  end

  defp normalize_posting_amount!(posting_attr) do
    case posting_decimal(posting_attr) do
      {:ok, amount} -> amount
      :error -> raise ArgumentError, "invalid posting amount"
    end
  end

  defp maybe_log_transaction_created({:ok, transaction}, audit_metadata) do
    case log_transaction_created(transaction, audit_metadata) do
      :ok -> transaction
      {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
    end
  end

  defp maybe_log_transaction_created({:error, %Ecto.Changeset{} = changeset}, _audit_metadata) do
    Repo.rollback(changeset)
  end

  defp maybe_finish_void_transaction({:ok, reversal}, voided, audit_metadata) do
    case log_transaction_created(reversal, audit_metadata) do
      :ok -> %{voided: voided, reversal: reversal}
      {:error, %Ecto.Changeset{} = changeset} -> Repo.rollback(changeset)
    end
  end

  defp maybe_finish_void_transaction(
         {:error, %Ecto.Changeset{} = changeset},
         _voided,
         _audit_metadata
       ) do
    Repo.rollback(changeset)
  end

  defp normalize_repo_result({:ok, result}), do: {:ok, result}
  defp normalize_repo_result({:error, %Ecto.Changeset{} = changeset}), do: {:error, changeset}

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
