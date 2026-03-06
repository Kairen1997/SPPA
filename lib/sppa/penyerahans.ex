defmodule Sppa.Penyerahans do
  @moduledoc """
  Context untuk penyerahan sistem.
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.Penyerahans.Penyerahan

  @doc """
  Senarai penyerahan bagi satu projek.
  """
  def list_penyerahans_by_project_id(nil), do: []

  def list_penyerahans_by_project_id(project_id) when is_integer(project_id) do
    Penyerahan
    |> where([p], p.project_id == ^project_id)
    |> order_by([p], asc: p.tarikh_penyerahan, asc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Cipta penyerahan baharu.
  """
  def create_penyerahan(attrs \\ %{}) do
    %Penyerahan{}
    |> Penyerahan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Kemaskini penyerahan sedia ada.
  """
  def update_penyerahan(%Penyerahan{} = penyerahan, attrs) do
    penyerahan
    |> Penyerahan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Dapatkan satu penyerahan (atau nil jika tiada).
  """
  def get_penyerahan(id) when is_integer(id) do
    Repo.get(Penyerahan, id)
  end

  def get_penyerahan(_), do: nil

  @doc """
  Dapatkan penyerahan bagi sesuatu projek (atau nil jika tiada).
  """
  def get_penyerahan_by_project_id(nil), do: nil

  def get_penyerahan_by_project_id(project_id) when is_integer(project_id) do
    Penyerahan
    |> where([p], p.project_id == ^project_id)
    |> order_by([p], asc: p.inserted_at)
    |> limit(1)
    |> Repo.one()
  end
end
