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
        # Broadcast new project for live dashboard updates
        Phoenix.PubSub.broadcast(Sppa.PubSub, "approved_projects", {:created, project})
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
    case approved_project
         |> ApprovedProject.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_project} ->
        # Broadcast update for live dashboard updates
        Phoenix.PubSub.broadcast(Sppa.PubSub, "approved_projects", {:updated, updated_project})
        {:ok, updated_project}
      error ->
        error
    end
  end

  @doc """
  Get dashboard statistics for approved projects.
  Returns:
  - jumlah: Total number of approved projects
  - jumlah_projek_berdaftar: Number of approved projects with linked internal projects
  - jumlah_projek_perlu_didaftar: Number of approved projects without linked internal projects
  """
  def get_dashboard_stats do
    result =
      from(ap in ApprovedProject,
        left_join: p in assoc(ap, :project),
        select: %{
          jumlah: count(ap.id),
          jumlah_projek_berdaftar: filter(count(ap.id), not is_nil(p.id)),
          jumlah_projek_perlu_didaftar: filter(count(ap.id), is_nil(p.id))
        }
      )
      |> Repo.one()

    %{
      jumlah: result.jumlah || 0,
      jumlah_projek_berdaftar: result.jumlah_projek_berdaftar || 0,
      jumlah_projek_perlu_didaftar: result.jumlah_projek_perlu_didaftar || 0
    }
  end
end
