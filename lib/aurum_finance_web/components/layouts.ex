defmodule AurumFinanceWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AurumFinanceWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the AurumFinance app shell: sidebar nav + topbar + content area.

  ## Examples

      <Layouts.app flash={@flash} active_nav={:dashboard}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :active_nav, :atom, default: nil, doc: "active nav item id, e.g. :dashboard"
  attr :page_title, :string, default: nil, doc: "current page title shown in the topbar"
  attr :inner_content, :any, default: nil
  slot :inner_block

  def app(assigns) do
    ~H"""
    <div class="au-app au-app-bg">
      <%!-- Sidebar --%>
      <aside class="au-sidebar">
        <%!-- Brand --%>
        <div class="flex items-center gap-[10px] px-[10px] pb-5 mb-1">
          <div class="au-logo" aria-hidden="true"></div>
          <div>
            <div class="text-[15px] font-semibold tracking-[0.2px] text-white/90">
              {dgettext("layout", "app_name")}
            </div>
            <div class="text-[12px] text-white/50 mt-[2px]">
              {dgettext("layout", "app_tagline")}
            </div>
          </div>
        </div>

        <%!-- Nav --%>
        <nav class="flex flex-col gap-[6px]">
          <%= for {id, label, icon, path} <- nav_items() do %>
            <.link
              navigate={path}
              class={["au-nav-item", @active_nav == id && "active"]}
            >
              <.icon name={icon} class="w-[18px] h-[18px] shrink-0 opacity-90" />
              <span>{label}</span>
            </.link>
          <% end %>
        </nav>

        <%!-- Snapshot section --%>
        <div class="au-section-label mt-auto pt-4">
          {dgettext("layout", "sidebar_snapshot_label")}
        </div>
        <div class="au-sidecard">
          <div class="text-[12px] text-white/50 leading-relaxed">
            {dgettext("layout", "sidebar_snapshot_placeholder")}
          </div>
        </div>
      </aside>

      <%!-- Main --%>
      <div class="au-main">
        <%!-- Topbar --%>
        <header class="au-topbar">
          <div class="flex items-center gap-2 min-w-0 text-[13px]">
            <span class="text-white/50 shrink-0">{dgettext("layout", "breadcrumb_app")}</span>
            <span class="text-white/30 shrink-0">/</span>
            <span class="text-white/88 truncate font-medium">
              {@page_title || dgettext("layout", "nav_dashboard")}
            </span>
          </div>
          <div class="flex items-center gap-[10px]">
            <.link
              id="logout-link"
              href={~p"/logout"}
              method="delete"
              class="au-btn"
            >
              {dgettext("layout", "nav_logout")}
            </.link>
            <div class="au-control">
              <span>{dgettext("layout", "topbar_entity_label")}</span>
              <span class="text-white/88 text-[13px]">
                {dgettext("layout", "topbar_entity_placeholder")}
              </span>
            </div>
            <div class="au-control">
              <span>{dgettext("layout", "topbar_currency_label")}</span>
              <span class="text-white/88 text-[13px] au-mono">
                {dgettext("layout", "topbar_currency_placeholder")}
              </span>
            </div>
            <div class="au-control">
              <span>{dgettext("layout", "topbar_rate_label")}</span>
              <span class="text-white/88 text-[13px] au-mono">
                {dgettext("layout", "topbar_rate_placeholder")}
              </span>
            </div>
            <label class="au-search">
              <.icon name="hero-magnifying-glass-mini" class="w-4 h-4 text-white/50 shrink-0" />
              <input
                id="app-shell-search"
                type="search"
                placeholder={dgettext("layout", "topbar_search_placeholder")}
                aria-label={dgettext("layout", "topbar_search_aria")}
              />
            </label>
          </div>
        </header>

        <%!-- Content --%>
        <main class="au-content">
          <.flash_group flash={@flash} />
          {if @inner_block != [], do: render_slot(@inner_block), else: @inner_content}
        </main>
      </div>
    </div>
    """
  end

  defp nav_items do
    [
      {:dashboard, dgettext("layout", "nav_dashboard"), "hero-home-mini", ~p"/dashboard"},
      {:entities, dgettext("layout", "nav_entities"), "hero-user-group-mini", ~p"/entities"},
      {:accounts, dgettext("layout", "nav_accounts"), "hero-building-library-mini",
       ~p"/accounts"},
      {:transactions, dgettext("layout", "nav_transactions"), "hero-list-bullet-mini",
       ~p"/transactions"},
      {:import, dgettext("layout", "nav_import"), "hero-arrow-up-tray-mini", ~p"/import"},
      {:rules, dgettext("layout", "nav_rules"), "hero-bolt-mini", ~p"/rules"},
      {:reconciliation, dgettext("layout", "nav_reconciliation"), "hero-check-circle-mini",
       ~p"/reconciliation"},
      {:fx, dgettext("layout", "nav_fx"), "hero-globe-alt-mini", ~p"/fx"},
      {:reports, dgettext("layout", "nav_reports"), "hero-chart-bar-mini", ~p"/reports"},
      {:settings, dgettext("layout", "nav_settings"), "hero-cog-6-tooth-mini", ~p"/settings"}
    ]
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
