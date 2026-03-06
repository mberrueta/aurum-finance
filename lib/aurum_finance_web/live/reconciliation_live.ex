defmodule AurumFinanceWeb.ReconciliationLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.ReconciliationComponents

  def mount(_params, _session, socket) do
    sessions = mock_sessions()
    selected = List.first(sessions)

    {:ok,
     socket
     |> assign(:active_nav, :reconciliation)
     |> assign(:page_title, dgettext("reconciliation", "page_title"))
     |> assign(:sessions, sessions)
     |> assign(:selected_session, selected)}
  end

  def handle_event("select_session", %{"id" => id}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == id))
    {:noreply, assign(socket, :selected_session, session)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={dgettext("reconciliation", "page_title")}>
        <:subtitle>{dgettext("reconciliation", "page_subtitle")}</:subtitle>
        <:actions>
          <button class="au-btn au-btn-primary">
            {dgettext("reconciliation", "btn_new_session")}
          </button>
        </:actions>
      </.page_header>

      <div class="grid grid-cols-2 gap-[14px]">
        <%!-- Sessions list --%>
        <.au_card>
          <:header>
            <span>{dgettext("reconciliation", "section_sessions")}</span>
            <.badge variant={:purple}>{length(@sessions)}</.badge>
          </:header>

          <div class="au-list">
            <div
              :for={session <- @sessions}
              phx-click="select_session"
              phx-value-id={session.id}
            >
              <.session_item session={session} />
            </div>
          </div>
        </.au_card>

        <%!-- Session detail --%>
        <.au_card>
          <:header>
            <span>{dgettext("reconciliation", "section_detail")}</span>
            <.badge>{@selected_session.period}</.badge>
          </:header>

          <p class="text-[12px] text-white/68 mt-[10px]">
            {dgettext("reconciliation", "label_account")}:
            <span class="au-badge au-badge-purple ml-[4px]">{@selected_session.account}</span>
          </p>

          <div class="au-hr"></div>

          <p class="text-[12px] text-white/50 mb-[8px]">
            {dgettext("reconciliation", "label_statement_lines")}
          </p>

          <table class="au-table">
            <thead>
              <tr>
                <th>{dgettext("reconciliation", "col_date")}</th>
                <th>{dgettext("reconciliation", "col_description")}</th>
                <th>{dgettext("reconciliation", "col_amount")}</th>
                <th>{dgettext("reconciliation", "col_state")}</th>
                <th>{dgettext("reconciliation", "col_match")}</th>
              </tr>
            </thead>
            <tbody>
              <%= for line <- @selected_session.statement_lines do %>
                <.statement_line_row
                  line={line}
                  match={find_match(@selected_session.matches, line.id)}
                />
              <% end %>
            </tbody>
          </table>

          <div class="au-hr"></div>

          <p class="text-[12px] text-white/50 mb-[8px]">
            {dgettext("reconciliation", "label_discrepancies")}
          </p>

          <%= if @selected_session.discrepancies == [] do %>
            <p class="text-[13px] text-white/50">
              {dgettext("reconciliation", "label_no_discrepancies")}
            </p>
          <% else %>
            <div class="au-list">
              <.discrepancy_item
                :for={d <- @selected_session.discrepancies}
                discrepancy={d}
              />
            </div>
          <% end %>
        </.au_card>
      </div>
    </div>
    """
  end

  defp find_match(matches, statement_id) do
    Enum.find(matches, &(&1.statement == statement_id))
  end

  # ── Mock data ──────────────────────────────────────────────────────────────────

  defp mock_sessions do
    [
      %{
        id: "rec_001",
        entity: "pf_br",
        account: "a_cash_br",
        period: "2026-03",
        status: "in_progress",
        statement_lines: [
          %{id: "s1", date: "2026-03-01", desc: "UBER *TRIP", amount: -47.90, currency: "BRL"},
          %{
            id: "s2",
            date: "2026-03-02",
            desc: "BROKER COMMISSION",
            amount: -13.09,
            currency: "USD"
          },
          %{id: "s3", date: "2026-03-02", desc: "QQQD BUY", amount: -2_640.0, currency: "USD"}
        ],
        matches: [
          %{statement: "s1", tx: "tx_002", confidence: 0.96, state: "reconciled"},
          %{statement: "s2", tx: nil, confidence: 0.0, state: "unreconciled"},
          %{statement: "s3", tx: "tx_001", confidence: 0.92, state: "cleared"}
        ],
        discrepancies: [
          %{
            type: "missing_tx",
            severity: "warn",
            msg: "Statement line BROKER COMMISSION has no matching ledger posting."
          }
        ]
      }
    ]
  end
end
