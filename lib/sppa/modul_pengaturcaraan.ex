defmodule Sppa.ModulPengaturcaraan do
  @moduledoc """
  Context for modul pengaturcaraan (programming-phase data per module from Analisis dan Rekabentuk).
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.ModulPengaturcaraan.ModulPengaturcaraan

  @doc """
  Returns all modul_pengaturcaraan for a project, keyed by analisis_dan_rekabentuk_module_id.
  """
  def list_by_project(project_id) do
    ModulPengaturcaraan
    |> where([m], m.project_id == ^project_id)
    |> Repo.all()
    |> Map.new(fn m -> {m.analisis_dan_rekabentuk_module_id, m} end)
  end

  @doc """
  Gets or creates a modul_pengaturcaraan for the given project and analisis module.
  Returns the existing record or inserts a new one with defaults.
  """
  def get_or_create(project_id, analisis_dan_rekabentuk_module_id) do
    case get_by_project_and_module(project_id, analisis_dan_rekabentuk_module_id) do
      nil ->
        attrs = %{
          project_id: project_id,
          analisis_dan_rekabentuk_module_id: analisis_dan_rekabentuk_module_id,
          status: "Belum Mula"
        }

        %ModulPengaturcaraan{}
        |> ModulPengaturcaraan.changeset(attrs)
        |> Repo.insert()

      existing ->
        {:ok, existing}
    end
  end

  @doc """
  Gets a single modul_pengaturcaraan by project and analisis module.
  """
  def get_by_project_and_module(project_id, analisis_dan_rekabentuk_module_id) do
    ModulPengaturcaraan
    |> where(
      [m],
      m.project_id == ^project_id and
        m.analisis_dan_rekabentuk_module_id == ^analisis_dan_rekabentuk_module_id
    )
    |> Repo.one()
  end

  @doc """
  Updates a modul_pengaturcaraan.
  """
  def update_modul_pengaturcaraan(%ModulPengaturcaraan{} = modul, attrs) do
    modul
    |> ModulPengaturcaraan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates or creates modul_pengaturcaraan for the given project and analisis module.
  """
  def upsert(project_id, analisis_dan_rekabentuk_module_id, attrs) do
    case get_by_project_and_module(project_id, analisis_dan_rekabentuk_module_id) do
      nil ->
        attrs =
          attrs
          |> Map.put(:project_id, project_id)
          |> Map.put(:analisis_dan_rekabentuk_module_id, analisis_dan_rekabentuk_module_id)

        %ModulPengaturcaraan{}
        |> ModulPengaturcaraan.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> ModulPengaturcaraan.changeset(attrs)
        |> Repo.update()
    end
  end
end
