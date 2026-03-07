defmodule AurumFinanceWeb.EntitiesLive do
  use AurumFinanceWeb, :live_view

  alias AurumFinance.Entities
  alias AurumFinance.Entities.Entity
  alias AurumFinance.Helpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       active_nav: :entities,
       page_title: dgettext("entities", "page_title"),
       show_archived: false,
       editing_entity: nil
     )
     |> assign_form(%Entity{})
     |> load_entities()}
  end

  @impl true
  def handle_event("toggle_archived", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_archived, not socket.assigns.show_archived)
     |> load_entities()}
  end

  def handle_event("new_entity", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_entity, nil)
     |> assign_form(%Entity{})}
  end

  def handle_event("edit_entity", %{"id" => id}, socket) do
    entity = Entities.get_entity!(id)

    {:noreply,
     socket
     |> assign(:editing_entity, entity)
     |> assign_form(entity)}
  end

  def handle_event("archive_entity", %{"id" => id}, socket) do
    entity = Entities.get_entity!(id)

    result = Entities.archive_entity(entity, actor: "person", channel: :web)

    {:noreply,
     handle_persist_result(socket, result, dgettext("entities", "flash_entity_archived"))}
  end

  def handle_event("unarchive_entity", %{"id" => id}, socket) do
    entity = Entities.get_entity!(id)

    result = Entities.unarchive_entity(entity, actor: "person", channel: :web)

    {:noreply,
     handle_persist_result(socket, result, dgettext("entities", "flash_entity_unarchived"))}
  end

  def handle_event("validate", %{"entity" => params}, socket) do
    target_entity = socket.assigns.editing_entity || %Entity{}

    changeset =
      target_entity
      |> Entities.change_entity(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, as: :entity))}
  end

  def handle_event("save", %{"entity" => params}, socket) do
    result =
      case socket.assigns.editing_entity do
        nil ->
          Entities.create_entity(params, actor: "person", channel: :web)

        entity ->
          Entities.update_entity(entity, params, actor: "person", channel: :web)
      end

    message =
      if socket.assigns.editing_entity,
        do: dgettext("entities", "flash_entity_updated"),
        else: dgettext("entities", "flash_entity_created")

    {:noreply, handle_persist_result(socket, result, message)}
  end

  defp handle_persist_result(socket, {:ok, _entity}, success_message) do
    socket
    |> put_flash(:info, success_message)
    |> assign(:editing_entity, nil)
    |> assign_form(%Entity{})
    |> load_entities()
  end

  defp handle_persist_result(
         socket,
         {:error, {:audit_failed, _changeset, _entity}},
         _success_message
       ) do
    socket
    |> put_flash(:error, dgettext("entities", "flash_audit_logging_failed"))
    |> assign(:editing_entity, nil)
    |> assign_form(%Entity{})
    |> load_entities()
  end

  defp handle_persist_result(socket, {:error, %Ecto.Changeset{} = changeset}, _success_message) do
    assign(socket, :form, to_form(changeset, as: :entity))
  end

  defp load_entities(socket) do
    opts = [include_archived: socket.assigns.show_archived]
    assign(socket, :entities, Entities.list_entities(opts))
  end

  defp assign_form(socket, %Entity{} = entity) do
    changeset = Entities.change_entity(entity)
    assign(socket, :form, to_form(changeset, as: :entity))
  end

  defp effective_tax_country_code(form) do
    fiscal_country_code =
      form[:fiscal_residency_country_code].value
      |> Helpers.blank_to_nil()

    country_code =
      form[:country_code].value
      |> Helpers.blank_to_nil()

    fiscal_country_code || country_code
  end
end
