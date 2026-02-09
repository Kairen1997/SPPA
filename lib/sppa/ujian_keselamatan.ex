defmodule Sppa.UjianKeselamatan do
  @moduledoc """
  Context for security tests (ujian keselamatan).
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.UjianKeselamatan.UjianKeselamatan
  alias Sppa.UjianKeselamatan.KesUjianKeselamatan

  @doc """
  Returns the list of ujian keselamatan. For backward compatibility.
  Prefer list_ujian_for_project/1 when project scope is known.
  """
  def list_ujian do
    UjianKeselamatan
    |> order_by([u], asc: u.inserted_at)
    |> preload([:kes_ujian])
    |> Repo.all()
    |> Enum.map(&format_ujian_for_display/1)
  end

  @doc """
  Returns the list of ujian keselamatan for a project with kes_ujian preloaded.
  """
  def list_ujian_for_project(project_id) when is_integer(project_id) do
    UjianKeselamatan
    |> where([u], u.project_id == ^project_id)
    |> order_by([u], asc: u.inserted_at)
    |> preload([:kes_ujian])
    |> Repo.all()
  end

  def list_ujian_for_project(_), do: []

  @doc """
  Builds the merged list of ujian rows for the index table. For each module from
  Analisis Dan Rekabentuk, returns either the matching ujian (by module_id) or
  a placeholder row with default values.
  """
  def list_ujian_rows_for_project(project_id, current_scope) do
    modules = AnalisisDanRekabentuk.list_modules_for_project(project_id, current_scope)
    ujian_list = list_ujian_for_project(project_id)

    ujian_by_module_id =
      ujian_list
      |> Enum.filter(fn u -> u.analisis_dan_rekabentuk_module_id end)
      |> Map.new(fn u -> {u.analisis_dan_rekabentuk_module_id, u} end)

    rows_from_modules =
      modules
      |> Enum.with_index(1)
      |> Enum.map(fn {module, idx} ->
        module_id = module[:id]
        mod_db_id = parse_module_id(module_id)
        ujian = mod_db_id && Map.get(ujian_by_module_id, mod_db_id)

        if ujian do
          format_ujian_row(ujian, module[:name] || module["name"], idx)
        else
          %{
            id: module_id,
            number: idx,
            nama_modul: module[:name] || module["name"] || "",
            tajuk: nil,
            modul: module[:name] || module["name"] || "",
            status: "Menunggu",
            tarikh_ujian: nil,
            tarikh_dijangka_siap: nil,
            penguji: nil,
            hasil: "Belum Selesai",
            disahkan_oleh: nil,
            catatan: nil,
            senarai_kes_ujian: []
          }
        end
      end)

    # Append ujian without module_id (e.g. created before module linking)
    orphan_ujian =
      ujian_list
      |> Enum.reject(fn u -> u.analisis_dan_rekabentuk_module_id end)
      |> Enum.with_index(length(rows_from_modules) + 1)
      |> Enum.map(fn {ujian, idx} ->
        format_ujian_row(ujian, ujian.modul || "", idx)
      end)

    rows_from_modules ++ orphan_ujian
  end

  defp parse_module_id("module_" <> rest) do
    case Integer.parse(rest) do
      {id, _} -> id
      :error -> nil
    end
  end

  defp parse_module_id(_), do: nil

  defp format_ujian_row(ujian, nama_modul, number) do
    kes_formatted = format_kes_list(ujian.kes_ujian || [])

    %{
      id: ujian.id,
      number: number,
      nama_modul: nama_modul,
      tajuk: ujian.tajuk,
      modul: ujian.modul,
      status: ujian.status || "Menunggu",
      tarikh_ujian: ujian.tarikh_ujian,
      tarikh_dijangka_siap: ujian.tarikh_dijangka_siap,
      penguji: ujian.penguji,
      hasil: ujian.hasil || "Belum Selesai",
      disahkan_oleh: ujian.disahkan_oleh,
      catatan: ujian.catatan,
      senarai_kes_ujian: kes_formatted
    }
  end

  @doc """
  Gets a single ujian keselamatan by id with kes_ujian preloaded.
  """
  def get_ujian(nil), do: nil

  def get_ujian(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, _} -> get_ujian(int_id)
      :error -> nil
    end
  end

  def get_ujian(id) when is_integer(id) do
    UjianKeselamatan
    |> Repo.get(id)
    |> case do
      nil -> nil
      ujian -> Repo.preload(ujian, :kes_ujian)
    end
  end

  @doc """
  Gets ujian by id and returns it formatted for LiveView display.
  """
  def get_ujian_formatted(id) when is_nil(id), do: nil

  def get_ujian_formatted(id) do
    case get_ujian(id) do
      nil -> nil
      ujian -> format_ujian_for_display(ujian)
    end
  end

  @doc """
  Creates an ujian keselamatan.
  """
  def create_ujian(attrs \\ %{}) do
    %UjianKeselamatan{}
    |> UjianKeselamatan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an ujian keselamatan.
  """
  def update_ujian(%UjianKeselamatan{} = ujian, attrs) do
    ujian
    |> UjianKeselamatan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an ujian keselamatan.
  """
  def delete_ujian(%UjianKeselamatan{} = ujian) do
    Repo.delete(ujian)
  end

  @doc """
  Creates a kes ujian keselamatan.
  """
  def create_kes(attrs \\ %{}) do
    %KesUjianKeselamatan{}
    |> KesUjianKeselamatan.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a kes ujian keselamatan.
  """
  def update_kes(%KesUjianKeselamatan{} = kes, attrs) do
    kes
    |> KesUjianKeselamatan.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a kes ujian keselamatan.
  """
  def delete_kes(%KesUjianKeselamatan{} = kes) do
    Repo.delete(kes)
  end

  @doc """
  Gets a kes ujian keselamatan by id.
  """
  def get_kes(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, _} -> Repo.get(KesUjianKeselamatan, int_id)
      :error -> nil
    end
  end

  def get_kes(id) when is_integer(id) do
    Repo.get(KesUjianKeselamatan, id)
  end

  @doc """
  Ensures an ujian keselamatan exists for the given module and project.
  Creates one with default values if not found. Returns the ujian struct.
  """
  def ensure_ujian_for_module(project_id, module_id, modul_name) when is_integer(project_id) do
    name = String.trim(modul_name || "")

    existing =
      UjianKeselamatan
      |> where(
        [u],
        u.project_id == ^project_id and
          u.analisis_dan_rekabentuk_module_id == ^module_id
      )
      |> Repo.one()

    if existing do
      existing
    else
      attrs = %{
        project_id: project_id,
        analisis_dan_rekabentuk_module_id: module_id,
        tajuk: "Ujian Keselamatan - #{name}",
        modul: name,
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
  Formats ujian struct for LiveView display. Maps kes_ujian to senarai_kes_ujian.
  """
  def format_ujian_for_display(nil), do: nil

  def format_ujian_for_display(%UjianKeselamatan{} = ujian) do
    kes_ujian = Repo.preload(ujian, :kes_ujian).kes_ujian
    kes_formatted = format_kes_list(kes_ujian)

    %{
      id: ujian.id,
      number: nil,
      tajuk: ujian.tajuk,
      modul: ujian.modul,
      nama_modul: ujian.modul,
      tarikh_ujian: ujian.tarikh_ujian,
      tarikh_dijangka_siap: ujian.tarikh_dijangka_siap,
      status: ujian.status,
      penguji: ujian.penguji,
      hasil: ujian.hasil,
      disahkan_oleh: ujian.disahkan_oleh,
      catatan: ujian.catatan,
      senarai_kes_ujian: kes_formatted
    }
  end

  defp format_kes_list(kes_ujian) do
    Enum.map(kes_ujian || [], fn kes ->
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
        disahkan: kes.disahkan || false,
        disahkan_oleh: kes.disahkan_oleh,
        tarikh_pengesahan: kes.tarikh_pengesahan
      }
    end)
  end
end
