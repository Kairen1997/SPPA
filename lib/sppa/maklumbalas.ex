defmodule Sppa.Maklumbalas do
  @moduledoc """
  Context untuk maklumbalas pelanggan (feedback) bagi projek.
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.Maklumbalas.Maklumbalas

  @doc """
  Senarai maklumbalas bagi satu projek, disusun mengikut tarikh (terkini dahulu).
  """
  def list_by_project_id(nil), do: []

  def list_by_project_id(project_id) when is_integer(project_id) do
    Maklumbalas
    |> where([m], m.project_id == ^project_id)
    |> order_by([m], desc: m.tarikh_maklumbalas, desc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Cipta maklumbalas baharu.
  """
  def create_maklumbalas(attrs \\ %{}) do
    %Maklumbalas{}
    |> Maklumbalas.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Kemaskini maklumbalas sedia ada.
  """
  def update_maklumbalas(%Maklumbalas{} = maklumbalas, attrs) do
    maklumbalas
    |> Maklumbalas.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Dapatkan satu maklumbalas mengikut id (atau nil jika tiada).
  """
  def get_maklumbalas(id) when is_integer(id) do
    Repo.get(Maklumbalas, id)
  end

  def get_maklumbalas(_), do: nil

  @doc """
  Padam maklumbalas.
  """
  def delete_maklumbalas(%Maklumbalas{} = maklumbalas) do
    Repo.delete(maklumbalas)
  end
end
