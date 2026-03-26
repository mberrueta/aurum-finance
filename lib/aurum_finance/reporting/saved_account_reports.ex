defmodule AurumFinance.Reporting.SavedAccountReports do
  @moduledoc """
  Persistence and preview APIs for saved account report definitions.

  The saved definition is global application state. Report outputs remain
  derived from the existing reporting and FX read models at render time.
  """

  import Ecto.Query, warn: false

  alias AurumFinance.Fx
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Repo
  alias AurumFinance.Reporting
  alias AurumFinance.Reporting.SavedAccountReport

  @type list_opt ::
          {:account_id, Ecto.UUID.t()}
          | {:entity_id, Ecto.UUID.t()}

  @doc """
  Lists saved account report definitions.

  Results are preloaded with their account/entity data and sorted by the
  derived display label so the dashboard renders deterministically.

  ## Examples

      iex> AurumFinance.Reporting.SavedAccountReports.list_saved_account_reports()
      []
  """
  @spec list_saved_account_reports([list_opt()]) :: [SavedAccountReport.t()]
  def list_saved_account_reports(opts \\ []) do
    opts
    |> list_saved_account_reports_query()
    |> Repo.all()
    |> Repo.preload(account: :entity)
    |> Enum.sort_by(&display_label/1)
  end

  @doc """
  Returns one saved account report definition by id or nil when missing.

  ## Examples

      iex> AurumFinance.Reporting.SavedAccountReports.get_saved_account_report(Ecto.UUID.generate())
      nil
  """
  @spec get_saved_account_report(Ecto.UUID.t()) :: SavedAccountReport.t() | nil
  def get_saved_account_report(id) when is_binary(id) do
    SavedAccountReport
    |> Repo.get(id)
    |> maybe_preload_saved_account_report()
  end

  @doc """
  Returns a changeset for saved account report definitions.

  This validates partial conversion input, account existence, and FX
  compatibility for the current or pinned report date.
  """
  @spec change_saved_account_report(SavedAccountReport.t(), map()) :: Ecto.Changeset.t()
  def change_saved_account_report(%SavedAccountReport{} = saved_account_report, attrs \\ %{}) do
    saved_account_report
    |> SavedAccountReport.changeset(attrs)
    |> validate_saved_account_report()
  end

  @doc """
  Creates a saved account report definition.
  """
  @spec create_saved_account_report(map()) ::
          {:ok, SavedAccountReport.t()} | {:error, Ecto.Changeset.t()}
  def create_saved_account_report(attrs) do
    %SavedAccountReport{}
    |> change_saved_account_report(attrs)
    |> Repo.insert()
    |> maybe_preload_write_result()
  end

  @doc """
  Updates one saved account report definition.
  """
  @spec update_saved_account_report(SavedAccountReport.t(), map()) ::
          {:ok, SavedAccountReport.t()} | {:error, Ecto.Changeset.t()}
  def update_saved_account_report(%SavedAccountReport{} = saved_account_report, attrs) do
    saved_account_report
    |> change_saved_account_report(attrs)
    |> Repo.update()
    |> maybe_preload_write_result()
  end

  @doc """
  Deletes one saved account report definition.
  """
  @spec delete_saved_account_report(SavedAccountReport.t()) ::
          {:ok, SavedAccountReport.t()} | {:error, Ecto.Changeset.t()}
  def delete_saved_account_report(%SavedAccountReport{} = saved_account_report) do
    Repo.delete(saved_account_report)
  end

  @doc """
  Returns the derived display label for one saved account report definition.

  ## Examples

      iex> account = %AurumFinance.Ledger.Account{
      ...>   name: "Checking",
      ...>   entity: %AurumFinance.Entities.Entity{name: "Alpha"}
      ...> }
      iex> report = %AurumFinance.Reporting.SavedAccountReport{account: account}
      iex> AurumFinance.Reporting.SavedAccountReports.display_label(report)
      "Alpha · Checking"
  """
  @spec display_label(SavedAccountReport.t()) :: String.t()
  def display_label(%SavedAccountReport{
        account: %Account{entity: %{name: entity_name}, name: account_name}
      }) do
    [entity_name, account_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  def display_label(%SavedAccountReport{account: %Account{name: account_name}}) do
    account_name || fallback_display_label()
  end

  def display_label(%SavedAccountReport{account_id: account_id}) do
    fallback_display_label(account_id)
  end

  @doc """
  Renders one saved account report definition at read time.

  Live definitions use the current date. Pinned definitions use the pinned
  date. Conversion still uses the existing reporting and FX read models.

  ## Examples

      iex> report = %AurumFinance.Reporting.SavedAccountReport{account_id: Ecto.UUID.generate()}
      iex> AurumFinance.Reporting.SavedAccountReports.preview_saved_account_report(report)
      {:error, :account_not_found}
  """
  @spec preview_saved_account_report(SavedAccountReport.t()) ::
          {:ok, map()} | {:error, term()}
  def preview_saved_account_report(%SavedAccountReport{} = saved_account_report) do
    report_date = report_date(saved_account_report)

    saved_account_report
    |> report_options(report_date)
    |> then(&Reporting.account_report(saved_account_report.account_id, &1))
    |> normalize_preview_result(saved_account_report, report_date)
  end

  defp list_saved_account_reports_query(opts) do
    SavedAccountReport
    |> filter_query(opts)
    |> order_by([report], asc: report.inserted_at, asc: report.id)
  end

  defp filter_query(query, []), do: query

  defp filter_query(query, [{:account_id, account_id} | rest]) do
    query
    |> where([report], report.account_id == ^account_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [{:entity_id, entity_id} | rest]) do
    query
    |> join(:inner, [report], account in assoc(report, :account))
    |> where([_report, account], account.entity_id == ^entity_id)
    |> filter_query(rest)
  end

  defp filter_query(query, [_unknown | rest]), do: filter_query(query, rest)

  defp validate_saved_account_report(%{valid?: false} = changeset), do: changeset

  defp validate_saved_account_report(changeset) do
    with %Account{} = account <- fetch_account(changeset),
         :ok <- validate_conversion_account(changeset, account) do
      changeset
    else
      nil -> add_error(changeset, :account_id, error_message(:invalid))
      {:error, changeset} -> changeset
    end
  end

  defp fetch_account(changeset) do
    changeset
    |> Ecto.Changeset.get_field(:account_id)
    |> case do
      nil -> nil
      account_id -> Repo.get(Account, account_id)
    end
  end

  defp validate_conversion_account(changeset, %Account{} = account) do
    case Ecto.Changeset.get_field(changeset, :convert) do
      true -> validate_converted_account(changeset, account)
      _ -> :ok
    end
  end

  defp validate_converted_account(changeset, %Account{} = account) do
    target_currency_code = Ecto.Changeset.get_field(changeset, :target_currency_code)
    fx_series_id = Ecto.Changeset.get_field(changeset, :fx_series_id)
    report_date = Ecto.Changeset.get_field(changeset, :pinned_as_of_date) || Date.utc_today()

    with false <- target_currency_code == account.currency_code,
         true <-
           compatible_fx_series?(
             account.currency_code,
             target_currency_code,
             report_date,
             fx_series_id
           ) do
      :ok
    else
      true ->
        {:error, add_error(changeset, :target_currency_code, same_currency_error())}

      false ->
        {:error, add_error(changeset, :fx_series_id, error_message(:invalid))}
    end
  end

  defp compatible_fx_series?(
         account_currency_code,
         target_currency_code,
         report_date,
         fx_series_id
       )
       when is_binary(account_currency_code) and is_binary(target_currency_code) and
              is_binary(fx_series_id) do
    Fx.list_compatible_fx_series(account_currency_code, target_currency_code, report_date)
    |> Enum.any?(&(&1.id == fx_series_id))
  end

  defp compatible_fx_series?(_, _, _, _), do: false

  defp report_options(%SavedAccountReport{} = saved_account_report, report_date) do
    opts = [as_of_date: report_date]

    if SavedAccountReport.converted?(saved_account_report) do
      opts ++
        [
          target_currency_code: saved_account_report.target_currency_code,
          fx_series_id: saved_account_report.fx_series_id
        ]
    else
      opts
    end
  end

  defp report_date(%SavedAccountReport{pinned_as_of_date: %Date{} = pinned_date}), do: pinned_date
  defp report_date(%SavedAccountReport{}), do: Date.utc_today()

  defp normalize_preview_result({:ok, report}, saved_account_report, report_date) do
    {:ok,
     %{
       report: report,
       live?: SavedAccountReport.live?(saved_account_report),
       effective_as_of_date: report_date
     }}
  end

  defp normalize_preview_result(
         {:error, %Ecto.Changeset{} = changeset},
         _saved_account_report,
         _
       ),
       do: {:error, changeset}

  defp normalize_preview_result({:error, reason}, _saved_account_report, _report_date),
    do: {:error, reason}

  defp maybe_preload_saved_account_report(nil), do: nil

  defp maybe_preload_saved_account_report(%SavedAccountReport{} = report) do
    Repo.preload(report, account: :entity)
  end

  defp maybe_preload_write_result({:ok, %SavedAccountReport{} = report}) do
    {:ok, Repo.preload(report, account: :entity)}
  end

  defp maybe_preload_write_result({:error, %Ecto.Changeset{} = changeset}),
    do: {:error, changeset}

  defp maybe_preload_write_result({:error, reason}), do: {:error, reason}

  defp add_error(changeset, field, message) do
    Ecto.Changeset.add_error(changeset, field, message)
  end

  defp error_message(:invalid),
    do: Gettext.dgettext(AurumFinance.Gettext, "errors", "is invalid")

  defp same_currency_error do
    Gettext.dgettext(AurumFinance.Gettext, "reports", "account_report_same_currency_error")
  end

  defp fallback_display_label(account_id \\ nil) do
    _ = account_id
    Gettext.dgettext(AurumFinance.Gettext, "reports", "saved_account_report_label_fallback")
  end
end
