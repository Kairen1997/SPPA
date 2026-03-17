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
  Mengira nombor ujian seterusnya untuk sesuatu modul dalam projek.
  Contoh: jika sudah ada 2 rekod untuk modul yang sama, fungsi akan
  memulangkan \"3\".
  """
  def next_no_ujian(project_id, modul_name) when is_integer(project_id) do
    name = String.trim(modul_name || "")

    count =
      UjianPenerimaanPengguna
      |> where([u], u.project_id == ^project_id and u.modul == ^name)
      |> select([u], count(u.id))
      |> Repo.one()

    Integer.to_string((count || 0) + 1)
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
  Parses extra_columns JSON string to list of maps with "id" and "label" keys.
  """
  def parse_extra_columns(nil), do: []
  def parse_extra_columns(""), do: []

  def parse_extra_columns(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, list} when is_list(list) ->
        Enum.map(list, fn
          %{"id" => id, "label" => label} -> %{"id" => to_string(id), "label" => to_string(label)}
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  @doc """
  Parses extra_values JSON string to map of column_id => value.
  """
  def parse_extra_values(nil), do: %{}
  def parse_extra_values(""), do: %{}

  def parse_extra_values(str) when is_binary(str) do
    case Jason.decode(str) do
      {:ok, map} when is_map(map) ->
        Map.new(map, fn {k, v} -> {to_string(k), v && to_string(v)} end)

      _ ->
        %{}
    end
  end

  @doc """
  Adds a dynamic column to an ujian. Label is the column header.
  Returns {:ok, ujian} or {:error, changeset}.
  """
  def add_column_to_ujian(ujian_id, label) when is_binary(label) and label != "" do
    ujian = get_ujian(ujian_id)

    if is_nil(ujian),
      do: {:error, :not_found},
      else: do_add_column(ujian, String.trim(label))
  end

  def add_column_to_ujian(_, _), do: {:error, :invalid_label}

  defp do_add_column(%UjianPenerimaanPengguna{} = ujian, label) do
    list = parse_extra_columns(ujian.extra_columns)
    id = Ecto.UUID.generate()
    new_list = list ++ [%{"id" => id, "label" => label}]
    json = Jason.encode!(new_list)

    ujian
    |> Ecto.Changeset.change(%{extra_columns: json})
    |> Repo.update()
  end

  @doc """
  Removes a dynamic column from an ujian. Also clears that column's values from all kes.
  """
  def remove_column_from_ujian(ujian_id, column_id) when is_binary(column_id) do
    ujian = get_ujian(ujian_id)

    if is_nil(ujian),
      do: {:error, :not_found},
      else: do_remove_column(ujian, column_id)
  end

  def remove_column_from_ujian(_, _), do: {:error, :invalid_column_id}

  defp do_remove_column(%UjianPenerimaanPengguna{} = ujian, column_id) do
    list = parse_extra_columns(ujian.extra_columns) |> Enum.reject(&(&1["id"] == column_id))
    json = Jason.encode!(list)

    case ujian
         |> Ecto.Changeset.change(%{extra_columns: json})
         |> Repo.update() do
      {:ok, updated} ->
        # Clear this column from all kes under this ujian
        kes_list = Repo.preload(updated, :kes_ujian).kes_ujian

        Enum.each(kes_list, fn kes ->
          vals = parse_extra_values(kes.extra_values)
          vals = Map.delete(vals, column_id)

          kes
          |> Ecto.Changeset.change(%{extra_values: Jason.encode!(vals)})
          |> Repo.update()
        end)

        {:ok, get_ujian(updated.id)}

      err ->
        err
    end
  end

  @doc """
  Updates a single extra (dynamic) column value for a kes.
  """
  def update_kes_extra_value(kes_id, column_id, value) when is_binary(column_id) do
    kes = get_kes(kes_id)

    if is_nil(kes),
      do: {:error, :not_found},
      else: do_update_kes_extra(kes, column_id, value)
  end

  def update_kes_extra_value(_, _, _), do: {:error, :invalid}

  defp do_update_kes_extra(%KesUjian{} = kes, column_id, value) do
    vals = parse_extra_values(kes.extra_values) |> Map.put(column_id, value || "")

    kes
    |> Ecto.Changeset.change(%{extra_values: Jason.encode!(vals)})
    |> Repo.update()
  end

  @doc """
  Formats ujian struct for LiveView display.
  Maps kes_ujian to senarai_kes_ujian and ensures kes has id (for compatibility).
  Includes extra_columns and each kes extra_values for dynamic table columns.
  """
  def format_ujian_for_display(%UjianPenerimaanPengguna{} = ujian) do
    ujian = Repo.preload(ujian, :kes_ujian)
    extra_columns = parse_extra_columns(ujian.extra_columns)

    kes_formatted =
      Enum.map(ujian.kes_ujian, fn kes ->
        extra_vals = parse_extra_values(kes.extra_values)

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
          disahkan: (kes.disahkan_oleh || "") != "",
          extra_values: extra_vals
        }
      end)

    %{
      id: ujian.id,
      tajuk: ujian.tajuk,
      modul: ujian.modul,
      no_ujian: ujian.no_ujian,
      tarikh_ujian: ujian.tarikh_ujian,
      tarikh_dijangka_siap: ujian.tarikh_dijangka_siap,
      status: ujian.status,
      penguji: ujian.penguji,
      hasil: ujian.hasil,
      catatan: ujian.catatan,
      extra_columns: extra_columns,
      senarai_kes_ujian: kes_formatted
    }
  end
end
