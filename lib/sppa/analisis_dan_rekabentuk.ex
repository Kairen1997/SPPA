defmodule Sppa.AnalisisDanRekabentuk do
  @moduledoc """
  The AnalisisDanRekabentuk context.
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.AnalisisDanRekabentuk.AnalisisDanRekabentuk
  alias Sppa.AnalisisDanRekabentuk.Module
  alias Sppa.AnalisisDanRekabentuk.Function
  alias Sppa.AnalisisDanRekabentuk.SubFunction

  @doc """
  Returns the list of analisis_dan_rekabentuk for a user scope.
  """
  def list_analisis_dan_rekabentuk(current_scope) do
    AnalisisDanRekabentuk
    |> where([a], a.user_id == ^current_scope.user.id)
    |> preload([:project, :user, modules: [:functions]])
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single analisis_dan_rekabentuk.

  Raises `Ecto.NoResultsError` if the Analisis Dan Rekabentuk does not exist.
  """
  def get_analisis_dan_rekabentuk!(id, current_scope) do
    AnalisisDanRekabentuk
    |> where([a], a.id == ^id and a.user_id == ^current_scope.user.id)
    |> preload([:project, :user, modules: [functions: :sub_functions]])
    |> Repo.one!()
  end

  @doc """
  Gets a single analisis_dan_rekabentuk by id and scope.

  Returns nil if not found (does not raise).
  """
  def get_analisis_dan_rekabentuk(id, current_scope) when not is_nil(id) do
    AnalisisDanRekabentuk
    |> where([a], a.id == ^id and a.user_id == ^current_scope.user.id)
    |> preload([:project, :user, modules: [functions: :sub_functions]])
    |> Repo.one()
  end

  def get_analisis_dan_rekabentuk(_id, _current_scope), do: nil

  @doc """
  Gets a single analisis_dan_rekabentuk by project_id.

  Returns nil if not found.
  """
  def get_analisis_dan_rekabentuk_by_project(project_id, current_scope) do
    AnalisisDanRekabentuk
    |> where([a], a.project_id == ^project_id and a.user_id == ^current_scope.user.id)
    |> preload([:project, :user, modules: [functions: :sub_functions]])
    |> Repo.one()
  end

  @doc """
  Gets the latest analisis_dan_rekabentuk for a project, regardless of who created it.

  This is used for project-level views where we want to show whatever
  analisis_dan_rekabentuk has been filled in for the project, even if it
  was created by a different user.

  Returns nil if not found.
  """
  def get_analisis_dan_rekabentuk_by_project_for_display(project_id, _current_scope) do
    AnalisisDanRekabentuk
    |> where([a], a.project_id == ^project_id)
    |> preload([:project, :user, modules: [functions: :sub_functions]])
    |> order_by([a], desc: a.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Returns modules (nama modul, versi, fungsi modul) from Analisis dan Rekabentuk
  for use on the Pembangunan (Pengaturcaraan) page.

  Uses the user's most recent analisis_dan_rekabentuk document. Each module
  includes the document version (versi). Fields not stored in Analisis dan
  Rekabentuk (priority, status, tarikh_mula, tarikh_jangka_siap, catatan) are
  set to defaults so the Pembangunan UI can display the list.
  """
  def list_modules_for_pembangunan(current_scope) do
    analisis =
      AnalisisDanRekabentuk
      |> where([a], a.user_id == ^current_scope.user.id)
      |> preload([modules: [functions: :sub_functions]])
      |> order_by([a], desc: a.inserted_at)
      |> limit(1)
      |> Repo.one()

    if analisis do
      versi = analisis.versi || "1.0.0"

      analisis.modules
      |> Enum.sort_by(& &1.number)
      |> Enum.map(fn module ->
        functions =
          module.functions
          |> Enum.map(fn function ->
            sub_functions =
              (function.sub_functions || [])
              |> Enum.map(fn sub -> %{id: "sub_#{sub.id}", name: sub.name || ""} end)

            %{
              id: "func_#{function.id}",
              name: function.name || "",
              sub_functions: sub_functions
            }
          end)

        %{
          id: "module_#{module.id}",
          number: module.number,
          name: module.name || "",
          version: versi,
          priority: nil,
          status: "Belum Mula",
          tarikh_mula: nil,
          tarikh_jangka_siap: nil,
          catatan: nil,
          functions: functions
        }
      end)
    else
      []
    end
  end

  @doc """
  Creates an analisis_dan_rekabentuk with modules, functions, and sub_functions.
  """
  def create_analisis_dan_rekabentuk(attrs, current_scope) do
    # Extract modules data from attrs
    modules_data = Map.get(attrs, :modules, []) || Map.get(attrs, "modules", [])

    # Prepare main record attrs
    main_attrs =
      attrs
      |> Map.put_new(:user_id, current_scope.user.id)
      |> Map.drop([:modules, "modules"])

    Repo.transaction(fn ->
      # Create main record
      changeset = AnalisisDanRekabentuk.changeset(%AnalisisDanRekabentuk{}, main_attrs)

      case Repo.insert(changeset) do
        {:ok, analisis_dan_rekabentuk} ->
          # Create modules with their functions and sub_functions
          create_modules_with_children(analisis_dan_rekabentuk.id, modules_data)
          # Reload with associations
          Repo.preload(analisis_dan_rekabentuk, [modules: [functions: :sub_functions]])

        error ->
          Repo.rollback(error)
      end
    end)
  end

  @doc """
  Updates an analisis_dan_rekabentuk with modules, functions, and sub_functions.
  """
  def update_analisis_dan_rekabentuk(%AnalisisDanRekabentuk{} = analisis_dan_rekabentuk, attrs) do
    # Extract modules data from attrs
    modules_data = Map.get(attrs, :modules, []) || Map.get(attrs, "modules", [])

    # Prepare main record attrs
    main_attrs = Map.drop(attrs, [:modules, "modules"])

    Repo.transaction(fn ->
      # Update main record
      changeset = AnalisisDanRekabentuk.changeset(analisis_dan_rekabentuk, main_attrs)

      case Repo.update(changeset) do
        {:ok, updated} ->
          # Delete existing modules (cascade will delete functions and sub_functions)
          Repo.delete_all(
            from(m in Module, where: m.analisis_dan_rekabentuk_id == ^updated.id)
          )

          # Create new modules with their functions and sub_functions
          create_modules_with_children(updated.id, modules_data)
          # Reload with associations
          Repo.preload(updated, [modules: [functions: :sub_functions]])

        error ->
          Repo.rollback(error)
      end
    end)
  end

  @doc """
  Deletes an analisis_dan_rekabentuk.
  """
  def delete_analisis_dan_rekabentuk(%AnalisisDanRekabentuk{} = analisis_dan_rekabentuk) do
    Repo.delete(analisis_dan_rekabentuk)
  end

  @doc """
  Returns analisis data formatted for display on the project tab (e.g. projek/:id?tab=analisis-dan-rekabentuk).

  Loads the latest analisis_dan_rekabentuk for the project from the database. Returns nil if none exists.
  Dates are formatted as DD/MM/YYYY for display.
  """
  def analisis_for_tab_display(project_id, current_scope) when is_integer(project_id) do
    case get_analisis_dan_rekabentuk_by_project_for_display(project_id, current_scope) do
      nil -> nil
      analisis -> analisis_to_display_format(analisis)
    end
  end

  def analisis_for_tab_display(_project_id, _current_scope), do: nil

  defp analisis_to_display_format(analisis_dan_rekabentuk) do
    base = to_liveview_format(analisis_dan_rekabentuk)

    base
    |> Map.put(:tarikh_semakan, format_date_for_display(base.tarikh_semakan))
    |> Map.put(:prepared_by_date, format_date_for_display(base.prepared_by_date))
    |> Map.put(:approved_by_date, format_date_for_display(base.approved_by_date))
  end

  defp format_date_for_display(nil), do: ""

  defp format_date_for_display(%Date{} = date) do
    day = date.day |> to_string() |> String.pad_leading(2, "0")
    month = date.month |> to_string() |> String.pad_leading(2, "0")
    "#{day}/#{month}/#{date.year}"
  end

  @doc """
  Converts a analisis_dan_rekabentuk from database to the format expected by the LiveView.
  """
  def to_liveview_format(%AnalisisDanRekabentuk{} = analisis_dan_rekabentuk) do
    modules =
      analisis_dan_rekabentuk.modules
      |> Enum.sort_by(& &1.number)
      |> Enum.map(fn module ->
        functions =
          module.functions
          |> Enum.map(fn function ->
            sub_functions =
              function.sub_functions
              |> Enum.map(fn sub_func ->
                %{
                  id: "sub_#{sub_func.id}",
                  name: sub_func.name || ""
                }
              end)

            %{
              id: "func_#{function.id}",
              name: function.name || "",
              sub_functions: sub_functions
            }
          end)

        %{
          id: "module_#{module.id}",
          number: module.number,
          name: module.name || "",
          functions: functions
        }
      end)

    %{
      id: analisis_dan_rekabentuk.id,
      document_id: analisis_dan_rekabentuk.document_id || "JPKN-BPA-01/B2",
      nama_projek: analisis_dan_rekabentuk.nama_projek || "",
      nama_agensi: analisis_dan_rekabentuk.nama_agensi || "",
      versi: analisis_dan_rekabentuk.versi || "",
      tarikh_semakan: analisis_dan_rekabentuk.tarikh_semakan,
      rujukan_perubahan: analisis_dan_rekabentuk.rujukan_perubahan || "",
      prepared_by_name: analisis_dan_rekabentuk.prepared_by_name || "",
      prepared_by_position: analisis_dan_rekabentuk.prepared_by_position || "",
      prepared_by_date: analisis_dan_rekabentuk.prepared_by_date,
      approved_by_name: analisis_dan_rekabentuk.approved_by_name || "",
      approved_by_position: analisis_dan_rekabentuk.approved_by_position || "",
      approved_by_date: analisis_dan_rekabentuk.approved_by_date,
      modules: modules
    }
  end

  @doc """
  Converts LiveView format to database format.
  """
  def from_liveview_format(attrs) do
    modules = Map.get(attrs, :modules, []) || Map.get(attrs, "modules", [])

    %{
      document_id: Map.get(attrs, :document_id, "JPKN-BPA-01/B2"),
      nama_projek: Map.get(attrs, :nama_projek, ""),
      nama_agensi: Map.get(attrs, :nama_agensi, ""),
      versi: Map.get(attrs, :versi, ""),
      tarikh_semakan: Map.get(attrs, :tarikh_semakan),
      rujukan_perubahan: Map.get(attrs, :rujukan_perubahan, ""),
      prepared_by_name: Map.get(attrs, :prepared_by_name, ""),
      prepared_by_position: Map.get(attrs, :prepared_by_position, ""),
      prepared_by_date: Map.get(attrs, :prepared_by_date),
      approved_by_name: Map.get(attrs, :approved_by_name, ""),
      approved_by_position: Map.get(attrs, :approved_by_position, ""),
      approved_by_date: Map.get(attrs, :approved_by_date),
      modules: modules
    }
  end

  # Helper function to create modules with their functions and sub_functions
  defp create_modules_with_children(analisis_dan_rekabentuk_id, modules_data) when is_list(modules_data) do
    Enum.each(modules_data, fn module_data ->
      module_attrs = %{
        number: get_integer(module_data, :number) || get_integer(module_data, "number"),
        name: get_string(module_data, :name) || get_string(module_data, "name") || "",
        analisis_dan_rekabentuk_id: analisis_dan_rekabentuk_id
      }

      case Repo.insert(Module.changeset(%Module{}, module_attrs)) do
        {:ok, module} ->
          # Create functions for this module
          functions_data = Map.get(module_data, :functions, []) || Map.get(module_data, "functions", [])

          Enum.each(functions_data, fn function_data ->
            function_attrs = %{
              name: get_string(function_data, :name) || get_string(function_data, "name") || "",
              analisis_dan_rekabentuk_module_id: module.id
            }

            case Repo.insert(Function.changeset(%Function{}, function_attrs)) do
              {:ok, function} ->
                # Create sub_functions for this function
                sub_functions_data =
                  Map.get(function_data, :sub_functions, []) ||
                    Map.get(function_data, "sub_functions", [])

                Enum.each(sub_functions_data, fn sub_function_data ->
                  sub_function_attrs = %{
                    name:
                      get_string(sub_function_data, :name) ||
                        get_string(sub_function_data, "name") || "",
                    analisis_dan_rekabentuk_function_id: function.id
                  }

                  Repo.insert(SubFunction.changeset(%SubFunction{}, sub_function_attrs))
                end)

              _ ->
                :ok
            end
          end)

        _ ->
          :ok
      end
    end)
  end

  defp create_modules_with_children(_, _), do: :ok

  # Helper functions to safely extract values from maps
  defp get_string(map, key) when is_atom(key) do
    case Map.get(map, key) do
      nil -> Map.get(map, to_string(key))
      val when is_binary(val) -> val
      val -> to_string(val)
    end
  end

  defp get_string(map, key) when is_binary(key) do
    case Map.get(map, key) do
      nil -> Map.get(map, String.to_existing_atom(key))
      val when is_binary(val) -> val
      val -> to_string(val)
    end
  rescue
    ArgumentError -> nil
  end

  defp get_integer(map, key) when is_atom(key) do
    case Map.get(map, key) do
      nil -> get_integer(map, to_string(key))
      val when is_integer(val) -> val
      val when is_binary(val) -> parse_integer(val)
      _ -> nil
    end
  end

  defp get_integer(map, key) when is_binary(key) do
    case Map.get(map, key) do
      nil ->
        try do
          get_integer(map, String.to_existing_atom(key))
        rescue
          ArgumentError -> nil
        end

      val when is_integer(val) ->
        val

      val when is_binary(val) ->
        parse_integer(val)

      _ ->
        nil
    end
  end

  defp parse_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  # Keep the original pdf_data function for backward compatibility
  @doc """
  Returns a structured map used by the printable preview.

  Options:
  - `:document_id` - defaults to "JPKN-BPA-01/B2"
  - `:nama_projek` - defaults to "Sistem Pengurusan Permohonan Aplikasi (SPPA)"
  - `:nama_agensi` - defaults to "Jabatan Pendaftaran Negara Sabah (JPKN)"
  - `:versi` - defaults to "1.0.0"
  - `:tarikh_semakan` - defaults to today's date (DD/MM/YYYY)
  - `:rujukan_perubahan` - default dummy reference string
  - `:modules` - defaults to `initial_modules/0`
  - `:prepared_by_*` / `:approved_by_*`
  """
  def pdf_data(opts \\ []) do
    modules = Keyword.get(opts, :modules, initial_modules())

    today =
      Date.utc_today()
      |> Date.to_string()
      |> String.split("-")
      |> Enum.reverse()
      |> Enum.join("/")

    %{
      document_id: Keyword.get(opts, :document_id, "JPKN-BPA-01/B2"),
      nama_projek:
        Keyword.get(opts, :nama_projek, "Sistem Pengurusan Permohonan Aplikasi (SPPA)"),
      nama_agensi: Keyword.get(opts, :nama_agensi, "Jabatan Pendaftaran Negara Sabah (JPKN)"),
      versi: Keyword.get(opts, :versi, "1.0.0"),
      tarikh_semakan: Keyword.get(opts, :tarikh_semakan, today),
      rujukan_perubahan:
        Keyword.get(
          opts,
          :rujukan_perubahan,
          "Mesyuarat Jawatankuasa Teknologi Maklumat - 15 Disember 2024"
        ),
      modules: modules,
      total_modules: length(modules),
      total_functions:
        modules
        |> Enum.map(fn module -> length(module.functions) end)
        |> Enum.sum(),
      prepared_by_name: Keyword.get(opts, :prepared_by_name, "Ahmad bin Abdullah"),
      prepared_by_position: Keyword.get(opts, :prepared_by_position, "Pengurus Projek"),
      prepared_by_date: Keyword.get(opts, :prepared_by_date, today),
      approved_by_name: Keyword.get(opts, :approved_by_name, "Dr. Siti binti Hassan"),
      approved_by_position: Keyword.get(opts, :approved_by_position, "Ketua Penolong Pengarah"),
      approved_by_date: Keyword.get(opts, :approved_by_date, today)
    }
  end

  @doc "Default module/function structure used as a starting point."
  def initial_modules do
    [
      %{
        id: "module_1",
        number: 1,
        name: "Modul Pengurusan Pengguna",
        functions: [
          %{
            id: "func_1_1",
            name: "Pendaftaran Pengguna",
            sub_functions: [%{id: "sub_1_1_1", name: "Pengesahan Pendaftaran"}]
          },
          %{id: "func_1_2", name: "Laman Log Masuk", sub_functions: []},
          %{
            id: "func_1_3",
            name: "Penyelenggaraan Profail",
            sub_functions: [%{id: "sub_1_3_1", name: "Pengemaskinian Profil"}]
          }
        ]
      },
      %{
        id: "module_2",
        number: 2,
        name: "Penyelenggaraan Kata Laluan",
        functions: []
      },
      %{
        id: "module_3",
        number: 3,
        name: "Modul Permohonan",
        functions: [
          %{id: "func_3_1", name: "Pendaftaran Permohonan", sub_functions: []},
          %{id: "func_3_2", name: "Kemaskini Permohonan", sub_functions: []},
          %{id: "func_3_3", name: "Semakan Status Permohonan", sub_functions: []}
        ]
      },
      %{
        id: "module_4",
        number: 4,
        name: "Modul Pengurusan Permohonan",
        functions: [
          %{id: "func_4_1", name: "Verifikasi Permohonan", sub_functions: []},
          %{id: "func_4_2", name: "Kelulusan Permohonan", sub_functions: []}
        ]
      },
      %{
        id: "module_5",
        number: 5,
        name: "Modul Laporan",
        functions: [
          %{id: "func_5_1", name: "Laporan mengikut tahun", sub_functions: []},
          %{id: "func_5_2", name: "Laporan mengikut lokasi/daerah", sub_functions: []}
        ]
      },
      %{
        id: "module_6",
        number: 6,
        name: "Modul Dashboard",
        functions: []
      }
    ]
  end
end
