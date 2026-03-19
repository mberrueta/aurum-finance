defmodule AurumFinanceWeb.ReportsLive do
  use AurumFinanceWeb, :live_view

  import Ecto.Changeset

  alias AurumFinance.Entities
  alias AurumFinance.Ledger
  alias AurumFinance.Ledger.Account
  alias AurumFinance.Reporting

  @rebuild_form_types %{account_id: :string, from_date: :date}
  @from_date_presets [:all, :last_month, :current_year, :one_year_ago]

  def mount(_params, _session, socket) do
    entities = Entities.list_entities()
    account_options = rebuild_account_options(entities)
    entity = mock_entity()
    net_worth_series = [120_500, 121_020, 119_800, 118_900, 119_150, 117_980, 118_160, 118_420]

    {:ok,
     socket
     |> assign(:active_nav, :reports)
     |> assign(:page_title, dgettext("reports", "page_title"))
     |> assign(:entity, entity)
     |> assign(:rebuild_account_options, account_options)
     |> assign(:net_worth_series, net_worth_series)
     |> assign(:cashflow, mock_cashflow())
     |> assign_rebuild_form(%{})}
  end

  def handle_event("validate_rebuild", %{"snapshot_rebuild" => rebuild_params}, socket) do
    {:noreply,
     socket
     |> assign_rebuild_form(rebuild_params, action: :validate)}
  end

  def handle_event("enqueue_rebuild", %{"snapshot_rebuild" => rebuild_params}, socket) do
    rebuild_params
    |> rebuild_changeset()
    |> Map.put(:action, :insert)
    |> enqueue_rebuild(socket)
  end

  def handle_event("apply_from_date_preset", %{"preset" => preset}, socket) do
    rebuild_params =
      socket.assigns.rebuild_form.params
      |> normalize_rebuild_params()
      |> Map.put("from_date", from_date_preset_value(preset))

    {:noreply, assign_rebuild_form(socket, rebuild_params, action: :validate)}
  end

  defp enqueue_rebuild(%Ecto.Changeset{valid?: false} = changeset, socket) do
    {:noreply,
     socket
     |> assign(:rebuild_form, to_form(changeset, as: :snapshot_rebuild))
     |> put_flash(:error, dgettext("reports", "rebuild_validation_error"))}
  end

  defp enqueue_rebuild(%Ecto.Changeset{valid?: true} = changeset, socket) do
    account_id = get_field(changeset, :account_id)
    from_date = get_field(changeset, :from_date)

    case Reporting.enqueue_daily_balance_snapshot_refresh(account_id, from_date) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> assign_rebuild_form(%{})
         |> put_flash(:info, dgettext("reports", "rebuild_success"))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:rebuild_form, to_form(changeset, as: :snapshot_rebuild))
         |> put_flash(:error, dgettext("reports", "rebuild_error"))}
    end
  end

  defp assign_rebuild_form(socket, params, opts \\ []) do
    changeset =
      params
      |> normalize_rebuild_params()
      |> rebuild_changeset()
      |> maybe_put_action(opts[:action])

    assign(socket, :rebuild_form, to_form(changeset, as: :snapshot_rebuild))
  end

  defp rebuild_changeset(params) do
    {%{}, @rebuild_form_types}
    |> cast(params, Map.keys(@rebuild_form_types))
    |> validate_required([:account_id],
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
    |> update_change(:account_id, &String.trim/1)
    |> validate_length(:account_id,
      min: 1,
      message: Gettext.dgettext(AurumFinance.Gettext, "errors", "error_field_required")
    )
  end

  defp normalize_rebuild_params(%{} = params) do
    params
    |> Map.update("account_id", "", &String.trim/1)
    |> Map.update("from_date", "", &normalize_from_date_param/1)
  end

  defp normalize_from_date_param(nil), do: ""
  defp normalize_from_date_param(%Date{} = date), do: Date.to_iso8601(date)
  defp normalize_from_date_param(value), do: value

  defp maybe_put_action(changeset, nil), do: changeset
  defp maybe_put_action(changeset, action), do: Map.put(changeset, :action, action)

  defp rebuild_account_options([]), do: account_prompt_option()

  defp rebuild_account_options(entities) do
    entity_names_by_id = Map.new(entities, &{&1.id, &1.name})
    entity_ids = Enum.map(entities, & &1.id)

    options =
      entity_ids
      |> Ledger.list_accounts_for_entities()
      |> Enum.sort_by(fn %Account{} = account ->
        {Map.get(entity_names_by_id, account.entity_id, ""), account.name}
      end)
      |> Enum.map(fn %Account{} = account ->
        entity_name = Map.fetch!(entity_names_by_id, account.entity_id)
        {"#{entity_name} / #{account.name}", account.id}
      end)

    account_prompt_option() ++ options
  end

  defp account_prompt_option do
    [{dgettext("reports", "rebuild_account_prompt"), ""}]
  end

  defp from_date_preset_options do
    Enum.map(@from_date_presets, fn preset ->
      {from_date_preset_label(preset), Atom.to_string(preset)}
    end)
  end

  defp from_date_preset_label(:all), do: dgettext("reports", "rebuild_from_date_preset_all")

  defp from_date_preset_label(:last_month),
    do: dgettext("reports", "rebuild_from_date_preset_last_month")

  defp from_date_preset_label(:current_year),
    do: dgettext("reports", "rebuild_from_date_preset_current_year")

  defp from_date_preset_label(:one_year_ago),
    do: dgettext("reports", "rebuild_from_date_preset_one_year_ago")

  defp from_date_preset_value(preset) when preset in ["", "all"], do: ""

  defp from_date_preset_value("last_month") do
    Date.utc_today()
    |> Date.beginning_of_month()
    |> Date.add(-1)
    |> Date.beginning_of_month()
    |> Date.to_iso8601()
  end

  defp from_date_preset_value("current_year") do
    today = Date.utc_today()

    %{today | month: 1, day: 1}
    |> Date.to_iso8601()
  end

  defp from_date_preset_value("one_year_ago") do
    Date.utc_today()
    |> Date.add(-365)
    |> Date.to_iso8601()
  end

  defp from_date_preset_value(_preset), do: ""

  defp pct_label(v) when v > 0, do: "+" <> :erlang.float_to_binary(v * 1.0, decimals: 1) <> "%"
  defp pct_label(v), do: :erlang.float_to_binary(v * 1.0, decimals: 1) <> "%"

  defp mock_cashflow do
    [
      %{category: dgettext("reports", "cashflow_income"), value: 4_200.0},
      %{category: dgettext("reports", "cashflow_housing"), value: -1_500.0},
      %{category: dgettext("reports", "cashflow_food"), value: -780.0},
      %{category: dgettext("reports", "cashflow_transport"), value: -260.0},
      %{category: dgettext("reports", "cashflow_other"), value: -400.0}
    ]
  end

  defp mock_entity do
    %{
      name: dgettext("reports", "mock_entity_name"),
      holdings: [
        %{
          symbol: "QQQD",
          name: dgettext("reports", "holding_name_qqqd"),
          qty: 83,
          price: 31.84,
          currency: "USD",
          change_pct_7d: -1.4
        },
        %{
          symbol: "VT",
          name: dgettext("reports", "holding_name_vt"),
          qty: 120,
          price: 103.22,
          currency: "USD",
          change_pct_7d: 0.9
        },
        %{
          symbol: "BOVA11",
          name: dgettext("reports", "holding_name_bova11"),
          qty: 55,
          price: 111.90,
          currency: "BRL",
          change_pct_7d: 1.2
        }
      ]
    }
  end
end
