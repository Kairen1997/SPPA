defmodule Sppa.PermohonanPerubahan do
  @moduledoc """
  Context for permohonan perubahan (change management requests).
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.PermohonanPerubahan.PermohonanPerubahan

  @doc """
  Returns the list of permohonan_perubahan for a project.
  """
  def list_by_project(project_id) do
    PermohonanPerubahan
    |> where([p], p.project_id == ^project_id)
    |> order_by([p], asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single permohonan_perubahan.
  """
  def get_permohonan_perubahan!(id), do: Repo.get!(PermohonanPerubahan, id)

  @doc """
  Gets a single permohonan_perubahan by id and project_id.
  """
  def get_by_project(project_id, id) do
    PermohonanPerubahan
    |> where([p], p.project_id == ^project_id and p.id == ^id)
    |> Repo.one()
  end

  @doc """
  Creates a permohonan_perubahan.
  """
  def create_permohonan_perubahan(attrs \\ %{}) do
    %PermohonanPerubahan{}
    |> PermohonanPerubahan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a permohonan_perubahan. Raises on failure.
  """
  def create_permohonan_perubahan!(attrs \\ %{}) do
    %PermohonanPerubahan{}
    |> PermohonanPerubahan.changeset(attrs)
    |> Repo.insert!()
  end

  @doc """
  Updates a permohonan_perubahan.
  """
  def update_permohonan_perubahan(%PermohonanPerubahan{} = permohonan, attrs) do
    permohonan
    |> PermohonanPerubahan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a permohonan_perubahan.
  """
  def delete_permohonan_perubahan(%PermohonanPerubahan{} = permohonan) do
    Repo.delete(permohonan)
  end
end
