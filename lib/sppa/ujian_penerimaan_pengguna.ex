defmodule Sppa.UjianPenerimaanPengguna do
  @moduledoc """
  Context for ujian penerimaan pengguna (User Acceptance Testing).
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.UjianPenerimaanPengguna.UjianPenerimaanPengguna
  alias Sppa.UjianPenerimaanPengguna.KesUjian

  @doc """
  Returns the list of UAT records.
  """
  def list_ujian do
    list_ujian_for_project(nil)
  end

  @doc """
  Ensures an ujian record exists for the given modul and project.
  Creates one with default values if not found. Returns the ujian struct.
  """
  def ensure_ujian_for_module(project_id, modul_name) when is_integer(project_id) do
    name = String.trim(modul_name || "")
    today = Date.utc_today()

    existing =
      UjianPenerimaanPengguna
      |> where([u], u.project_id == ^project_id and u.modul == ^name)
      |> Repo.one()

    if existing do
      existing
    else
      attrs = %{
        project_id: project_id,
        tajuk: "Ujian Penerimaan Pengguna - #{name}",
        modul: name,
        tarikh_ujian: today,
        tarikh_dijangka_siap: today,
        status: "Menunggu",
        hasil: "Belum Selesai"
      }

      case create_ujian(attrs) do
        {:ok, ujian} -> ujian
        {:error, _} -> nil
      end
    end
  end

  @doc """
  Returns the list of UAT records for a project.
  When project_id is nil, returns all ujian.
  """
  def list_ujian_for_project(nil) do
    UjianPenerimaanPengguna
    |> order_by([u], asc: u.inserted_at)
    |> Repo.all()
  end

  def list_ujian_for_project(project_id) when is_integer(project_id) do
    UjianPenerimaanPengguna
    |> where([u], u.project_id == ^project_id)
    |> order_by([u], asc: u.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single ujian by id with kes_ujian preloaded.
  """
  def get_ujian(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, _} -> get_ujian(int_id)
      :error -> nil
    end
  end

  def get_ujian(id) when is_integer(id) do
    UjianPenerimaanPengguna
    |> Repo.get(id)
    |> case do
      nil -> nil
      ujian -> Repo.preload(ujian, :kes_ujian)
    end
  end

  @doc """
  Creates a ujian penerimaan pengguna.
  """
  def create_ujian(attrs \\ %{}) do
    %UjianPenerimaanPengguna{}
    |> UjianPenerimaanPengguna.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a ujian penerimaan pengguna.
  """
  def update_ujian(%UjianPenerimaanPengguna{} = ujian, attrs) do
    ujian
    |> UjianPenerimaanPengguna.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a ujian penerimaan pengguna.
  """
  def delete_ujian(%UjianPenerimaanPengguna{} = ujian) do
    Repo.delete(ujian)
  end

  @doc """
  Creates a kes ujian.
  """
  def create_kes(attrs \\ %{}) do
    %KesUjian{}
    |> KesUjian.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a kes ujian.
  """
  def update_kes(%KesUjian{} = kes, attrs) do
    kes
    |> KesUjian.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a kes ujian.
  """
  def delete_kes(%KesUjian{} = kes) do
    Repo.delete(kes)
  end

  @doc """
  Gets a kes ujian by id.
  """
  def get_kes(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, _} -> Repo.get(KesUjian, int_id)
      :error -> nil
    end
  end

  def get_kes(id) when is_integer(id) do
    Repo.get(KesUjian, id)
  end

  @doc """
  Formats ujian struct for LiveView display.
  Maps kes_ujian to senarai_kes_ujian and ensures kes has id (for compatibility).
  """
  def format_ujian_for_display(%UjianPenerimaanPengguna{} = ujian) do
    kes_ujian = Repo.preload(ujian, :kes_ujian).kes_ujian

    kes_formatted =
      Enum.map(kes_ujian, fn kes ->
        %{
          id: kes.id,
          kod: kes.kod,
          senario: kes.senario,
          langkah: kes.langkah,
          keputusan_dijangka: kes.keputusan_dijangka,
          keputusan_sebenar: kes.keputusan_sebenar,
          hasil: kes.hasil,
          penguji: kes.penguji,
          tarikh_ujian: kes.tarikh_ujian,
          disahkan_oleh: kes.disahkan_oleh,
          tarikh_pengesahan: kes.tarikh_pengesahan,
          disahkan: (kes.disahkan_oleh || "") != ""
        }
      end)

    %{
      id: ujian.id,
      tajuk: ujian.tajuk,
      modul: ujian.modul,
      tarikh_ujian: ujian.tarikh_ujian,
      tarikh_dijangka_siap: ujian.tarikh_dijangka_siap,
      status: ujian.status,
      penguji: ujian.penguji,
      hasil: ujian.hasil,
      catatan: ujian.catatan,
      senarai_kes_ujian: kes_formatted
    }
  end
end
