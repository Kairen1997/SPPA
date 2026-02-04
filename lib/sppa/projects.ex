defmodule Sppa.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Sppa.Repo
  alias Sppa.Projects.Project

  @doc """
  Returns the list of projects for a user scope.
  """
  def list_projects(current_scope) do
    Project
    |> where([p], p.user_id == ^current_scope.user.id)
    |> preload([:developer, :project_manager])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
  end

  @doc """
  Returns the list of projects for a pengurus projek (project manager).
  Projects where the current user is assigned as project manager.
  """
  def list_projects_for_pengurus_projek(current_scope) do
    Project
    |> where([p], p.project_manager_id == ^current_scope.user.id)
    |> preload([:developer, :project_manager])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
    |> Enum.map(&format_project_for_display/1)
  end

  @doc """
  Returns the list of all projects (for directors/admins).
  """
  def list_all_projects do
    Project
    |> preload([:developer, :project_manager])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
    |> Enum.map(&format_project_for_display/1)
  end

  @doc """
  Returns the list of projects for a pembangun sistem (developer).
  Projects where the current user is assigned as developer.
  """
  def list_projects_for_pembangun_sistem(current_scope) do
    Project
    |> where([p], p.developer_id == ^current_scope.user.id)
    |> preload([:developer, :project_manager])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
    |> Enum.map(&format_project_for_display/1)
  end

  @doc """
  Formats project data for display in senarai projek.
  """
  def format_project_for_display(project) do
    %{
      id: project.id,
      nama: project.nama,
      jabatan: project.jabatan,
      status: project.status,
      fasa: project.fasa,
      tarikh_mula: project.tarikh_mula,
      tarikh_siap: project.tarikh_siap,
      pengurus_projek: get_user_display_name(project.project_manager),
      pembangun_sistem: get_user_display_name(project.developer),
      developer_id: project.developer_id,
      project_manager_id: project.project_manager_id,
      dokumen_sokongan: project.dokumen_sokongan || 0
    }
  end

  defp get_user_display_name(nil), do: nil

  defp get_user_display_name(user) do
    # Try to get name from email or no_kp
    cond do
      user.email && user.email != "" -> user.email
      user.no_kp && user.no_kp != "" -> user.no_kp
      true -> "N/A"
    end
  end

  @doc """
  Returns the list of recent activities (latest projects).
  Only includes projects with status "Dalam Pembangunan" or "Selesai".
  """
  def list_recent_activities(current_scope, limit \\ 10) do
    Project
    |> where([p], p.user_id == ^current_scope.user.id)
    |> where([p], p.status == "Dalam Pembangunan" or p.status == "Selesai")
    |> preload([:developer, :project_manager])
    |> order_by([p], desc: p.last_updated)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets dashboard statistics for a user scope.
  Optimized to use a single query instead of multiple separate queries.
  """
  def get_dashboard_stats(current_scope) do
    result =
      from(p in Project,
        where: p.user_id == ^current_scope.user.id,
        select: %{
          total_projects: count(p.id),
          in_development: filter(count(p.id), p.status == "Dalam Pembangunan"),
          completed: filter(count(p.id), p.status == "Selesai"),
          on_hold: filter(count(p.id), p.status == "Ditangguhkan"),
          uat: filter(count(p.id), p.status == "UAT"),
          change_management: filter(count(p.id), p.status == "Pengurusan Perubahan")
        }
      )
      |> Repo.one()

    %{
      total_projects: result.total_projects || 0,
      in_development: result.in_development || 0,
      completed: result.completed || 0,
      on_hold: result.on_hold || 0,
      uat: result.uat || 0,
      change_management: result.change_management || 0
    }
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.
  """
  def get_project!(id, current_scope) do
    Project
    |> where([p], p.id == ^id and p.user_id == ^current_scope.user.id)
    |> preload([:developer, :project_manager, :approved_project])
    |> Repo.one!()
  end

  @doc """
  Gets a single project by ID without user scope restriction.
  Used for directors/admins who can view all projects.
  """
  def get_project_by_id(id) do
    Project
    |> where([p], p.id == ^id)
    |> preload([:developer, :project_manager])
    |> Repo.one()
  end

  @doc """
  Creates a project.
  """
  def create_project(attrs, current_scope) do
    case %Project{}
         |> Project.changeset(attrs)
         |> put_change(:user_id, current_scope.user.id)
         |> Repo.insert() do
      {:ok, project} ->
        # If project is linked to an approved project, broadcast update
        if project.approved_project_id do
          approved_project = Sppa.ApprovedProjects.get_approved_project!(project.approved_project_id)
          Phoenix.PubSub.broadcast(Sppa.PubSub, "approved_projects", {:updated, approved_project})
        end
        {:ok, project}
      error ->
        error
    end
  end

  @doc """
  Updates a project.
  """
  def update_project(%Project{} = project, attrs) do
    case project
         |> Project.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_project} ->
        # If project is linked to an approved project, broadcast update
        if updated_project.approved_project_id do
          approved_project = Sppa.ApprovedProjects.get_approved_project!(updated_project.approved_project_id)
          Phoenix.PubSub.broadcast(Sppa.PubSub, "approved_projects", {:updated, approved_project})
        end
        {:ok, updated_project}
      error ->
        error
    end
  end

  @doc """
  Deletes a project.
  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end
end
