defmodule AurumFinance.Reporting.DailyBalanceSnapshot do
  @moduledoc """
  Reporting-side daily closing balance projection row.

  This schema owns the persisted shape of `daily_balance_snapshots`. Runtime
  rebuild semantics belong to the reporting projection engine and context
  contracts, not to this schema.

  `entity_id` is persisted denormalized reporting data so entity-scoped reads do
  not need to join back through accounts. It should be derived internally from
  the resolved account, not trusted from external caller input.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AurumFinance.Entities.Entity
  alias AurumFinance.Ledger.Account

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  @required [
    :account_id,
    :entity_id,
    :snapshot_date,
    :closing_balance,
    :daily_delta,
    :computed_at,
    :projection_version
  ]
  @optional []

  schema "daily_balance_snapshots" do
    field :snapshot_date, :date
    field :closing_balance, :decimal
    field :daily_delta, :decimal
    field :computed_at, :utc_datetime_usec
    field :projection_version, :integer

    belongs_to :account, Account
    belongs_to :entity, Entity

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds the snapshot changeset for persisted reporting rows.

  In normal flow, callers should prefer the projection-version module helpers so
  derived fields such as `entity_id` and `projection_version` are owned by the
  projection layer instead of external input.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Reporting.DailyBalanceSnapshot.changeset(
      ...>     %AurumFinance.Reporting.DailyBalanceSnapshot{},
      ...>     %{
      ...>       account_id: Ecto.UUID.generate(),
      ...>       entity_id: Ecto.UUID.generate(),
      ...>       snapshot_date: ~D[2026-03-10],
      ...>       closing_balance: Decimal.new("100.0000"),
      ...>       daily_delta: Decimal.new("5.0000"),
      ...>       computed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond),
      ...>       projection_version: 1
      ...>     }
      ...>   )
      iex> changeset.valid?
      true
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> foreign_key_constraint(:account_id)
    |> foreign_key_constraint(:entity_id)
    |> unique_constraint(:account_id,
      name: :daily_balance_snapshots_account_id_snapshot_date_index
    )
  end
end
