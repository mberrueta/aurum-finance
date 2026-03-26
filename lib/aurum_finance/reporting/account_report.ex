defmodule AurumFinance.Reporting.AccountReport do
  @moduledoc """
  Single-account reporting read model with optional FX conversion.

  The report is intentionally narrow:

  - it reads one account only
  - it uses the latest daily balance snapshot on or before `as_of_date`
  - conversion is opt-in and request-time only
  - FX series must be explicitly selected; there is no automatic series choice

  Missing FX rates do not fail the report. In that case the native amount still
  returns and `conversion_status` becomes `:unavailable`.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Fx
  alias AurumFinance.Fx.FxSeries
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Reporting.AccountReportParams
  alias AurumFinance.Reporting.DailyBalanceSnapshot
  alias AurumFinance.Repo

  @no_fx_rate_message "No FX rate found within 4 days"
  @no_native_amount_message "Native balance is unavailable for conversion"

  @type option ::
          {:as_of_date, Date.t()}
          | {:target_currency_code, String.t()}
          | {:fx_series_id, Ecto.UUID.t() | String.t()}

  @doc """
  Returns one account report as of `as_of_date`, with optional FX conversion.

  When `target_currency_code` and `fx_series_id` are both present, the selected
  series must be compatible with the account currency, target currency, and
  report date. Invalid selections return a changeset suitable for form errors.

  Missing rate data is non-fatal. The report still returns the native amount
  with `conversion_status: :unavailable` and an explanatory message.

  ## Examples

      iex> AurumFinance.Reporting.AccountReport.get_report(Ecto.UUID.generate(), as_of_date: ~D[2026-03-20])
      {:error, :account_not_found}
  """
  @spec get_report(Ecto.UUID.t(), [option()]) ::
          {:ok, map()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def get_report(account_id, opts \\ [])

  def get_report(account_id, opts) when is_binary(account_id) and is_list(opts) do
    with {:ok, params} <- validate_params(opts),
         {:ok, account} <- fetch_account(account_id),
         {:ok, report} <- build_native_report(account, params) do
      maybe_apply_conversion(report, params)
    end
  end

  def get_report(account_id, _opts), do: {:error, {:invalid_account_id, account_id}}

  defp validate_params(opts) do
    AccountReportParams.changeset(%AccountReportParams{}, Map.new(opts))
    |> validate_params_result()
  end

  defp validate_params_result(%{valid?: true} = changeset), do: {:ok, changeset}
  defp validate_params_result(changeset), do: {:error, changeset}

  defp fetch_account(account_id) do
    Repo.get(Account, account_id)
    |> fetch_account_result()
  end

  defp fetch_account_result(%Account{} = account), do: {:ok, account}
  defp fetch_account_result(nil), do: {:error, :account_not_found}

  defp build_native_report(%Account{} = account, params) do
    as_of_date = Ecto.Changeset.get_field(params, :as_of_date)
    snapshot = latest_snapshot(account.id, as_of_date)
    native_amount = native_amount(account, snapshot)

    {:ok,
     %{
       account_id: account.id,
       account_name: account.name,
       account_type: account.account_type,
       as_of_date: as_of_date,
       native_currency_code: account.currency_code,
       native_amount: native_amount,
       ledger_balance: snapshot && snapshot.snapshot_closing_balance,
       snapshot_date_used: snapshot && snapshot.snapshot_date,
       snapshot: snapshot_display(snapshot),
       conversion_status: :not_requested,
       conversion_message: nil,
       target_currency_code: nil,
       converted_amount: nil,
       converted_currency_code: nil,
       fx_series_id: nil,
       fx_series_slug: nil,
       fx_series_name: nil,
       fx_series_base_currency_code: nil,
       fx_series_quote_currency_code: nil,
       fx_series_inverted?: nil,
       fx_rate_effective_date: nil,
       fx_rate_value: nil
     }}
  end

  defp maybe_apply_conversion(report, params) do
    maybe_apply_conversion(
      report,
      Ecto.Changeset.get_field(params, :target_currency_code),
      Ecto.Changeset.get_field(params, :fx_series_id)
    )
  end

  defp maybe_apply_conversion(report, nil, nil), do: {:ok, report}

  defp maybe_apply_conversion(report, target_currency_code, fx_series_id) do
    apply_conversion(report, target_currency_code, fx_series_id)
  end

  defp apply_conversion(report, target_currency_code, fx_series_id) do
    selected_fx_series =
      compatible_fx_series(
        report.native_currency_code,
        report.as_of_date,
        target_currency_code,
        fx_series_id
      )

    conversion_result(selected_fx_series, report, target_currency_code, fx_series_id)
  end

  defp compatible_fx_series(account_currency_code, as_of_date, target_currency_code, fx_series_id) do
    Fx.list_compatible_fx_series(account_currency_code, target_currency_code, as_of_date)
    |> Enum.find(&(&1.id == fx_series_id))
  end

  defp conversion_result(%FxSeries{} = series, report, target_currency_code, _fx_series_id) do
    apply_rate(report, series, target_currency_code)
  end

  defp conversion_result(nil, report, target_currency_code, fx_series_id) do
    {:error, invalid_fx_series_changeset(report.as_of_date, target_currency_code, fx_series_id)}
  end

  defp invalid_fx_series_changeset(as_of_date, target_currency_code, fx_series_id) do
    %AccountReportParams{}
    |> AccountReportParams.changeset(%{
      as_of_date: as_of_date,
      target_currency_code: target_currency_code,
      fx_series_id: fx_series_id
    })
    |> Ecto.Changeset.add_error(
      :fx_series_id,
      Gettext.dgettext(AurumFinance.Gettext, "errors", "is invalid")
    )
  end

  defp apply_rate(
         %{native_amount: %Decimal{} = native_amount} = report,
         %FxSeries{} = series,
         target_currency_code
       ) do
    Fx.lookup_fx_rate(series.id, report.as_of_date, invert: series.inverted?)
    |> rate_lookup_result(native_amount, report, series, target_currency_code)
  end

  defp apply_rate(%{native_amount: nil} = report, %FxSeries{} = series, target_currency_code) do
    {:ok, unavailable_conversion(report, series, target_currency_code, @no_native_amount_message)}
  end

  defp rate_lookup_result(
         {:ok, rate},
         native_amount,
         report,
         %FxSeries{} = series,
         target_currency_code
       ) do
    {:ok,
     report
     |> Map.put(:conversion_status, :converted)
     |> Map.put(:conversion_message, nil)
     |> Map.put(:target_currency_code, target_currency_code)
     |> Map.put(:converted_currency_code, target_currency_code)
     |> Map.put(:converted_amount, Decimal.mult(native_amount, rate.rate_value))
     |> Map.put(:fx_series_id, series.id)
     |> Map.put(:fx_series_slug, series.slug)
     |> Map.put(:fx_series_name, series.name)
     |> Map.put(:fx_series_base_currency_code, series.base_currency_code)
     |> Map.put(:fx_series_quote_currency_code, series.quote_currency_code)
     |> Map.put(:fx_series_inverted?, series.inverted?)
     |> Map.put(:fx_rate_effective_date, rate.effective_date)
     |> Map.put(:fx_rate_value, rate.rate_value)}
  end

  defp rate_lookup_result(
         {:error, :rate_not_found},
         _native_amount,
         report,
         %FxSeries{} = series,
         target_currency_code
       ) do
    {:ok, unavailable_conversion(report, series, target_currency_code, @no_fx_rate_message)}
  end

  defp unavailable_conversion(report, %FxSeries{} = series, target_currency_code, message) do
    report
    |> Map.put(:conversion_status, :unavailable)
    |> Map.put(:conversion_message, message)
    |> Map.put(:target_currency_code, target_currency_code)
    |> Map.put(:converted_currency_code, target_currency_code)
    |> Map.put(:fx_series_id, series.id)
    |> Map.put(:fx_series_slug, series.slug)
    |> Map.put(:fx_series_name, series.name)
    |> Map.put(:fx_series_base_currency_code, series.base_currency_code)
    |> Map.put(:fx_series_quote_currency_code, series.quote_currency_code)
    |> Map.put(:fx_series_inverted?, series.inverted?)
  end

  defp latest_snapshot(account_id, %Date{} = as_of_date) do
    DailyBalanceSnapshot
    |> where([snapshot], snapshot.account_id == ^account_id)
    |> where([snapshot], snapshot.snapshot_date <= ^as_of_date)
    |> order_by([snapshot],
      desc: snapshot.snapshot_date,
      desc: snapshot.computed_at,
      desc: snapshot.id
    )
    |> limit(1)
    |> select([snapshot], %{
      snapshot_date: snapshot.snapshot_date,
      snapshot_computed_at: snapshot.computed_at,
      snapshot_closing_balance: snapshot.closing_balance,
      snapshot_daily_delta: snapshot.daily_delta,
      snapshot_projection_version: snapshot.projection_version
    })
    |> Repo.one()
  end

  defp native_amount(%Account{account_type: :liability}, %{snapshot_closing_balance: balance})
       when is_struct(balance, Decimal),
       do: Decimal.abs(balance)

  defp native_amount(%Account{}, %{snapshot_closing_balance: balance})
       when is_struct(balance, Decimal),
       do: balance

  defp native_amount(%Account{}, %{snapshot_closing_balance: nil}), do: nil
  defp native_amount(%Account{}, nil), do: nil

  defp snapshot_display(nil), do: nil

  defp snapshot_display(snapshot) do
    %{
      date: snapshot.snapshot_date,
      computed_at: snapshot.snapshot_computed_at,
      closing_balance: snapshot.snapshot_closing_balance,
      daily_delta: snapshot.snapshot_daily_delta,
      projection_version: snapshot.snapshot_projection_version
    }
  end
end
