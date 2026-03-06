defmodule AurumFinanceWeb.ImportComponents do
  @moduledoc """
  Components for the Import page.

  Components:
    - import_step/1   — a single step pill in the pipeline indicator
    - preview_row/1   — a row in the import preview table
  """

  use Phoenix.Component
  use Gettext, backend: AurumFinanceWeb.Gettext

  import AurumFinanceWeb.UiComponents

  @doc """
  Purpose: renders one pipeline step chip in the import wizard.

  Use: pass the step `label`, its `index`, and current `active_step`.

  Example:

      <.import_step label="Preview" index={4} active_step={4} />
  """
  attr :label, :string, required: true
  attr :index, :integer, required: true
  attr :active_step, :integer, required: true

  def import_step(assigns) do
    ~H"""
    <div class={["au-step", @index == @active_step && "active"]}>
      {@index + 1}. {@label}
    </div>
    """
  end

  @doc """
  Purpose: renders one row in the import preview table.

  Use: pass a preview row map with normalized transaction fields and status.

  Example:

      <.preview_row
        row=%{
          date: "2026-03-01",
          description: "UBER *TRIP",
          amount: -47.90,
          currency: "BRL",
          status: :ready,
          hint: "Rule matched: Transport"
        }
      />
  """
  attr :row, :map, required: true

  def preview_row(assigns) do
    ~H"""
    <tr>
      <td class="au-mono whitespace-nowrap">{@row.date}</td>
      <td class="text-white/92">{@row.description}</td>
      <td class="au-mono whitespace-nowrap">{format_money(@row.amount, @row.currency)}</td>
      <td class="au-mono">{@row.currency}</td>
      <td>
        <.badge variant={status_variant(@row.status)}>
          {status_label(@row.status)}
        </.badge>
      </td>
      <td class="text-white/68">{@row.hint}</td>
    </tr>
    """
  end

  defp status_variant(:ready), do: :good
  defp status_variant(:duplicate), do: :warn
  defp status_variant(:error), do: :bad
  defp status_variant(_), do: :default

  defp status_label(:ready), do: dgettext("import", "status_ready")
  defp status_label(:duplicate), do: dgettext("import", "status_duplicate")
  defp status_label(:error), do: dgettext("import", "status_error")
  defp status_label(s), do: to_string(s)
end
