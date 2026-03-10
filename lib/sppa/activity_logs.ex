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
  - `:target_user_id` - Optional ID of the user who is the target of the action (e.g. assigned pengurus projek)

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
  Returns recent assignment activities where the current user (pengurus projek) was
  assigned to a project by ketua unit. Used for dashboard PP notifications so the
  project manager sees "Ketua unit telah menugaskan projek X kepada anda."
  """
  def list_recent_assignment_activities_for_pengurus_projek(current_scope, limit \\ 10) do
    if is_nil(current_scope) or is_nil(current_scope.user) or current_scope.user.role != "pengurus projek" do
      []
    else
      from(a in ActivityLog,
        where:
          a.action == "pengurus_projek_dilantik" and
            a.target_user_id == ^current_scope.user.id,
        order_by: [desc: a.inserted_at],
        limit: ^limit,
        preload: [:actor]
      )
      |> Repo.all()
      |> Enum.map(fn a ->
        %{
          resource_name: a.resource_name,
          action_label: action_label(a.action),
          details: a.details,
          inserted_at: a.inserted_at
        }
      end)
    end
  end

  @doc """
  Returns recent assignment activities (pengurus projek dilantik/dikeluarkan) for the
  ketua unit dashboard. All ketua units see the same list; no per-unit filter.
  Used for "Aktiviti Terkini Unit" so ketua unit can see when projects are assigned
  to pengurus projek (nama sistem, nama pengurus, tindakan, tarikh).
  """
  def list_recent_assignment_activities_for_ketua_unit(limit \\ 20) do
    from(a in ActivityLog,
      where:
        a.action in ["pengurus_projek_dilantik", "pengurus_projek_dikeluarkan"] and
          a.resource_type in ["project", "approved_project"] and
          is_nil(a.target_user_id),
      order_by: [desc: a.inserted_at],
      limit: ^limit,
      preload: [:actor]
    )
    |> Repo.all()
  end

  @doc """
  Returns the display label in Malay for an action key.
  """
  def action_label("projek_dicipta"), do: "Projek dicipta"
  def action_label("projek_dikemaskini"), do: "Projek dikemaskini"
  def action_label("pengurus_projek_dilantik"), do: "Pengurus projek dilantik"
  def action_label("pengurus_projek_dikeluarkan"), do: "Pengurus projek dikeluarkan"
  def action_label(action), do: action
end
