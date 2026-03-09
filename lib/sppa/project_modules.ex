defmodule Sppa.ProjectModules do
  @moduledoc """
  Context for project modules (tugasan/modul per projek).
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.Projects
  alias Sppa.ProjectModules.ProjectModule

  @doc """
  List project modules (tugasan) assigned to the current user for the Pengaturcaraan page.
  Only returns modules where developer_id == current_scope.user.id, restricted to projects
  the user can access (pengurus projek: assigned via approved_project.pengurus_projek;
  pembangun sistem: developer or in approved_project.pembangun_sistem).
  """
  def list_modules_assigned_to_user(current_scope) do
    user_id = current_scope.user && current_scope.user.id

    if is_nil(user_id) do
      []
    else
      project_ids = Projects.list_accessible_project_ids_for_pengaturcaraan(current_scope)

      if project_ids == [] do
        []
      else
        ProjectModule
        |> where([m], m.project_id in ^project_ids and m.developer_id == ^user_id)
        |> order_by([m], asc: m.project_id, asc: m.fasa, asc: m.versi, asc: m.inserted_at)
        |> preload([:developer, project: :approved_project])
        |> Repo.all()
      end
    end
  end

  @doc """
  List all modules for a given project by project_id (no user filter).
  Used for display on Analisis dan Rekabentuk page so pembangun sistem can see
  modul created by pengurus projek (tajuk tugasan, penerangan).
  """
  def list_modules_by_project_id(project_id) when is_integer(project_id) do
    ProjectModule
    |> where([m], m.project_id == ^project_id)
    |> order_by([m], asc: m.fasa, asc: m.versi, asc: m.inserted_at)
    |> preload([m], [:developer, :project])
    |> Repo.all()
  end

  def list_modules_by_project_id(_), do: []

  @doc """
  List all modules for a given project.

  Access control is enforced at the project level (for example in
  `Projects.get_project!/2`), so this function simply returns all
  modules for the given project_id.
  """
  def list_modules_for_project(_current_scope, project_id) do
    list_modules_by_project_id(project_id)
  end

  @doc """
  Create a module (task) for a project.
  """
  def create_module(attrs) do
    %ProjectModule{}
    |> ProjectModule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Update an existing module.
  """
  def update_module(%ProjectModule{} = module, attrs) do
    module
    |> ProjectModule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a module.
  """
  def delete_module(%ProjectModule{} = module) do
    Repo.delete(module)
  end

  @doc """
  Get a single module by id.
  """
  def get_module!(id) do
    Repo.get!(ProjectModule, id)
  end
end
