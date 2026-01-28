defmodule Sppa.ApprovedProjects do
  @moduledoc """
  Context for approved projects received from sistem permohonan aplikasi.
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.ApprovedProjects.ApprovedProject

  @doc """
  Insert approved project data coming from sistem permohonan aplikasi (Internal API).
  Uses on_conflict: :nothing to handle duplicates gracefully.
  Returns {:ok, struct} for new inserts, {:ok, nil} for conflicts (duplicates).
  """
  def create_approved_project(attrs) do
    changeset = ApprovedProject.changeset(%ApprovedProject{}, attrs)

    case Repo.insert(changeset, on_conflict: :nothing, conflict_target: :external_application_id) do
      {:ok, %ApprovedProject{id: nil}} ->
        # Duplicate detected (on_conflict returned struct without ID)
        {:ok, nil}
      {:ok, project} ->
        # New record inserted successfully
        {:ok, project}
      {:error, error_changeset} ->
        # Validation or other error
        {:error, error_changeset}
    end
  end

  @doc """
  List all approved projects and preload internal project if exists.
  """
  def list_approved_projects do
    Repo.all(from a in ApprovedProject, preload: [:project])
  end

  @doc """
  Get a single approved project.
  """
  def get_approved_project!(id) do
    Repo.get!(ApprovedProject, id)
    |> Repo.preload(:project)
  end

  @doc """
  Update an approved project.
  """
  def update_approved_project(%ApprovedProject{} = approved_project, attrs) do
    approved_project
    |> ApprovedProject.changeset(attrs)
    |> Repo.update()
  end
end
