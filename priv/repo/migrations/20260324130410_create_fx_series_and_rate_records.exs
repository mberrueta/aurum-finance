defmodule AurumFinance.Repo.Migrations.CreateFxSeriesAndRateRecords do
  use Ecto.Migration

  def up do
    create table(:fx_series, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :base_currency_code, :string, size: 3, null: false
      add :quote_currency_code, :string, size: 3, null: false
      add :from_date, :date, null: false
      add :to_date, :date
      add :source_kind, :string, null: false
      add :provider_module, :string
      add :sync_status, :string, null: false, default: "active"
      add :sync_message, :text
      add :last_sync_attempted_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fx_series, [:slug])

    create index(:fx_series, [:base_currency_code, :quote_currency_code])

    create table(:fx_rate_records, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :fx_series_id, references(:fx_series, type: :binary_id, on_delete: :nothing),
        null: false

      add :effective_date, :date, null: false
      add :rate_value, :decimal, precision: 24, scale: 12, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:fx_rate_records, [:fx_series_id, :effective_date])
    create index(:fx_rate_records, [:effective_date])

    create table(:saved_account_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false

      add :target_currency_code, :string, size: 3

      add :fx_series_id, references(:fx_series, type: :binary_id, on_delete: :nilify_all)

      add :pinned_as_of_date, :date

      timestamps(type: :utc_datetime_usec)
    end

    create index(:saved_account_reports, [:account_id])
    create index(:saved_account_reports, [:fx_series_id])
    create index(:saved_account_reports, [:pinned_as_of_date])
  end

  def down do
    drop index(:saved_account_reports, [:pinned_as_of_date])
    drop index(:saved_account_reports, [:fx_series_id])
    drop index(:saved_account_reports, [:account_id])
    drop table(:saved_account_reports)

    drop index(:fx_rate_records, [:effective_date])
    drop unique_index(:fx_rate_records, [:fx_series_id, :effective_date])
    drop table(:fx_rate_records)

    drop index(:fx_series, [:base_currency_code, :quote_currency_code])
    drop unique_index(:fx_series, [:slug])
    drop table(:fx_series)
  end
end
