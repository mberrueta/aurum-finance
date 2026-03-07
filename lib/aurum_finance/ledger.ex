defmodule AurumFinance.Ledger do
  @moduledoc """
  The Ledger context, responsible for canonical account records and derived balances.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Audit
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Repo

  @entity_type "account"
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
      |> require_entity_scope!()
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
      |> require_entity_scope!()
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
  Returns the derived account balance.

  Posting-backed balance computation is deferred until the postings model exists.

  ## Examples

      iex> AurumFinance.Ledger.get_account_balance(Ecto.UUID.generate())
      %{}

      iex> AurumFinance.Ledger.get_account_balance(Ecto.UUID.generate(), as_of_date: ~D[2026-03-07])
      %{}
  """
  @spec get_account_balance(Ecto.UUID.t(), [balance_opt()]) :: map()
  def get_account_balance(_account_id, _opts \\ []), do: %{}

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

  defp require_entity_scope!(opts) do
    case Keyword.fetch(opts, :entity_id) do
      {:ok, entity_id} when not is_nil(entity_id) -> opts
      _ -> raise ArgumentError, "list_accounts/1 requires :entity_id"
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

  defp filter_query(query, [_unknown_filter | rest]) do
    filter_query(query, rest)
  end
end
