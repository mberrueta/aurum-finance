defmodule AurumFinanceWeb.SettingsLive do
  use AurumFinanceWeb, :live_view

  def mount(_params, _session, socket) do
    posture_items = [
      %{
        title: "No external data by default",
        sub: "AI integrations are opt-in (future).",
        badge: "privacy-first",
        variant: :good
      },
      %{
        title: "Auditability",
        sub: "Immutable ledger facts + overlays + derived reports.",
        badge: "ledger",
        variant: :default
      },
      %{
        title: "Multi-entity ownership",
        sub: "Personal, company, trust, family profiles.",
        badge: "entities",
        variant: :default
      }
    ]

    links = [
      %{title: "Docs", sub: "README, ADRs, architecture notes", badge: "repo", variant: :default},
      %{
        title: "Security",
        sub: "Boundaries, threat model, privacy posture",
        badge: "review",
        variant: :warn
      }
    ]

    {:ok,
     socket
     |> assign(:active_nav, :settings)
     |> assign(:page_title, dgettext("settings", "page_title"))
     |> assign(:entity_defaults, mock_entity_defaults())
     |> assign(:posture_items, posture_items)
     |> assign(:links, links)}
  end

  def render(assigns) do
    ~H"""
    <div id="settings-page">
      <.page_header title={dgettext("settings", "page_title")}>
        <:subtitle>
          Privacy-first, self-hosted posture. This page is informational in the UI prototype.
        </:subtitle>
      </.page_header>

      <div class="grid grid-cols-1 xl:grid-cols-2 gap-[14px]">
        <.section_panel title="Instance posture" badge="self-hosted" badge_variant={:purple}>
          <div class="au-list">
            <div :for={item <- @posture_items} class="au-item">
              <div>
                <div class="text-[13px] text-white/92">{item.title}</div>
                <div class="text-[12px] text-white/68 mt-[2px]">{item.sub}</div>
              </div>
              <.badge variant={item.variant}>{item.badge}</.badge>
            </div>
          </div>
        </.section_panel>

        <.section_panel title="Entity defaults" badge="mock">
          <div class="au-kv mt-[12px] text-[13px]">
            <div class="text-white/50">Entity</div>
            <div class="text-white/92">{@entity_defaults.entity}</div>
            <div class="text-white/50">Base currency</div>
            <div class="text-white/92">{@entity_defaults.base_currency}</div>
            <div class="text-white/50">Jurisdiction</div>
            <div class="text-white/92">{@entity_defaults.jurisdiction}</div>
            <div class="text-white/50">Default rate type</div>
            <div class="text-white/92">{@entity_defaults.default_rate_type}</div>
          </div>
          <div class="au-hr"></div>
          <p class="text-[12px] text-white/50 leading-relaxed">
            Real settings would control FX series selection, tax posture, import defaults, and data access scopes.
          </p>
        </.section_panel>
      </div>

      <.section_panel title="Links" badge="placeholders" class="mt-[14px]">
        <div class="au-list">
          <div :for={item <- @links} class="au-item">
            <div>
              <div class="text-[13px] text-white/92">{item.title}</div>
              <div class="text-[12px] text-white/68 mt-[2px]">{item.sub}</div>
            </div>
            <.badge variant={item.variant}>{item.badge}</.badge>
          </div>
        </div>
      </.section_panel>
    </div>
    """
  end

  defp mock_entity_defaults do
    %{
      entity: "Personal (BR)",
      base_currency: "BRL",
      jurisdiction: "BR",
      default_rate_type: "market"
    }
  end
end
