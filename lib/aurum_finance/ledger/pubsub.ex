defmodule AurumFinance.Ledger.PubSub do
  @moduledoc """
  PubSub helpers for ledger transaction write notifications.

  Notifications are state-change signals only. Subscribers should re-read
  persisted state after receiving them.

  The topic is intentionally ledger-owned and reporting-agnostic. It carries
  only the minimum projection trigger data needed by downstream consumers:

  - the persisted transaction id
  - the entity scope
  - the transaction business date as `from_date`
  - the affected posting account ids, deduplicated

  The module only broadcasts after successful final ledger writes. Validation
  errors, preview flows, and other non-persisted paths must not use these
  helpers.
  """

  alias AurumFinance.Ledger.Transaction

  @transaction_topic "ledger:transactions"

  @type transaction_event :: :transaction_created | :transaction_voided

  @type transaction_notification :: %{
          transaction_id: Ecto.UUID.t(),
          entity_id: Ecto.UUID.t(),
          from_date: Date.t(),
          account_ids: [Ecto.UUID.t()]
        }

  @doc """
  Subscribes the caller to ledger transaction write notifications.

  ## Examples

      iex> AurumFinance.Ledger.PubSub.subscribe_transactions()
      :ok
  """
  @spec subscribe_transactions() :: :ok | {:error, term()}
  def subscribe_transactions do
    Phoenix.PubSub.subscribe(AurumFinance.PubSub, @transaction_topic)
  end

  @doc """
  Broadcasts that a transaction was created successfully.

  The payload always reflects persisted ledger state and uses the transaction
  business date as the downstream rebuild `from_date`.

  ## Examples

      iex> transaction = %AurumFinance.Ledger.Transaction{
      ...>   id: Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate(),
      ...>   date: ~D[2026-03-19],
      ...>   postings: [
      ...>     %AurumFinance.Ledger.Posting{account_id: Ecto.UUID.generate(), amount: Decimal.new("-10.0000")},
      ...>     %AurumFinance.Ledger.Posting{account_id: Ecto.UUID.generate(), amount: Decimal.new("10.0000")}
      ...>   ]
      ...> }
      iex> AurumFinance.Ledger.PubSub.broadcast_transaction_created(transaction)
      :ok
  """
  @spec broadcast_transaction_created(Transaction.t()) :: :ok
  def broadcast_transaction_created(%Transaction{} = transaction) do
    broadcast(:transaction_created, transaction_notification(transaction))
  end

  @doc """
  Broadcasts that a transaction void flow completed successfully.

  The event is emitted from the original voided transaction rather than the
  reversal transaction because downstream projections only need the original
  business date and affected accounts to rebuild correctly.

  ## Examples

      iex> voided = %AurumFinance.Ledger.Transaction{
      ...>   id: Ecto.UUID.generate(),
      ...>   entity_id: Ecto.UUID.generate(),
      ...>   date: ~D[2026-03-19],
      ...>   postings: [
      ...>     %AurumFinance.Ledger.Posting{account_id: Ecto.UUID.generate(), amount: Decimal.new("-10.0000")},
      ...>     %AurumFinance.Ledger.Posting{account_id: Ecto.UUID.generate(), amount: Decimal.new("10.0000")}
      ...>   ]
      ...> }
      iex> AurumFinance.Ledger.PubSub.broadcast_transaction_voided(voided)
      :ok
  """
  @spec broadcast_transaction_voided(Transaction.t()) :: :ok
  def broadcast_transaction_voided(%Transaction{} = transaction) do
    broadcast(:transaction_voided, transaction_notification(transaction))
  end

  defp transaction_notification(%Transaction{} = transaction) do
    %{
      transaction_id: transaction.id,
      entity_id: transaction.entity_id,
      from_date: transaction.date,
      account_ids: affected_account_ids(transaction)
    }
  end

  defp affected_account_ids(%Transaction{postings: postings}) do
    postings
    |> Enum.map(& &1.account_id)
    |> Enum.uniq()
  end

  defp broadcast(event, notification) do
    AurumFinance.PubSub
    |> Phoenix.PubSub.broadcast(@transaction_topic, {event, notification})
    |> normalize_broadcast_result()
  end

  defp normalize_broadcast_result(:ok), do: :ok
  defp normalize_broadcast_result({:error, _reason}), do: :ok
end
