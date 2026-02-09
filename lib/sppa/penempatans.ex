defmodule Sppa.Penempatans do
  @moduledoc """
  Context for penempatan (deployments).
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.Penempatans.Penempatan

  @doc """
  Returns the list of penempatans for the given project IDs (for current user scope).
  """
  def list_penempatans_by_project_ids(project_ids) when is_list(project_ids) do
    project_ids = Enum.uniq(Enum.reject(project_ids, &is_nil/1))

    if project_ids == [] do
      []
    else
      Penempatan
      |> where([p], p.project_id in ^project_ids)
      |> order_by([p], desc: p.tarikh_penempatan, desc: p.inserted_at)
      |> Repo.all()
    end
  end

  @doc """
  Returns the list of all penempatans (for directors/admins or when no project filter).
  """
  def list_all_penempatans do
    Penempatan
    |> order_by([p], desc: p.tarikh_penempatan, desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single penempatan by id.
  """
  def get_penempatan!(id), do: Repo.get!(Penempatan, id)

  @doc """
  Gets a single penempatan by id. Returns nil if not found.
  """
  def get_penempatan(id) when is_integer(id) do
    Repo.get(Penempatan, id)
  end

  def get_penempatan(_), do: nil

  @doc """
  Creates a penempatan.
  """
  def create_penempatan(attrs \\ %{}) do
    %Penempatan{}
    |> Penempatan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a penempatan.
  """
  def update_penempatan(%Penempatan{} = penempatan, attrs) do
    penempatan
    |> Penempatan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a penempatan.
  """
  def delete_penempatan(%Penempatan{} = penempatan) do
    Repo.delete(penempatan)
  end
end
