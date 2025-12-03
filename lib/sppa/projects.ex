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
  """
  def get_dashboard_stats(current_scope) do
    base_query = from(p in Project, where: p.user_id == ^current_scope.user.id)

    total_projects = Repo.aggregate(base_query, :count, :id)

    in_development =
      base_query
      |> where([p], p.status == "Dalam Pembangunan")
      |> Repo.aggregate(:count, :id)

    completed =
      base_query
      |> where([p], p.status == "Selesai")
      |> Repo.aggregate(:count, :id)

    on_hold =
      base_query
      |> where([p], p.status == "Ditangguhkan")
      |> Repo.aggregate(:count, :id)

    uat =
      base_query
      |> where([p], p.status == "UAT")
      |> Repo.aggregate(:count, :id)

    change_management =
      base_query
      |> where([p], p.status == "Pengurusan Perubahan")
      |> Repo.aggregate(:count, :id)

    %{
      total_projects: total_projects || 0,
      in_development: in_development || 0,
      completed: completed || 0,
      on_hold: on_hold || 0,
      uat: uat || 0,
      change_management: change_management || 0
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
