defmodule Sppa.ApprovedProjects do
  @moduledoc """
  Context for approved projects received from sistem permohonan aplikasi.
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.ApprovedProjects.ApprovedProject

  # Fields to update when external sync finds an existing record (do not overwrite id, inserted_at, or project_id)
  @sync_upsert_replace_fields [
    :nama_projek, :jabatan, :pengurus_email, :tarikh_mula, :tarikh_jangkaan_siap,
    :pembangun_sistem, :pengurus_projek, :latar_belakang, :objektif, :skop,
    :kumpulan_pengguna, :implikasi, :kertas_kerja_path, :external_updated_at
  ]

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
  Sync one approved project from external API: insert if new, update if existing (by external_application_id).
  Keeps project_id (link to internal project) unchanged on conflict.
  Returns {:ok, project} for insert, {:ok, project} for update, {:error, changeset} on validation error.
  """
  def sync_approved_project(attrs) do
    changeset = ApprovedProject.changeset(%ApprovedProject{}, attrs)

    opts = [
      conflict_target: :external_application_id,
      on_conflict: {:replace, @sync_upsert_replace_fields}
    ]

    case Repo.insert(changeset, opts) do
      {:ok, project} ->
        Phoenix.PubSub.broadcast(Sppa.PubSub, "approved_projects", {:updated, project})
        {:ok, project}

      {:error, error_changeset} ->
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
