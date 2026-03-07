defmodule AurumFinanceWeb.SlideoverComponents do
  @moduledoc """
  Reusable right-docked panel surfaces for create/edit flows.
  """

  use Phoenix.Component

  import AurumFinanceWeb.CoreComponents

  @doc """
  Renders a reusable right-sidebar panel with overlay and close actions.

  ## Examples

      <.right_sidebar_panel open={true} title="Edit entity" close_event="close_form">
        <div>Form content</div>
      </.right_sidebar_panel>
  """
  attr :open, :boolean, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :close_event, :string, required: true
  attr :panel_id, :string, default: "right-sidebar-panel"
  attr :overlay_id, :string, default: "right-sidebar-overlay"
  attr :close_button_id, :string, default: "close-sidebar-btn"
  attr :rest, :global

  slot :inner_block, required: true
  slot :footer

  def right_sidebar_panel(assigns) do
    ~H"""
    <div :if={@open} class="relative z-40" {@rest}>
      <button
        id={@overlay_id}
        type="button"
        class="fixed inset-0 bg-slate-950/70 backdrop-blur-[2px] transition-opacity"
        phx-click={@close_event}
        aria-label="Close panel"
      />

      <aside
        id={@panel_id}
        class="fixed inset-y-0 right-0 flex w-full max-w-2xl justify-end p-3 sm:p-4"
        aria-modal="true"
        role="dialog"
      >
        <div class="flex h-full w-full flex-col overflow-hidden rounded-[28px] border border-white/12 bg-[#081120] shadow-[0_20px_80px_rgba(0,0,0,0.55)]">
          <div class="flex items-start justify-between gap-4 border-b border-white/10 px-5 py-5 sm:px-6">
            <div class="min-w-0">
              <p class="text-[11px] uppercase tracking-[0.22em] text-white/42">Workspace form</p>
              <h3 class="mt-2 text-lg font-semibold tracking-[0.01em] text-white/92">
                {@title}
              </h3>
              <p :if={@subtitle} class="mt-1 text-sm leading-relaxed text-white/62">
                {@subtitle}
              </p>
            </div>

            <button
              id={@close_button_id}
              type="button"
              class="inline-flex size-10 items-center justify-center rounded-2xl border border-white/10 bg-white/[0.03] text-white/70 transition hover:border-white/20 hover:bg-white/[0.08] hover:text-white"
              phx-click={@close_event}
              aria-label="Close panel"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <div class="flex-1 overflow-y-auto px-5 py-5 sm:px-6">
            {render_slot(@inner_block)}
          </div>

          <div :if={@footer != []} class="border-t border-white/10 px-5 py-4 sm:px-6">
            {render_slot(@footer)}
          </div>
        </div>
      </aside>
    </div>
    """
  end
end
