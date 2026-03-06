defmodule AurumFinance.Audit.AuditEvent do
  @moduledoc """
  Generic audit event used to track domain changes across contexts.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @channels [:web, :system, :mcp, :ai_assistant]
  @required [:entity_type, :entity_id, :action, :actor, :channel, :occurred_at]
  @optional [:before, :after]

  @type t :: %__MODULE__{}

  schema "audit_events" do
    field :entity_type, :string
    field :entity_id, :binary_id
    field :action, :string
    field :actor, :string
    field :channel, Ecto.Enum, values: @channels
    field :before, :map
    field :after, :map
    field :occurred_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Returns a changeset for inserting an audit event.

  ## Examples

      iex> changeset =
      ...>   AurumFinance.Audit.AuditEvent.changeset(%AurumFinance.Audit.AuditEvent{}, %{
      ...>     entity_type: "entity",
      ...>     entity_id: Ecto.UUID.generate(),
      ...>     action: "created",
      ...>     actor: "root",
      ...>     channel: :web,
      ...>     occurred_at: DateTime.utc_now()
      ...>   })
      iex> changeset.valid?
      true
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(audit_event, attrs) do
    audit_event
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_field_required")
    )
    |> validate_length(:entity_type,
      min: 1,
      max: 120,
      message:
        Gettext.dgettext(
          AurumFinanceWeb.Gettext,
          "errors",
          "error_audit_entity_type_length_invalid"
        )
    )
    |> validate_length(:action,
      min: 1,
      max: 120,
      message:
        Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_audit_action_length_invalid")
    )
    |> validate_length(:actor,
      min: 1,
      max: 120,
      message: Gettext.dgettext(AurumFinanceWeb.Gettext, "errors", "error_audit_actor_invalid")
    )
  end
end
