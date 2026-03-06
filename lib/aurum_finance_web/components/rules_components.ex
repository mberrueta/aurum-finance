defmodule AurumFinanceWeb.RulesComponents do
  @moduledoc """
  Components for the Rules Engine page.

  Components:
    - rule_group_item/1 — a clickable rule group row
    - rule_row/1        — a row in the ordered rules table
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.UiComponents

  @doc """
  Purpose: renders a clickable summary row for one rule group.

  Use: pass a `group` map with `name`, `description`, and `rules`.

  Example:

      <.rule_group_item
        group=%{
          name: "Expense Category",
          description: "Categorize expenses via ordered rules.",
          rules: [%{id: "r1"}, %{id: "r2"}]
        }
      />
  """
  attr :group, :map, required: true

  def rule_group_item(assigns) do
    ~H"""
    <div class="au-item cursor-pointer">
      <div>
        <div class="text-[13px] text-white/92">{@group.name}</div>
        <div class="text-[12px] text-white/68 mt-[2px]">{@group.description}</div>
      </div>
      <.badge>{length(@group.rules)} {dgettext("rules", "label_rules")}</.badge>
    </div>
    """
  end

  @doc """
  Purpose: renders one ordered rule row in the group detail table.

  Use: pass a `rule` map with `order`, `when`, `then`, and `stop`.

  Example:

      <.rule_row
        rule=%{
          order: 1,
          when: "description contains \"Uber\"",
          then: "category=Transport",
          stop: true
        }
      />
  """
  attr :rule, :map, required: true

  def rule_row(assigns) do
    ~H"""
    <tr>
      <td class="au-mono">{@rule.order}</td>
      <td>{@rule.when}</td>
      <td class="au-mono">{@rule.then}</td>
      <td>
        <%= if @rule.stop do %>
          <.badge variant={:good}>{dgettext("rules", "label_stop_yes")}</.badge>
        <% else %>
          <.badge>{dgettext("rules", "label_stop_no")}</.badge>
        <% end %>
      </td>
    </tr>
    """
  end
end
