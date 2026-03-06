defmodule AurumFinanceWeb.RulesLive do
  use AurumFinanceWeb, :live_view

  import AurumFinanceWeb.RulesComponents

  def mount(_params, _session, socket) do
    groups = mock_rule_groups()

    {:ok,
     socket
     |> assign(:active_nav, :rules)
     |> assign(:page_title, dgettext("rules", "page_title"))
     |> assign(:groups, groups)
     |> assign(:selected_group, List.first(groups))
     |> assign(:test_result, nil)}
  end

  def handle_event("select_group", %{"id" => id}, socket) do
    group = Enum.find(socket.assigns.groups, &(&1.id == id))
    {:noreply, assign(socket, selected_group: group, test_result: nil)}
  end

  def handle_event("run_test", _, socket) do
    group = socket.assigns.selected_group
    first_rule = List.first(group.rules)

    result = %{
      rule_id: first_rule && first_rule.id,
      overlay: "category=Transport, tags=[ride]",
      confidence: "0.93"
    }

    {:noreply, assign(socket, :test_result, result)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.page_header title={dgettext("rules", "page_title")}>
        <:subtitle>{dgettext("rules", "page_subtitle")}</:subtitle>
        <:actions>
          <button class="au-btn au-btn-primary">{dgettext("rules", "btn_new_group")}</button>
        </:actions>
      </.page_header>

      <div class="grid grid-cols-2 gap-[14px]">
        <%!-- Rule groups list --%>
        <.au_card>
          <:header>
            <span>{dgettext("rules", "section_rule_groups")}</span>
            <.badge variant={:purple}>{length(@groups)}</.badge>
          </:header>

          <div class="au-list">
            <div
              :for={group <- @groups}
              phx-click="select_group"
              phx-value-id={group.id}
            >
              <.rule_group_item group={group} />
            </div>
          </div>
        </.au_card>

        <%!-- Rule group detail --%>
        <.au_card>
          <:header>
            <span>{@selected_group.name}</span>
            <.badge variant={:purple}>{dgettext("rules", "badge_ordered")}</.badge>
          </:header>

          <p class="text-[13px] text-white/68 mt-[10px] leading-relaxed">
            {@selected_group.description}
          </p>

          <div class="au-hr"></div>

          <p class="text-[12px] text-white/50 mb-[8px]">{dgettext("rules", "label_rules_table")}</p>

          <table class="au-table">
            <thead>
              <tr>
                <th style="width:70px;">{dgettext("rules", "col_order")}</th>
                <th>{dgettext("rules", "col_when")}</th>
                <th>{dgettext("rules", "col_then")}</th>
                <th style="width:100px;">{dgettext("rules", "col_stop")}</th>
              </tr>
            </thead>
            <tbody>
              <.rule_row :for={rule <- @selected_group.rules} rule={rule} />
            </tbody>
          </table>

          <div class="au-hr"></div>

          <div class="flex items-start justify-between gap-[10px]">
            <div>
              <p class="text-[12px] text-white/50">{dgettext("rules", "label_test_runner")}</p>
              <p class="au-mono text-[11px] text-white/68 mt-[6px]">
                {~s|{"date":"2026-03-01","description":"Uber trip","amount":-47.90}|}
              </p>
            </div>
            <button class="au-btn shrink-0" phx-click="run_test">
              {dgettext("rules", "btn_run_test")}
            </button>
          </div>

          <%= if @test_result do %>
            <div class="au-list mt-[10px]">
              <div class="au-item">
                <div>
                  <div class="text-[13px] text-white/92">
                    {dgettext("rules", "label_test_matched")}: {@test_result.rule_id}
                  </div>
                  <div class="text-[12px] text-white/68 mt-[2px]">
                    {dgettext("rules", "label_test_proposed")}: {@test_result.overlay}
                  </div>
                </div>
                <.badge variant={:good}>
                  {dgettext("rules", "label_test_confidence")} {@test_result.confidence}
                </.badge>
              </div>
            </div>
          <% end %>
        </.au_card>
      </div>
    </div>
    """
  end

  # ── Mock data ──────────────────────────────────────────────────────────────────

  defp mock_rule_groups do
    [
      %{
        id: "rg_expense_cat",
        name: "Expense Category",
        description: "Categorize expenses via ordered rules (stop on match).",
        rules: [
          %{
            id: "r1",
            order: 1,
            when: "description contains \"Uber\"",
            then: "category=Transport, tag=ride",
            stop: true
          },
          %{
            id: "r2",
            order: 2,
            when: "merchant in {\"iFood\",\"Rappi\"}",
            then: "category=Food Delivery",
            stop: true
          },
          %{
            id: "r3",
            order: 3,
            when: "account is credit_card",
            then: "category=Card Purchase",
            stop: false
          }
        ]
      },
      %{
        id: "rg_invest",
        name: "Investment Recognition",
        description: "Detect buys/sells/dividends and attach investment metadata.",
        rules: [
          %{
            id: "i1",
            order: 1,
            when: "description startsWith \"Broker Buy\"",
            then: "category=Investments:Buy",
            stop: true
          },
          %{
            id: "i2",
            order: 2,
            when: "description startsWith \"Dividend\"",
            then: "category=Income:Dividend",
            stop: true
          }
        ]
      }
    ]
  end
end
