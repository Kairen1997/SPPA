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
  Returns the list of recent activities (latest projects).
  """
  def list_recent_activities(current_scope, limit \\ 10) do
    Project
    |> where([p], p.user_id == ^current_scope.user.id)
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
    |> preload([:developer, :project_manager])
    |> Repo.one!()
  end

  @doc """
  Creates a project.
  """
  def create_project(attrs, current_scope) do
    %Project{}
    |> Project.changeset(attrs)
    |> put_change(:user_id, current_scope.user.id)
    |> Repo.insert()
  end

  @doc """
  Updates a project.
  """
  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a project.
  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end
end
