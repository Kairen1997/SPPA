defmodule Sppa.ProjectModules do
  @moduledoc """
  Context for project modules (tugasan/modul per projek).
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.ProjectModules.ProjectModule

  @doc """
  List all modules for a given project that belong to the current scope's owner.
  """
  def list_modules_for_project(current_scope, project_id) do
    ProjectModule
    |> join(:inner, [m], p in assoc(m, :project))
    |> where([m, p], m.project_id == ^project_id and p.user_id == ^current_scope.user.id)
    |> preload([m, p], [:developer, project: p])
    |> order_by([m, _p], asc: m.fasa, asc: m.versi, asc: m.inserted_at)
    |> Repo.all()
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
