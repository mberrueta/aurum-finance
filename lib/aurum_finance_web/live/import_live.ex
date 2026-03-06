defmodule AurumFinanceWeb.ImportLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.ImportComponents

  @steps ["Upload", "Parse", "Normalize", "Deduplicate", "Preview", "Commit"]

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:active_nav, :import)
     |> assign(:page_title, dgettext("import", "page_title"))
     |> assign(:active_step, 4)
     |> assign(:preview_rows, mock_preview_rows())}
  end

  def handle_event("set_step", %{"step" => step}, socket) do
    {:noreply, assign(socket, :active_step, String.to_integer(step))}
  end

  def handle_event("prev_step", _, socket) do
    {:noreply, assign(socket, :active_step, max(0, socket.assigns.active_step - 1))}
  end

  def handle_event("next_step", _, socket) do
    {:noreply, assign(socket, :active_step, min(5, socket.assigns.active_step + 1))}
  end

  def render(assigns) do
    assigns = assign(assigns, :steps, Enum.with_index(@steps))

    ~H"""
    <div>
      <.page_header title={dgettext("import", "page_title")}>
        <:subtitle>{dgettext("import", "page_subtitle")}</:subtitle>
        <:actions>
          <button class="au-btn" phx-click="prev_step">{dgettext("import", "btn_prev")}</button>
          <button class="au-btn au-btn-primary" phx-click="next_step">
            {dgettext("import", "btn_next")}
          </button>
        </:actions>
      </.page_header>

      <%!-- Pipeline wizard card --%>
      <.au_card>
        <:header>
          <span>{dgettext("import", "section_pipeline")}</span>
          <.badge variant={:purple}>{dgettext("import", "badge_mock_wizard")}</.badge>
        </:header>

        <div class="au-steps">
          <.import_step
            :for={{label, idx} <- @steps}
            label={label}
            index={idx}
            active_step={@active_step}
          />
        </div>

        <div class="au-hr"></div>

        <%= if @active_step == 4 do %>
          <table class="au-table">
            <thead>
              <tr>
                <th>{dgettext("import", "col_date")}</th>
                <th>{dgettext("import", "col_description")}</th>
                <th>{dgettext("import", "col_amount")}</th>
                <th>{dgettext("import", "col_currency")}</th>
                <th>{dgettext("import", "col_status")}</th>
                <th>{dgettext("import", "col_hint")}</th>
              </tr>
            </thead>
            <tbody>
              <.preview_row :for={row <- @preview_rows} row={row} />
            </tbody>
          </table>
          <div class="au-hr"></div>
          <div class="flex gap-[10px] flex-wrap">
            <button class="au-btn au-btn-primary" disabled>
              {dgettext("import", "btn_accept_all")}
            </button>
            <button class="au-btn" disabled>
              {dgettext("import", "btn_skip_dupes")}
            </button>
          </div>
        <% else %>
          <div class="au-empty">{stage_placeholder(@active_step)}</div>
        <% end %>
      </.au_card>

      <%!-- Bottom info cards --%>
      <div class="grid grid-cols-2 gap-[14px] mt-[14px]">
        <.au_card>
          <:header>
            <span>{dgettext("import", "section_design_note")}</span>
            <.badge>{dgettext("import", "badge_facts_overlays")}</.badge>
          </:header>

          <p class="text-[13px] text-white/68 mt-[10px] leading-relaxed">
            {dgettext("import", "design_note_text")}
          </p>
        </.au_card>

        <.au_card>
          <:header>
            <span>{dgettext("import", "section_shortcuts")}</span>
            <.badge>{dgettext("import", "badge_ui_only")}</.badge>
          </:header>

          <div class="au-list">
            <div class="au-item">
              <div>
                <div class="text-[13px] text-white/92">
                  {dgettext("import", "shortcut_preview_title")}
                </div>
                <div class="text-[12px] text-white/68 mt-[2px]">
                  {dgettext("import", "shortcut_preview_sub")}
                </div>
              </div>
              <button class="au-btn" phx-click="set_step" phx-value-step="4">
                {dgettext("import", "btn_go")}
              </button>
            </div>
            <div class="au-item">
              <div>
                <div class="text-[13px] text-white/92">
                  {dgettext("import", "shortcut_recon_title")}
                </div>
                <div class="text-[12px] text-white/68 mt-[2px]">
                  {dgettext("import", "shortcut_recon_sub")}
                </div>
              </div>
              <.link href="/reconciliation" class="au-btn">
                {dgettext("import", "btn_go")}
              </.link>
            </div>
          </div>
        </.au_card>
      </div>
    </div>
    """
  end

  defp stage_placeholder(0), do: dgettext("import", "stage_upload")
  defp stage_placeholder(1), do: dgettext("import", "stage_parse")
  defp stage_placeholder(2), do: dgettext("import", "stage_normalize")
  defp stage_placeholder(3), do: dgettext("import", "stage_deduplicate")
  defp stage_placeholder(5), do: dgettext("import", "stage_commit")
  defp stage_placeholder(_), do: "—"

  defp mock_preview_rows do
    [
      %{
        date: "2026-03-01",
        description: "UBER *TRIP",
        amount: -47.90,
        currency: "BRL",
        status: :ready,
        hint: "Rule matched: Transport"
      },
      %{
        date: "2026-03-02",
        description: "QQQD BUY",
        amount: -2_640.0,
        currency: "USD",
        status: :ready,
        hint: "Investment recognition: Buy"
      },
      %{
        date: "2026-03-02",
        description: "BROKER COMMISSION",
        amount: -13.09,
        currency: "USD",
        status: :error,
        hint: "Missing fee account mapping"
      },
      %{
        date: "2026-03-02",
        description: "QQQD BUY",
        amount: -2_640.0,
        currency: "USD",
        status: :duplicate,
        hint: "Duplicate vs tx_001"
      }
    ]
  end
end
