defmodule Sppa.ActivityLogs do
  @moduledoc """
  Context for activity/audit logging.
  Records who did what, when, for dashboard "Aktiviti Terkini" and audit trail.
  """
  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.ActivityLogs.ActivityLog
  alias Sppa.Projects

  @doc """
  Records an activity in the audit log.

  ## Options
  - `:actor_id` - ID of the user who performed the action (required)
  - `:action` - Action key, e.g. "projek_dicipta", "projek_dikemaskini"
  - `:resource_type` - Type of resource, e.g. "project"
  - `:resource_id` - ID of the resource
  - `:resource_name` - Display name of the resource (e.g. project nama)
  - `:details` - Optional text details (e.g. "Status: Dalam Pembangunan → Selesai")

  ## Examples
      log_activity(%{
        actor_id: user_id,
        action: "projek_dicipta",
        resource_type: "project",
        resource_id: project.id,
        resource_name: project.nama
      })
  """
  def log_activity(attrs) when is_map(attrs) do
    %ActivityLog{}
    |> ActivityLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns recent activity log entries for the current scope.
  Only includes activities for resources (e.g. projects) the user can see based on role.
  """
  def list_recent_activities(current_scope, limit \\ 20) do
    visible_project_ids = Projects.visible_project_ids(current_scope)

    if visible_project_ids == [] do
      []
    else
      from(a in ActivityLog,
        where: a.resource_type == "project" and a.resource_id in ^visible_project_ids,
        order_by: [desc: a.inserted_at],
        limit: ^limit,
        preload: [:actor]
      )
      |> Repo.all()
    end
  end

  @doc """
  Returns the display label in Malay for an action key.
  """
  def action_label("projek_dicipta"), do: "Projek dicipta"
  def action_label("projek_dikemaskini"), do: "Projek dikemaskini"
  def action_label(action), do: action
end
