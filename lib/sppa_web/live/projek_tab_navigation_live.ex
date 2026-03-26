defmodule SppaWeb.ProjekTabNavigationLive do
  use SppaWeb, :live_view

  alias Sppa.ActivityLogs
  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.Penempatans
  alias Sppa.Penyerahans
  alias Sppa.PermohonanPerubahan
  alias Sppa.Projects
  alias Sppa.ProjectModules
  alias Sppa.SoalSelidiks
  alias Sppa.UjianKeselamatan
  alias Sppa.UjianPenerimaanPengguna
  alias Sppa.Maklumbalas
  alias Sppa.ModulPengaturcaraan
  alias Sppa.GanttData

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah", "ketua unit"]
  @module_page_size 10

  @tab_slug_to_label %{
    "soal-selidik" => "Soal Selidik",
    "analisis-dan-rekabentuk" => "Analisis dan Rekabentuk",
    "jadual-projek" => "Jadual Projek",
    "pengaturcaraan" => "Pengaturcaraan",
    "pengurus-perubahan" => "Pengurus Perubahan",
    "uat" => "UAT",
    "ujian-keselamatan" => "Ujian Keselamatan",
    "penempatan" => "Penempatan",
    "penyerahan" => "Penyerahan",
    "maklumbalas-pelanggan" => "Maklumbalas Pelanggan"
  }

  # Helpers for Pengaturcaraan tab (assigned modul + Gantt)
  def pengaturcaraan_status_color("in_progress"),
    do: "bg-blue-100 text-blue-800 border border-blue-200"

  def pengaturcaraan_status_color("done"),
    do: "bg-green-100 text-green-800 border border-green-200"

  def pengaturcaraan_status_color(_), do: "bg-gray-100 text-gray-800 border border-gray-200"

  def pengaturcaraan_status_label("in_progress"), do: "Dalam Proses"
  def pengaturcaraan_status_label("done"), do: "Selesai"
  def pengaturcaraan_status_label(_), do: "Dalam Proses"

  def pengaturcaraan_priority_color("high"), do: "bg-orange-100 text-orange-800 border-orange-200"
  def pengaturcaraan_priority_color("medium"), do: "bg-amber-100 text-amber-800 border-amber-200"
  def pengaturcaraan_priority_color("low"), do: "bg-pink-100 text-pink-800 border-pink-200"
  def pengaturcaraan_priority_color(_), do: "bg-gray-100 text-gray-800 border-gray-200"

  def pengaturcaraan_priority_label("high"), do: "Tinggi"
  def pengaturcaraan_priority_label("medium"), do: "Sederhana"
  def pengaturcaraan_priority_label("low"), do: "Rendah"
  def pengaturcaraan_priority_label(_), do: "Sederhana"

  def pengaturcaraan_days_between(start_date, end_date), do: Date.diff(end_date, start_date) + 1

  @impl true
  def mount(params_or_uri, session, socket) do
    params = ensure_params_map(params_or_uri)
    do_mount(params, session, socket)
  end

  defp ensure_params_map(%{} = params), do: params

  defp ensure_params_map(uri_string) when is_binary(uri_string) do
    # Some code paths pass the request URL as the first argument; extract id from path
    case Regex.run(~r{/projek/(\d+)(?:/|$)}, uri_string) do
      [_, id] -> %{"id" => id}
      _ -> %{}
    end
  end

  defp do_mount(%{"id" => id}, _session, socket) when is_binary(id) do
    project_id = String.to_integer(id)

    # Verify user has required role
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Load project
      project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)

      if project do
        # Load soal selidik data for this project
        # Untuk paparan di tab projek, kita mahu tunjukkan apa sahaja
        # soal selidik yang telah diisi untuk projek ini (tidak kira siapa
        # yang mengisi), selagi pengguna yang melihat mempunyai peranan yang
        # dibenarkan untuk projek tersebut.
        #
        # Fungsi context akan cuba:
        # 1. Cari berdasarkan project_id
        # 2. Jika tiada, padankan berdasarkan nama sistem (nama projek) – ini
        #    meliputi rekod lama yang belum mempunyai project_id.
        soal_selidik =
          SoalSelidiks.get_soal_selidik_for_project_or_by_name(
            project,
            socket.assigns.current_scope
          )

        # Debug logging
        require Logger
        Logger.info("=== PROJEK TAB NAVIGATION DEBUG ===")
        Logger.info("Project ID: #{project.id}")
        Logger.info("Project Nama: #{project.nama}")

        soal_selidik_status =
          if soal_selidik do
            "YES - ID: #{soal_selidik.id}"
          else
            "NO"
          end

        Logger.info("Soal Selidik found: #{soal_selidik_status}")

        soal_selidik_pdf_data =
          if soal_selidik do
            data = SoalSelidiks.to_liveview_format(soal_selidik)
            Logger.info("PDF Data prepared: nama_sistem=#{data.nama_sistem}")
            Logger.info("fr_categories count: #{length(data.fr_categories)}")
            Logger.info("nfr_categories count: #{length(data.nfr_categories)}")
            data
          else
            Logger.info("No soal selidik found for project")
            nil
          end

        Logger.info("================================")

        activities =
          if connected?(socket) do
            socket.assigns.current_scope
            |> ActivityLogs.list_recent_activities(10)
            |> Enum.map(fn a ->
              Map.put(a, :action_label, ActivityLogs.action_label(a.action))
            end)
          else
            []
          end

        notifications_count = length(activities)

        analisis_pdf_data =
          AnalisisDanRekabentuk.analisis_for_tab_display(project_id, socket.assigns.current_scope)

        modules =
          AnalisisDanRekabentuk.list_modules_for_project(project_id, socket.assigns.current_scope)

        project_modules = ProjectModules.list_modules_by_project_id(project_id)

        # For Pengaturcaraan tab: show only modul assigned to current user (from Modul Projek page)
        developer_tasks =
          case socket.assigns.current_scope && socket.assigns.current_scope.user do
            %{role: "pembangun sistem", id: user_id} ->
              Enum.filter(project_modules, fn m -> m.developer_id == user_id end)

            %{role: "pengurus projek", id: user_id} ->
              Enum.filter(project_modules, fn m -> m.developer_id == user_id end)

            _ ->
              project_modules
          end

        project_pengaturcaraan_gantt_data =
          GanttData.build_project_gantt(project, developer_tasks)

        {jadual_gantt_data, jadual_month_labels} = prepare_jadual_data_for_project(project)

        perubahan = PermohonanPerubahan.list_by_project(project_id)
        penempatan = get_penempatan_for_project(project_id, socket.assigns.current_scope, project)
        penyerahan = get_penyerahan_for_project(project)
        ujian = build_uat_list(project_id, socket.assigns.current_scope)
        uat_per_page = 10
        uat_total = length(ujian)
        uat_total_pages = uat_total_pages(uat_total, uat_per_page)
        uat_page = 1
        uat_paginated_ujian = uat_paginate(ujian, uat_page, uat_per_page)
        senarai_nama_modul = AnalisisDanRekabentuk.list_module_names(socket.assigns.current_scope)

        senarai_nama_modul_ordered =
          socket.assigns.current_scope
          |> AnalisisDanRekabentuk.list_modules_id_name()
          |> Enum.map(& &1.name)

        # Tab "Ujian Keselamatan": data sama seperti bekas UjianKeselamatanLive
        ujian_keselamatan_rows =
          UjianKeselamatan.list_ujian_rows_for_project(
            project_id,
            socket.assigns.current_scope
          )

        {:ok,
         socket
         |> assign(:hide_root_header, true)
         |> assign(:page_title, "Butiran Projek")
         |> assign(:sidebar_open, false)
         |> assign(:notifications_open, false)
         |> assign(:profile_menu_open, false)
         |> assign(:show_settings_modal, false)
         |> assign(:show_notes_modal, false)
         |> assign(:notes_task, nil)
         |> assign(:notes_form, to_form(%{"text" => ""}, as: :notes))
         |> assign(:project, project)
         |> assign(:project_modules, project_modules)
         |> assign(:developer_tasks, developer_tasks)
         |> assign(:project_pengaturcaraan_gantt_data, project_pengaturcaraan_gantt_data)
         |> assign(:soal_selidik_pdf_data, soal_selidik_pdf_data)
         |> assign(:analisis_pdf_data, analisis_pdf_data)
         |> assign(:modules, modules)
         |> assign(:module_page_size, @module_page_size)
         |> assign(:module_page, 1)
         |> assign(:module_view_mode, "table")
         |> put_module_pagination_assigns()
         |> assign(:module_show_edit_modal, false)
         |> assign(:selected_module, nil)
         |> assign(:module_form, to_form(%{}, as: :module))
         |> assign(:jadual_gantt_data, jadual_gantt_data)
         |> assign(:jadual_month_labels, jadual_month_labels)
         |> assign(:jadual_get_status_color, &jadual_status_color/1)
         |> assign(:jadual_get_status_badge_class, &jadual_status_badge_class/1)
         |> assign(:perubahan, perubahan)
         |> assign(:show_ujian_modal, false)
         |> assign(:selected_ujian, nil)
         |> assign(:penempatan, penempatan)
         |> assign(:penyerahan, penyerahan)
         # Penyerahan tab state (modals & forms)
         |> assign(:penyerahan_show_create_modal, false)
         |> assign(:penyerahan_show_edit_modal, false)
         |> assign(:penyerahan_show_upload_modal, false)
         |> assign(:penyerahan_upload_target, "manual")
         |> assign(:penyerahan_editing_penyerahan, nil)
         |> assign(:penyerahan_selected_penyerahan, nil)
         |> assign(:penyerahan_uploading_penyerahan_id, nil)
         |> assign(:penyerahan_uploading_penyerahan, nil)
         |> assign(:penyerahan_form, to_form(%{}, as: :penyerahan))
         |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))
         |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))
         |> assign(:penyerahan_expanded_catatan, MapSet.new())
         |> assign(:ujian, ujian)
         |> assign(:uat_paginated_ujian, uat_paginated_ujian)
         |> assign(:uat_ujian_total, uat_total)
         |> assign(:uat_page, uat_page)
         |> assign(:uat_per_page, uat_per_page)
         |> assign(:uat_total_pages, uat_total_pages)
         |> assign(:uat_show_create_modal, false)
         |> assign(:uat_show_edit_modal, false)
         |> assign(:uat_show_edit_kes_modal, false)
         |> assign(:uat_show_add_kes_modal, false)
         |> assign(:uat_show_add_column_modal, false)
         |> assign(:uat_selected_ujian, nil)
         |> assign(:uat_selected_kes, nil)
         |> assign(:uat_editing_ujian, nil)
         |> assign(:uat_edit_row_status, nil)
         |> assign(:uat_expanded_ujian_id, nil)
         |> assign(:uat_expanded_ujian, nil)
         |> assign(:uat_add_kes_ujian_id, nil)
         |> assign(:uat_form, to_form(%{}, as: :ujian))
         |> assign(:uat_kes_form, to_form(%{}, as: :kes))
         |> assign(:uat_kes_column_form, to_form(%{}, as: :column))
         |> assign(:senarai_nama_modul, senarai_nama_modul)
         |> assign(:senarai_nama_modul_ordered, senarai_nama_modul_ordered)
         |> assign(:ujian_keselamatan, ujian_keselamatan_rows)
         |> assign(:kes_show_create_modal, false)
         |> assign(:kes_show_edit_modal, false)
         |> assign(:kes_show_edit_kes_modal, false)
         |> assign(:kes_selected_ujian, nil)
         |> assign(:kes_form, to_form(%{}, as: :ujian))
         |> assign(:kes_kes_form, to_form(%{}, as: :kes))
         |> assign(:kes_editing_ujian, nil)
         |> assign(:kes_editing_ujian_raw_id, nil)
         |> assign(:kes_selected_kes, nil)
         |> assign(:show_view_modal, false)
         |> assign(:show_edit_modal, false)
         |> assign(:show_create_modal, false)
         |> assign(:selected_perubahan, nil)
         |> assign(:form, to_form(%{}, as: :perubahan))
         |> assign(:penempatan_show_create_modal, false)
         |> assign(:penempatan_form, to_form(%{}, as: :penempatan))
         |> assign(:penempatan_mode, "create")
         |> assign(:penempatan_editing_id, nil)
         |> assign(:maklumbalas_list, [])
         |> assign(:maklumbalas_show_create_modal, false)
         |> assign(:maklumbalas_show_edit_modal, false)
         |> assign(:maklumbalas_editing, nil)
         |> assign(:maklumbalas_form, to_form(%{}, as: :maklumbalas))
         |> assign(:current_tab, "Soal Selidik")
         |> assign(:read_only_ketua_unit, user_role == "ketua unit")
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)
         |> allow_upload(:kes_file,
           accept: ~w(.pdf .doc .docx .xls .xlsx .png .jpg .jpeg .gif),
           max_entries: 1,
           max_file_size: 10_000_000
         )
         |> allow_upload(:kes_edit_file,
           accept: ~w(.pdf .doc .docx .xls .xlsx .png .jpg .jpeg .gif),
           max_entries: 1,
           max_file_size: 10_000_000
         )
         |> allow_upload(:maklumbalas_file,
           accept: ~w(.pdf .doc .docx .xls .xlsx .png .jpg .jpeg),
           max_entries: 1,
           max_file_size: 10_000_000
         )
         |> allow_upload(:penyerahan_manual,
           accept: ~w(.pdf .doc .docx),
           max_entries: 1,
           max_file_size: 10_000_000,
           chunk_size: 64_000
         )
         |> allow_upload(:penyerahan_surat,
           accept: ~w(.pdf .doc .docx),
           max_entries: 1,
           max_file_size: 10_000_000,
           chunk_size: 64_000
         )
         |> allow_upload(:uat_file,
           accept: ~w(.pdf .doc .docx),
           max_entries: 1,
           max_file_size: 10_000_000,
           chunk_size: 64_000
         )}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Projek tidak ditemui atau anda tidak mempunyai kebenaran untuk melihat projek ini."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/projek")

        {:ok, socket}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "Anda tidak mempunyai kebenaran untuk mengakses halaman ini."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:ok, socket}
    end
  end

  defp do_mount(_params, _session, socket) do
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:error, "Projek tidak ditemui.")
      |> Phoenix.LiveView.redirect(to: ~p"/projek")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    # Phoenix may pass uri as a string; ensure we have (params_map, uri_string)
    {params_map, uri_string} = normalize_params_uri(params, uri)
    current_tab = tab_from_params(params_map, uri_string)

    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    # Ketua unit cannot access Pengaturcaraan tab; redirect to Soal Selidik
    if user_role == "ketua unit" && current_tab == "Pengaturcaraan" do
      {:noreply,
       push_patch(socket, to: ~p"/projek/#{socket.assigns.project.id}?tab=soal-selidik")}
    else
      handle_params_continue(params_map, uri_string, current_tab, socket)
    end
  end

  defp handle_params_continue(params_map, _uri_string, current_tab, socket) do
    # Simpan fasa semasa projek berdasarkan tab yang dibuka (fasa di mana pembangun berada)
    if socket.assigns[:project] && current_tab do
      Projects.update_project_fasa(socket.assigns.project.id, current_tab)
    end

    # Refresh penempatan from DB when user switches to Penempatan or Maklumbalas Pelanggan tab
    socket =
      if current_tab in ["Penempatan", "Maklumbalas Pelanggan"] && socket.assigns[:project] do
        project = socket.assigns.project

        penempatan =
          get_penempatan_for_project(project.id, socket.assigns.current_scope, project)

        assign(socket, :penempatan, penempatan)
      else
        socket
      end

    # Muat senarai maklumbalas dari DB apabila tab Maklumbalas Pelanggan dibuka
    socket =
      if current_tab == "Maklumbalas Pelanggan" && socket.assigns[:project] do
        project_id = socket.assigns.project.id
        list = Maklumbalas.list_by_project_id(project_id)
        assign(socket, :maklumbalas_list, list)
      else
        socket
      end

    # Apabila pengguna membuka tab Maklumbalas Pelanggan, semak sama ada semua bahagian
    # dari Soal Selidik sehingga Maklumbalas Pelanggan telah lengkap; jika ya, kemas kini
    # status projek kepada "Selesai".
    socket =
      if current_tab == "Maklumbalas Pelanggan" && socket.assigns[:project] do
        project = socket.assigns.project

        if all_sections_soal_selidik_to_maklumbalas_complete?(socket) &&
             project.status != "Selesai" do
          project_struct = Projects.get_project_by_id(project.id)

          if project_struct do
            case Projects.update_project(
                   project_struct,
                   %{"status" => "Selesai"},
                   socket.assigns.current_scope
                 ) do
              {:ok, updated} ->
                socket
                |> assign(:project, Projects.format_project_for_display(updated))
                |> Phoenix.LiveView.put_flash(
                  :info,
                  "Semua bahagian telah lengkap. Projek telah ditandakan sebagai Selesai."
                )

              _ ->
                socket
            end
          else
            socket
          end
        else
          socket
        end
      else
        socket
      end

    # Refresh UAT list and pagination when user switches to UAT tab
    socket =
      if current_tab == "UAT" && socket.assigns[:project] &&
           is_nil(socket.assigns[:uat_selected_ujian]) do
        project_id = socket.assigns.project.id
        ujian = build_uat_list(project_id, socket.assigns.current_scope)
        per_page = socket.assigns[:uat_per_page] || 10
        total = length(ujian)
        tp = uat_total_pages(total, per_page)
        page = 1
        paginated = uat_paginate(ujian, page, per_page)

        socket
        |> assign(:ujian, ujian)
        |> assign(:uat_paginated_ujian, paginated)
        |> assign(:uat_ujian_total, total)
        |> assign(:uat_page, page)
        |> assign(:uat_total_pages, tp)
      else
        socket
      end

    # Refresh Ujian Keselamatan tab and load detail when ujian_id in params
    socket =
      if current_tab == "Ujian Keselamatan" && socket.assigns[:project] do
        project_id = socket.assigns.project.id

        ujian_list =
          UjianKeselamatan.list_ujian_rows_for_project(
            project_id,
            socket.assigns.current_scope
          )

        kes_selected =
          case params_map["ujian_id"] do
            nil ->
              nil

            id_str ->
              case Integer.parse(id_str) do
                {id, _} -> UjianKeselamatan.get_ujian_formatted(id)
                :error -> nil
              end
          end

        socket
        |> assign(:ujian_keselamatan, ujian_list)
        |> assign(:kes_selected_ujian, kes_selected)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:current_tab, current_tab)
     |> assign(:page_title, "Butiran Projek - #{current_tab}")}
  end

  defp normalize_params_uri(params, uri) when is_map(params) do
    {params, to_string(uri)}
  end

  defp normalize_params_uri(uri, params) when is_binary(uri) and is_map(params) do
    # Some code paths pass (uri, params) instead of (params, uri)
    {params, uri}
  end

  defp tab_from_params(params, uri_string) do
    slug =
      params["tab"] ||
        extract_tab_from_uri(uri_string)

    cond do
      slug && slug != "" ->
        Map.get(@tab_slug_to_label, slug, "Soal Selidik")

      String.ends_with?(uri_string, "/soal-selidik") ->
        "Soal Selidik"

      true ->
        "Soal Selidik"
    end
  end

  defp extract_tab_from_uri(uri_string) when is_binary(uri_string) do
    case URI.parse(uri_string) do
      %{query: nil} -> nil
      %{query: query} -> URI.decode_query(query)["tab"]
    end
  end

  # Semak sama ada semua bahagian dari tab Soal Selidik sehingga Maklumbalas Pelanggan
  # telah lengkap. Jika ya, projek layak ditandakan sebagai Selesai.
  defp all_sections_soal_selidik_to_maklumbalas_complete?(socket) do
    project = socket.assigns[:project]
    if is_nil(project), do: false, else: do_all_sections_complete?(socket, project)
  end

  defp do_all_sections_complete?(socket, _project) do
    soal_selidik_ok = socket.assigns[:soal_selidik_pdf_data] != nil
    # "Modul" completion is based on modul assigned by Pengurus Projek (ProjectModules),
    # not on Analisis & Rekabentuk modules.
    project_modules = socket.assigns[:project_modules] || []
    modules_ok = project_modules != []
    # Jadual Projek tab is display-only; do not require dates for completion.
    jadual_ok = true
    penempatan = socket.assigns[:penempatan] || []
    penempatan_ok = penempatan != []
    ujian = socket.assigns[:ujian] || []
    uat_ok = ujian != []

    pengaturcaraan_tasks = socket.assigns[:developer_tasks] || []
    pengaturcaraan_ok = pengaturcaraan_tasks != []

    ujian_keselamatan_rows = socket.assigns[:ujian_keselamatan] || []
    ujian_keselamatan_ok = ujian_keselamatan_rows != []

    penyerahan_list = socket.assigns[:penyerahan] || []
    penyerahan_ok = penyerahan_list != []

    maklumbalas_list = socket.assigns[:maklumbalas_list] || []
    maklumbalas_ok = maklumbalas_list != []

    soal_selidik_ok and
      modules_ok and
      jadual_ok and
      pengaturcaraan_ok and
      uat_ok and
      ujian_keselamatan_ok and
      penempatan_ok and
      penyerahan_ok and
      maklumbalas_ok
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end

  @impl true
  def handle_event("close_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, false)}
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply,
     socket
     |> update(:notifications_open, &(!&1))
     |> assign(:profile_menu_open, false)}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
  end

  @impl true
  def handle_event("toggle_profile_menu", _params, socket) do
    {:noreply,
     socket
     |> update(:profile_menu_open, &(!&1))
     |> assign(:notifications_open, false)}
  end

  @impl true
  def handle_event("close_profile_menu", _params, socket) do
    {:noreply, assign(socket, :profile_menu_open, false)}
  end

  @impl true
  def handle_event("open_notes_modal", params, socket) do
    task_id = params["task_id"] || params["task-id"]

    task =
      if task_id do
        Enum.find(socket.assigns.developer_tasks || [], fn t ->
          to_string(t.id) == to_string(task_id)
        end)
      else
        nil
      end

    if task do
      notes_value = Map.get(task, :notes) || task.notes || ""

      form =
        to_form(%{"text" => notes_value}, as: :notes)

      {:noreply,
       socket
       |> assign(:show_notes_modal, true)
       |> assign(:notes_task, task)
       |> assign(:notes_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_notes_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_notes_modal, false)
     |> assign(:notes_task, nil)}
  end

  @impl true
  def handle_event("save_notes", params, socket) do
    task = socket.assigns.notes_task
    notes_text = get_in(params, ["notes", "text"]) || ""

    if is_nil(task) do
      {:noreply, socket}
    else
      attrs = %{
        notes: if(notes_text == "", do: nil, else: notes_text)
      }

      case ProjectModules.update_module(task, attrs) do
        {:ok, _updated} ->
          project_id = socket.assigns.project.id
          project = socket.assigns.project

          project_modules =
            ProjectModules.list_modules_by_project_id(project_id)

          developer_tasks =
            case socket.assigns.current_scope && socket.assigns.current_scope.user do
              %{role: "pembangun sistem", id: user_id} ->
                Enum.filter(project_modules, fn m -> m.developer_id == user_id end)

              %{role: "pengurus projek", id: user_id} ->
                Enum.filter(project_modules, fn m -> m.developer_id == user_id end)

              _ ->
                project_modules
            end

          project_pengaturcaraan_gantt_data =
            GanttData.build_project_gantt(project, developer_tasks)

          {:noreply,
           socket
           |> assign(:project_modules, project_modules)
           |> assign(:developer_tasks, developer_tasks)
           |> assign(:project_pengaturcaraan_gantt_data, project_pengaturcaraan_gantt_data)
           |> assign(:show_notes_modal, false)
           |> assign(:notes_task, nil)
           |> assign(:notes_form, to_form(%{"text" => ""}, as: :notes))
           |> put_flash(:info, "Catatan berjaya disimpan.")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal menyimpan catatan. Sila cuba lagi.")}
      end
    end
  end

  @impl true
  def handle_event("open_settings_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_settings_modal, true)
     |> assign(:profile_menu_open, false)}
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :module_view_mode, view)}
  end

  @impl true
  def handle_event("go_to_page", %{"page" => page_str}, socket) do
    page =
      case Integer.parse(to_string(page_str)) do
        {p, ""} -> p
        _ -> socket.assigns.module_page || 1
      end

    socket =
      socket
      |> assign(:module_page, page)
      |> put_module_pagination_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_module_edit_modal", %{"module_id" => module_id}, socket) do
    module_id_str = to_string(module_id)

    module =
      Enum.find(socket.assigns.modules, fn m -> to_string(m.id) == module_id_str end) ||
        Enum.find(socket.assigns.module_paginated_modules || [], fn m ->
          to_string(m.id) == module_id_str
        end)

    if module do
      form_data = %{
        "priority" => module.priority || "",
        "status" => module.status || "Belum Mula",
        "tarikh_mula" =>
          if(module.tarikh_mula, do: Calendar.strftime(module.tarikh_mula, "%Y-%m-%d"), else: ""),
        "tarikh_jangka_siap" =>
          if(module.tarikh_jangka_siap,
            do: Calendar.strftime(module.tarikh_jangka_siap, "%Y-%m-%d"),
            else: ""
          ),
        "catatan" => module.catatan || ""
      }

      form = to_form(form_data, as: :module)

      {:noreply,
       socket
       |> assign(:module_show_edit_modal, true)
       |> assign(:selected_module, module)
       |> assign(:module_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_module_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:module_show_edit_modal, false)
     |> assign(:selected_module, nil)
     |> assign(:module_form, to_form(%{}, as: :module))}
  end

  @impl true
  def handle_event("update_module", %{"module" => module_params}, socket) do
    selected = socket.assigns.selected_module
    module_id_str = selected.id
    project_id = selected.project_id

    analisis_module_id =
      case module_id_str do
        "module_" <> id_str -> String.to_integer(id_str)
        _ -> nil
      end

    if is_nil(project_id) or is_nil(analisis_module_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Projek atau modul tidak sah.")
       |> assign(:module_show_edit_modal, false)
       |> assign(:selected_module, nil)}
    else
      tarikh_mula =
        if module_params["tarikh_mula"] && module_params["tarikh_mula"] != "" do
          case Date.from_iso8601(module_params["tarikh_mula"]) do
            {:ok, date} -> date
            _ -> nil
          end
        else
          nil
        end

      tarikh_jangka_siap =
        if module_params["tarikh_jangka_siap"] && module_params["tarikh_jangka_siap"] != "" do
          case Date.from_iso8601(module_params["tarikh_jangka_siap"]) do
            {:ok, date} -> date
            _ -> nil
          end
        else
          nil
        end

      attrs = %{
        keutamaan: module_params["priority"] || nil,
        status: module_params["status"] || "Belum Mula",
        tarikh_mula: tarikh_mula,
        tarikh_jangka_siap: tarikh_jangka_siap,
        catatan: if(module_params["catatan"] == "", do: nil, else: module_params["catatan"])
      }

      case ModulPengaturcaraan.upsert(project_id, analisis_module_id, attrs) do
        {:ok, _} ->
          modules =
            AnalisisDanRekabentuk.list_modules_for_project(
              project_id,
              socket.assigns.current_scope
            )

          {:noreply,
           socket
           |> assign(:modules, modules)
           |> assign(:module_page, 1)
           |> put_module_pagination_assigns()
           |> assign(:module_show_edit_modal, false)
           |> assign(:selected_module, nil)
           |> assign(:module_form, to_form(%{}, as: :module))
           |> put_flash(:info, "Modul berjaya dikemaskini")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal mengemaskini modul. Sila cuba lagi.")}
      end
    end
  end

  @impl true
  def handle_event("open_ujian_modal", %{"ujian_id" => ujian_id}, socket) do
    ujian_id_parsed = parse_ujian_id(to_string(ujian_id))
    ujian_struct = UjianPenerimaanPengguna.get_ujian(ujian_id_parsed)

    if ujian_struct do
      selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian_struct)

      {:noreply,
       socket
       |> assign(:show_ujian_modal, false)
       |> assign(:uat_selected_ujian, selected)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_ujian_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_ujian_modal, false)
     |> assign(:uat_selected_ujian, nil)}
  end

  @impl true
  def handle_event("uat_back_to_list", _params, socket) do
    {:noreply, assign(socket, :uat_selected_ujian, nil)}
  end

  @impl true
  def handle_event("uat_toggle_expand", params, socket) do
    # Accept both "ujian_id" and "ujian-id"; coerce to integer for consistent comparison
    raw_id = params["ujian_id"] || params["ujian-id"]
    id = raw_id && parse_ujian_id(to_string(raw_id))

    socket =
      if is_nil(id) do
        socket
      else
        current = socket.assigns[:uat_expanded_ujian_id]

        if current == id do
          socket
          |> assign(:uat_expanded_ujian_id, nil)
          |> assign(:uat_expanded_ujian, nil)
        else
          ujian_struct = UjianPenerimaanPengguna.get_ujian(id)

          if ujian_struct do
            formatted = UjianPenerimaanPengguna.format_ujian_for_display(ujian_struct)

            socket
            |> assign(:uat_expanded_ujian_id, id)
            |> assign(:uat_expanded_ujian, formatted)
          else
            socket
          end
        end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("uat_next_page", _params, socket) do
    %{uat_page: page, uat_total_pages: total_pages, uat_per_page: per_page, ujian: ujian} =
      socket.assigns

    new_page = min(page + 1, total_pages)
    paginated = uat_paginate(ujian, new_page, per_page)

    {:noreply,
     socket
     |> assign(:uat_page, new_page)
     |> assign(:uat_paginated_ujian, paginated)}
  end

  @impl true
  def handle_event("uat_prev_page", _params, socket) do
    %{uat_page: page, uat_per_page: per_page, ujian: ujian} = socket.assigns

    new_page = max(page - 1, 1)
    paginated = uat_paginate(ujian, new_page, per_page)

    {:noreply,
     socket
     |> assign(:uat_page, new_page)
     |> assign(:uat_paginated_ujian, paginated)}
  end

  @impl true
  def handle_event("uat_go_to_page", %{"page" => page_param}, socket) do
    %{uat_total_pages: total_pages, uat_per_page: per_page, ujian: ujian} = socket.assigns

    new_page =
      case Integer.parse(page_param) do
        {int, _} when int >= 1 and int <= total_pages -> int
        _ -> socket.assigns.uat_page
      end

    paginated = uat_paginate(ujian, new_page, per_page)

    {:noreply,
     socket
     |> assign(:uat_page, new_page)
     |> assign(:uat_paginated_ujian, paginated)}
  end

  @impl true
  def handle_event("open_uat_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:uat_show_create_modal, true)
     |> assign(:uat_form, to_form(%{}, as: :ujian))}
  end

  @impl true
  def handle_event("close_uat_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:uat_show_create_modal, false)
     |> assign(:uat_form, to_form(%{}, as: :ujian))}
  end

  @impl true
  def handle_event("open_uat_edit_modal", params, socket) do
    ujian_id = params["ujian_id"]
    # Status dari baris jadual (phx-value-status); fallback dari rekod
    row_status = params["status"] && to_string(params["status"])

    ujian_id_int = parse_ujian_id(ujian_id)

    ujian =
      if socket.assigns[:ujian] && length(socket.assigns.ujian) > 0 do
        Enum.find(socket.assigns.ujian, fn u -> u.id == ujian_id_int end)
      else
        UjianPenerimaanPengguna.get_ujian(ujian_id_int)
      end

    if ujian do
      # Status untuk form: guna nilai dari baris dahulu, else dari rekod (sumber sama dengan jadual)
      status_value =
        if is_binary(row_status) && String.trim(row_status) != "" do
          uat_status_normalize(row_status)
        else
          # Langsung dari rekod yang sama seperti lajur STATUS
          (Map.get(ujian, :status) || Map.get(ujian, "status") || "Dalam Progres")
          |> to_string()
          |> uat_status_normalize()
        end

      form_data = %{
        "tajuk" => ujian.tajuk,
        "modul" => ujian.modul,
        "no_ujian" => ujian.no_ujian || "",
        "tarikh_ujian" => Calendar.strftime(ujian.tarikh_ujian, "%Y-%m-%d"),
        "tarikh_dijangka_siap" => Calendar.strftime(ujian.tarikh_dijangka_siap, "%Y-%m-%d"),
        "status" => status_value,
        "penguji" => ujian.penguji || "",
        "hasil" => ujian.hasil || "",
        "catatan" => ujian.catatan || ""
      }

      form = to_form(form_data, as: :ujian)

      {:noreply,
       socket
       |> assign(:uat_show_edit_modal, true)
       |> assign(:uat_editing_ujian, ujian)
       |> assign(:uat_edit_row_status, row_status)
       |> assign(:uat_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_uat_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:uat_show_edit_modal, false)
     |> assign(:uat_editing_ujian, nil)
     |> assign(:uat_edit_row_status, nil)
     |> assign(:uat_form, to_form(%{}, as: :ujian))}
  end

  @impl true
  def handle_event("validate_uat_ujian", %{"ujian" => ujian_params}, socket) do
    ujian_params =
      if socket.assigns[:uat_show_create_modal] do
        modul = (ujian_params["modul"] || "") |> to_string() |> String.trim()

        no_ujian =
          if modul != "",
            do: UjianPenerimaanPengguna.next_no_ujian(socket.assigns.project.id, modul),
            else: ""

        Map.put(ujian_params, "no_ujian", no_ujian)
      else
        ujian_params
      end

    form = to_form(ujian_params, as: :ujian)
    {:noreply, assign(socket, :uat_form, form)}
  end

  @impl true
  def handle_event("create_uat_ujian", %{"ujian" => ujian_params}, socket) do
    project_id = socket.assigns.project.id

    dokumen_ujian_path =
      consume_uploaded_entries(socket, :uat_file, fn %{path: path}, entry ->
        filename = kes_upload_filename(project_id, entry)
        dest_dir = Path.join(File.cwd!(), "priv/static/uploads/uat_ujian")
        File.mkdir_p!(dest_dir)
        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)
        # Simpan path relatif dari root static, supaya boleh dicapai melalui Plug.Static
        {:ok, "uploads/uat_ujian/#{filename}"}
      end)
      |> List.first()

    modul_name =
      ujian_params["modul"]
      |> to_string()
      |> String.trim()

    no_ujian_value =
      ujian_params["no_ujian"]
      |> to_string()
      |> String.trim()
      |> case do
        "" -> UjianPenerimaanPengguna.next_no_ujian(project_id, modul_name)
        value -> value
      end

    tajuk_default =
      modul_name
      |> then(fn name ->
        if name == "" do
          "Ujian Penerimaan Pengguna"
        else
          "Ujian Penerimaan Pengguna - #{name}"
        end
      end)

    attrs = %{
      project_id: project_id,
      tajuk: tajuk_default,
      modul: ujian_params["modul"],
      no_ujian: no_ujian_value,
      tarikh_ujian: uat_parse_date(ujian_params["tarikh_ujian"], Date.utc_today()),
      tarikh_dijangka_siap:
        uat_parse_date(ujian_params["tarikh_dijangka_siap"], Date.utc_today()),
      status: ujian_params["status"] || "Menunggu",
      penguji: uat_empty_to_nil(ujian_params["penguji"]),
      hasil: ujian_params["hasil"] || "Belum Selesai",
      catatan: uat_empty_to_nil(ujian_params["catatan"]),
      dokumen_ujian: dokumen_ujian_path,
      dokumen_ujian_nama:
        if(dokumen_ujian_path, do: kes_display_filename(dokumen_ujian_path), else: nil)
    }

    case UjianPenerimaanPengguna.create_ujian(attrs) do
      {:ok, _ujian} ->
        ujian = build_uat_list(project_id, socket.assigns.current_scope)
        per_page = socket.assigns.uat_per_page
        total = length(ujian)
        total_pages_val = uat_total_pages(total, per_page)
        page = 1
        paginated_ujian = uat_paginate(ujian, page, per_page)

        {:noreply,
         socket
         |> assign(:ujian, ujian)
         |> assign(:uat_paginated_ujian, paginated_ujian)
         |> assign(:uat_ujian_total, total)
         |> assign(:uat_page, page)
         |> assign(:uat_total_pages, total_pages_val)
         |> assign(:uat_show_create_modal, false)
         |> assign(:uat_form, to_form(%{}, as: :ujian))
         |> put_flash(:info, "Ujian penerimaan pengguna berjaya didaftarkan")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:uat_form, to_form(changeset, as: :ujian))
         |> put_flash(:error, "Gagal mendaftar. Sila semak maklumat.")}
    end
  end

  @impl true
  def handle_event("update_uat_ujian", %{"ujian" => ujian_params}, socket) do
    editing_ujian = socket.assigns[:uat_editing_ujian]

    if editing_ujian do
      project_id = socket.assigns.project.id

      dokumen_ujian_path =
        consume_uploaded_entries(socket, :uat_file, fn %{path: path}, entry ->
          filename = kes_upload_filename(project_id, entry)
          dest_dir = Path.join(File.cwd!(), "priv/static/uploads/uat_ujian")
          File.mkdir_p!(dest_dir)
          dest = Path.join(dest_dir, filename)
          File.cp!(path, dest)
          {:ok, "uploads/uat_ujian/#{filename}"}
        end)
        |> List.first()

      attrs = %{
        tajuk: ujian_params["tajuk"] || editing_ujian.tajuk,
        modul: ujian_params["modul"],
        no_ujian: uat_empty_to_nil(ujian_params["no_ujian"]) || editing_ujian.no_ujian,
        tarikh_ujian: uat_parse_date(ujian_params["tarikh_ujian"], editing_ujian.tarikh_ujian),
        tarikh_dijangka_siap:
          uat_parse_date(ujian_params["tarikh_dijangka_siap"], editing_ujian.tarikh_dijangka_siap),
        status: ujian_params["status"],
        penguji: uat_empty_to_nil(ujian_params["penguji"]),
        hasil: ujian_params["hasil"],
        catatan: uat_empty_to_nil(ujian_params["catatan"]),
        dokumen_ujian: dokumen_ujian_path || editing_ujian.dokumen_ujian,
        dokumen_ujian_nama:
          cond do
            dokumen_ujian_path ->
              kes_display_filename(dokumen_ujian_path)

            editing_ujian.dokumen_ujian_nama ->
              editing_ujian.dokumen_ujian_nama

            true ->
              editing_ujian.dokumen_ujian && kes_display_filename(editing_ujian.dokumen_ujian)
          end
      }

      case UjianPenerimaanPengguna.update_ujian(editing_ujian, attrs) do
        {:ok, _} ->
          ujian_id = editing_ujian.id
          project_id = socket.assigns.project.id

          updated_ujian_list = build_uat_list(project_id, socket.assigns.current_scope)

          per_page = socket.assigns.uat_per_page
          total = length(updated_ujian_list)
          tp = uat_total_pages(total, per_page)
          p = min(socket.assigns[:uat_page] || 1, max(tp, 1))
          paginated_ujian = uat_paginate(updated_ujian_list, p, per_page)

          updated_socket =
            socket
            |> assign(:ujian, updated_ujian_list)
            |> assign(:uat_paginated_ujian, paginated_ujian)
            |> assign(:uat_ujian_total, total)
            |> assign(:uat_page, p)
            |> assign(:uat_total_pages, tp)
            |> assign(:uat_show_edit_modal, false)
            |> assign(:uat_editing_ujian, nil)
            |> assign(:uat_edit_row_status, nil)
            |> assign(:uat_form, to_form(%{}, as: :ujian))
            |> put_flash(:info, "Ujian penerimaan pengguna berjaya dikemaskini")

          final_socket =
            if socket.assigns[:uat_selected_ujian] &&
                 socket.assigns.uat_selected_ujian.id == ujian_id do
              ujian = UjianPenerimaanPengguna.get_ujian(ujian_id)

              assign(
                updated_socket,
                :uat_selected_ujian,
                UjianPenerimaanPengguna.format_ujian_for_display(ujian)
              )
            else
              updated_socket
            end

          {:noreply, final_socket}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:uat_form, to_form(changeset, as: :ujian))
           |> put_flash(:error, "Gagal mengemaskini. Sila semak maklumat.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_kes_ujian", %{"kes_id" => kes_id}, socket) do
    kes_id_parsed = parse_kes_id(kes_id)

    senarai =
      cond do
        socket.assigns[:uat_selected_ujian] && socket.assigns.uat_selected_ujian.senarai_kes_ujian ->
          socket.assigns.uat_selected_ujian.senarai_kes_ujian

        socket.assigns[:uat_expanded_ujian] && socket.assigns.uat_expanded_ujian.senarai_kes_ujian ->
          socket.assigns.uat_expanded_ujian.senarai_kes_ujian

        true ->
          nil
      end

    if senarai do
      kes = Enum.find(senarai, fn k -> k.id == kes_id_parsed end)

      if kes do
        form_data = %{
          "senario" => kes.senario || "",
          "langkah" => kes.langkah || "",
          "keputusan_dijangka" => kes.keputusan_dijangka || "",
          "keputusan_sebenar" => kes.keputusan_sebenar || "",
          "hasil" => kes.hasil || "",
          "penguji" => Map.get(kes, :penguji, "") || "",
          "tarikh_ujian" =>
            if(kes.tarikh_ujian, do: Calendar.strftime(kes.tarikh_ujian, "%Y-%m-%d"), else: ""),
          "disahkan_oleh" => Map.get(kes, :disahkan_oleh, "") || "",
          "tarikh_pengesahan" =>
            if(kes.tarikh_pengesahan,
              do: Calendar.strftime(kes.tarikh_pengesahan, "%Y-%m-%d"),
              else: ""
            )
        }

        form = to_form(form_data, as: :kes)

        {:noreply,
         socket
         |> assign(:uat_show_edit_kes_modal, true)
         |> assign(:uat_selected_kes, kes)
         |> assign(:uat_kes_form, form)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_edit_kes_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:uat_show_edit_kes_modal, false)
     |> assign(:uat_selected_kes, nil)
     |> assign(:uat_kes_form, to_form(%{}, as: :kes))}
  end

  @impl true
  def handle_event("validate_kes", %{"kes" => kes_params}, socket) do
    form = to_form(kes_params, as: :kes)
    {:noreply, assign(socket, :uat_kes_form, form)}
  end

  @impl true
  def handle_event("update_kes", %{"kes" => kes_params}, socket) do
    kes_id = socket.assigns.uat_selected_kes.id
    kes_struct = UjianPenerimaanPengguna.get_kes(kes_id)

    if kes_struct do
      attrs = %{
        senario: kes_params["senario"],
        langkah: uat_empty_to_nil(kes_params["langkah"]),
        keputusan_dijangka: uat_empty_to_nil(kes_params["keputusan_dijangka"]),
        keputusan_sebenar: uat_empty_to_nil(kes_params["keputusan_sebenar"]),
        hasil: uat_empty_to_nil(kes_params["hasil"]),
        penguji: uat_empty_to_nil(kes_params["penguji"]),
        tarikh_ujian: uat_parse_date(kes_params["tarikh_ujian"], nil),
        disahkan_oleh: uat_empty_to_nil(kes_params["disahkan_oleh"]),
        tarikh_pengesahan: uat_parse_date(kes_params["tarikh_pengesahan"], nil)
      }

      case UjianPenerimaanPengguna.update_kes(kes_struct, attrs) do
        {:ok, _} ->
          ujian_id = kes_struct.ujian_penerimaan_pengguna_id
          ujian = UjianPenerimaanPengguna.get_ujian(ujian_id)
          selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

          socket =
            socket
            |> assign(:uat_selected_kes, nil)
            |> assign(:uat_show_edit_kes_modal, false)
            |> assign(:uat_kes_form, to_form(%{}, as: :kes))
            |> put_flash(:info, "Kes ujian berjaya dikemaskini")

          socket =
            if socket.assigns[:uat_selected_ujian] &&
                 socket.assigns.uat_selected_ujian.id == ujian_id do
              assign(socket, :uat_selected_ujian, selected)
            else
              socket
            end

          socket =
            if socket.assigns[:uat_expanded_ujian_id] == ujian_id do
              assign(socket, :uat_expanded_ujian, selected)
            else
              socket
            end

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:uat_kes_form, to_form(changeset, as: :kes))
           |> put_flash(:error, "Gagal mengemaskini kes. Sila semak maklumat.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_kes_ujian", %{"kes_id" => kes_id}, socket) do
    kes_struct = UjianPenerimaanPengguna.get_kes(parse_kes_id(kes_id))

    if kes_struct do
      ujian_id = kes_struct.ujian_penerimaan_pengguna_id

      case UjianPenerimaanPengguna.delete_kes(kes_struct) do
        {:ok, _} ->
          ujian = UjianPenerimaanPengguna.get_ujian(ujian_id)
          selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

          socket =
            socket
            |> assign(:uat_selected_kes, nil)
            |> assign(:uat_show_edit_kes_modal, false)
            |> put_flash(:info, "Kes ujian berjaya dipadam")

          socket =
            if socket.assigns[:uat_selected_ujian] &&
                 socket.assigns.uat_selected_ujian.id == ujian_id do
              assign(socket, :uat_selected_ujian, selected)
            else
              socket
            end

          socket =
            if socket.assigns[:uat_expanded_ujian_id] == ujian_id do
              assign(socket, :uat_expanded_ujian, selected)
            else
              socket
            end

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Gagal memadam kes ujian.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_add_kes_modal", params, socket) do
    default_kes = %{
      "senario" => "",
      "langkah" => "",
      "keputusan_dijangka" => "",
      "keputusan_sebenar" => "",
      "hasil" => "",
      "penguji" => "",
      "tarikh_ujian" => "",
      "disahkan_oleh" => "",
      "tarikh_pengesahan" => ""
    }

    ujian_id = if params["ujian_id"], do: parse_ujian_id(params["ujian_id"]), else: nil

    socket =
      socket
      |> assign(:uat_show_add_kes_modal, true)
      |> assign(:uat_kes_form, to_form(default_kes, as: :kes))
      |> then(fn s ->
        if ujian_id, do: assign(s, :uat_add_kes_ujian_id, ujian_id), else: s
      end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_add_kes_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:uat_show_add_kes_modal, false)
     |> assign(:uat_kes_form, to_form(%{}, as: :kes))
     |> assign(:uat_add_kes_ujian_id, nil)}
  end

  @impl true
  def handle_event("validate_add_kes", %{"kes" => kes_params}, socket) do
    form = to_form(kes_params, as: :kes)
    {:noreply, assign(socket, :uat_kes_form, form)}
  end

  @impl true
  def handle_event("create_kes", %{"kes" => kes_params}, socket) do
    parent_id =
      socket.assigns[:uat_add_kes_ujian_id] ||
        (socket.assigns[:uat_selected_ujian] && socket.assigns.uat_selected_ujian.id)

    if parent_id do
      parent_ujian = UjianPenerimaanPengguna.get_ujian(parent_id)

      selected_parent =
        parent_ujian && UjianPenerimaanPengguna.format_ujian_for_display(parent_ujian)

      senarai = (selected_parent && selected_parent.senarai_kes_ujian) || []

      new_number =
        senarai
        |> Enum.map(fn k ->
          kod = Map.get(k, :kod, k.id)
          kod_str = if is_binary(kod), do: kod, else: to_string(kod)

          case Regex.run(~r/REG-(\d+)/, kod_str) do
            [_, num_str] -> String.to_integer(num_str)
            _ -> 0
          end
        end)
        |> (fn list -> if list == [], do: [0], else: list end).()
        |> Enum.max()
        |> Kernel.+(1)

      kod = "REG-#{String.pad_leading(Integer.to_string(new_number), 3, "0")}"

      attrs = %{
        ujian_penerimaan_pengguna_id: parent_id,
        kod: kod,
        senario: kes_params["senario"] || "",
        langkah: uat_empty_to_nil(kes_params["langkah"]),
        keputusan_dijangka: uat_empty_to_nil(kes_params["keputusan_dijangka"]),
        keputusan_sebenar: uat_empty_to_nil(kes_params["keputusan_sebenar"]),
        hasil: uat_empty_to_nil(kes_params["hasil"]),
        penguji: uat_empty_to_nil(kes_params["penguji"]),
        tarikh_ujian: uat_parse_date(kes_params["tarikh_ujian"], nil),
        disahkan_oleh: uat_empty_to_nil(kes_params["disahkan_oleh"]),
        tarikh_pengesahan: uat_parse_date(kes_params["tarikh_pengesahan"], nil)
      }

      case UjianPenerimaanPengguna.create_kes(attrs) do
        {:ok, _} ->
          ujian = UjianPenerimaanPengguna.get_ujian(parent_id)
          selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

          socket =
            socket
            |> assign(:uat_show_add_kes_modal, false)
            |> assign(:uat_kes_form, to_form(%{}, as: :kes))
            |> assign(:uat_add_kes_ujian_id, nil)
            |> put_flash(:info, "Kes ujian berjaya ditambah")

          socket =
            if socket.assigns[:uat_selected_ujian] &&
                 socket.assigns.uat_selected_ujian.id == parent_id do
              assign(socket, :uat_selected_ujian, selected)
            else
              socket
            end

          socket =
            if socket.assigns[:uat_expanded_ujian_id] == parent_id do
              assign(socket, :uat_expanded_ujian, selected)
            else
              socket
            end

          {:noreply, socket}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:uat_kes_form, to_form(changeset, as: :kes))
           |> put_flash(:error, "Gagal menambah kes. Sila semak maklumat.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_uat_add_column_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:uat_show_add_column_modal, true)
     |> assign(:uat_kes_column_form, to_form(%{"label" => ""}, as: :column))}
  end

  @impl true
  def handle_event("close_uat_add_column_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:uat_show_add_column_modal, false)
     |> assign(:uat_kes_column_form, to_form(%{}, as: :column))}
  end

  @impl true
  def handle_event("validate_uat_column", %{"column" => params}, socket) do
    {:noreply, assign(socket, :uat_kes_column_form, to_form(params, as: :column))}
  end

  @impl true
  def handle_event("add_uat_column", %{"column" => %{"label" => label}}, socket) do
    label = String.trim(label || "")
    ujian_id = socket.assigns[:uat_expanded_ujian_id]

    if label == "" do
      {:noreply,
       socket
       |> assign(:uat_kes_column_form, to_form(%{"label" => label}, as: :column))
       |> put_flash(:error, "Sila masukkan nama lajur.")}
    else
      if is_nil(ujian_id) do
        {:noreply,
         put_flash(socket, :error, "Sesi tidak sah. Sila kembangkan baris ujian dahulu.")}
      else
        case UjianPenerimaanPengguna.add_column_to_ujian(ujian_id, label) do
          {:ok, ujian} ->
            formatted = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

            {:noreply,
             socket
             |> assign(:uat_show_add_column_modal, false)
             |> assign(:uat_kes_column_form, to_form(%{}, as: :column))
             |> assign(:uat_expanded_ujian, formatted)
             |> put_flash(:info, "Lajur berjaya ditambah.")}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Gagal menambah lajur.")}
        end
      end
    end
  end

  @impl true
  def handle_event(
        "remove_uat_column",
        %{"column_id" => column_id, "ujian_id" => ujian_id_param},
        socket
      ) do
    ujian_id = parse_ujian_id(ujian_id_param)

    if ujian_id && column_id != "" do
      case UjianPenerimaanPengguna.remove_column_from_ujian(ujian_id, column_id) do
        {:ok, ujian} ->
          formatted = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

          {:noreply,
           socket
           |> assign(:uat_expanded_ujian, formatted)
           |> put_flash(:info, "Lajur telah dialih keluar.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Gagal mengalih keluar lajur.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "uat_update_kes_extra",
        %{"kes_id" => kes_id_param, "column_id" => column_id, "value" => value},
        socket
      ) do
    kes_id = parse_kes_id(kes_id_param)

    if kes_id && column_id != "" do
      case UjianPenerimaanPengguna.update_kes_extra_value(kes_id, column_id, value) do
        {:ok, _} ->
          ujian_id = socket.assigns[:uat_expanded_ujian_id]

          if ujian_id do
            ujian = UjianPenerimaanPengguna.get_ujian(ujian_id)
            formatted = ujian && UjianPenerimaanPengguna.format_ujian_for_display(ujian)

            {:noreply,
             if(formatted, do: assign(socket, :uat_expanded_ujian, formatted), else: socket)}
          else
            {:noreply, socket}
          end

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Gagal menyimpan catatan.")}
      end
    else
      {:noreply, socket}
    end
  end

  # Perubahan (change management) modals and forms
  @impl true
  def handle_event("open_view_modal", %{"perubahan_id" => perubahan_id}, socket) do
    id = parse_perubahan_id(perubahan_id)
    perubahan = id && Enum.find(socket.assigns.perubahan, fn p -> p.id == id end)

    if perubahan do
      {:noreply,
       socket
       |> assign(:show_view_modal, true)
       |> assign(:selected_perubahan, perubahan)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_view_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_view_modal, false)
     |> assign(:selected_perubahan, nil)}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    form = to_form(%{}, as: :perubahan)

    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:form, to_form(%{}, as: :perubahan))}
  end

  @impl true
  def handle_event("validate_perubahan", %{"perubahan" => perubahan_params}, socket) do
    form = to_form(perubahan_params, as: :perubahan)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("open_edit_modal", %{"perubahan_id" => perubahan_id}, socket) do
    id = parse_perubahan_id(perubahan_id)
    perubahan = id && Enum.find(socket.assigns.perubahan, fn p -> p.id == id end)

    if perubahan do
      tarikh_dijangka_siap_str =
        if perubahan.tarikh_dijangka_siap do
          Calendar.strftime(perubahan.tarikh_dijangka_siap, "%Y-%m-%d")
        else
          ""
        end

      form_data = %{
        "tajuk" => perubahan.tajuk,
        "jenis" => perubahan.jenis,
        "modul_terlibat" => perubahan.modul_terlibat,
        "tarikh_dibuat" => Calendar.strftime(perubahan.tarikh_dibuat, "%Y-%m-%d"),
        "tarikh_dijangka_siap" => tarikh_dijangka_siap_str,
        "status" => perubahan.status,
        "keutamaan" => perubahan.keutamaan || "",
        "justifikasi" => perubahan.justifikasi || "",
        "kesan" => perubahan.kesan || "",
        "catatan" => perubahan.catatan || ""
      }

      form = to_form(form_data, as: :perubahan)

      {:noreply,
       socket
       |> assign(:show_view_modal, false)
       |> assign(:show_edit_modal, true)
       |> assign(:selected_perubahan, perubahan)
       |> assign(:form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:selected_perubahan, nil)
     |> assign(:form, to_form(%{}, as: :perubahan))}
  end

  # --- Ujian Keselamatan (tab) events (prefix kes_ to avoid clash with UAT) ---
  @impl true
  def handle_event("open_kes_create_modal", _params, socket) do
    form_data = %{
      "tarikh_permohonan" => "",
      "tarikh_kelulusan" => "",
      "upload_file" => "",
      "status_kelulusan" => "Lulus"
    }

    {:noreply,
     socket
     |> assign(:kes_show_create_modal, true)
     |> assign(:kes_form, to_form(form_data, as: :ujian))}
  end

  @impl true
  def handle_event("close_kes_create_modal", _params, socket) do
    socket =
      socket
      |> maybe_cancel_kes_file_uploads()
      |> assign(:kes_show_create_modal, false)
      |> assign(:kes_form, to_form(%{}, as: :ujian))

    {:noreply, socket}
  end

  @impl true
  def handle_event("kes_create_ujian", %{"ujian" => ujian_params}, socket) do
    project_id = socket.assigns.project.id

    modul_name =
      (ujian_params["modul"] || "")
      |> String.trim()
      |> then(fn m -> if m == "", do: "-", else: m end)

    tajuk =
      (ujian_params["tajuk"] || "")
      |> String.trim()
      |> then(fn t -> if t == "", do: "Ujian Keselamatan", else: t end)

    module_id =
      socket.assigns[:modules]
      |> List.wrap()
      |> Enum.find(fn m -> (m[:name] || m["name"]) == modul_name end)
      |> then(fn m -> m && (m[:id] || m["id"]) end)
      |> then(fn id -> id && kes_parse_module_id_from_placeholder(to_string(id)) end)

    tarikh_permohonan = kes_parse_date_param(ujian_params["tarikh_permohonan"])
    tarikh_kelulusan = kes_parse_date_param(ujian_params["tarikh_kelulusan"])

    status_kelulusan =
      (ujian_params["status_kelulusan"] || "Lulus")
      |> String.trim()
      |> then(fn s -> if s == "", do: nil, else: s end)

    upload_file =
      consume_uploaded_entries(socket, :kes_file, fn %{path: path}, entry ->
        filename = kes_upload_filename(project_id, entry)
        dest_dir = Path.join(File.cwd!(), "priv/static/uploads/ujian_keselamatan")
        File.mkdir_p!(dest_dir)
        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)
        {:ok, "ujian_keselamatan/#{filename}"}
      end)
      |> List.first()

    attrs = %{
      project_id: project_id,
      modul: modul_name,
      tajuk: tajuk,
      analisis_dan_rekabentuk_module_id: module_id,
      tarikh_permohonan: tarikh_permohonan,
      tarikh_kelulusan: tarikh_kelulusan,
      upload_file: upload_file,
      status_kelulusan: status_kelulusan
    }

    case UjianKeselamatan.create_ujian(attrs) do
      {:ok, _ujian} ->
        ujian_list =
          UjianKeselamatan.list_ujian_rows_for_project(
            project_id,
            socket.assigns.current_scope
          )

        {:noreply,
         socket
         |> assign(:ujian_keselamatan, ujian_list)
         |> assign(:kes_show_create_modal, false)
         |> assign(:kes_form, to_form(%{}, as: :ujian))
         |> put_flash(:info, "Ujian keselamatan berjaya didaftarkan")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:kes_form, to_form(changeset, as: :ujian))
         |> put_flash(:error, "Gagal mendaftar ujian keselamatan. Sila semak maklumat.")}
    end
  end

  # =========================
  # Penyerahan tab events
  # =========================

  @impl true
  def handle_event("penyerahan_open_create_modal", _params, socket) do
    project = socket.assigns[:project]

    jabatan =
      if project && Map.get(project, :jabatan) && project.jabatan != "" do
        project.jabatan
      else
        "Tidak Ditetapkan"
      end

    pengurus_projek =
      if project && Map.get(project, :pengurus_projek) && project.pengurus_projek != "" do
        project.pengurus_projek
      else
        "Tidak Ditetapkan"
      end

    form_data = %{
      "nama_sistem" => (project && project.nama) || "",
      "versi" => versi_for_project(project),
      "penerima" => jabatan,
      "pengurus_projek" => pengurus_projek
    }

    form = to_form(form_data, as: :penyerahan)

    {:noreply,
     socket
     |> assign(:penyerahan_show_create_modal, true)
     |> assign(:penyerahan_form, form)}
  end

  @impl true
  def handle_event("penyerahan_close_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:penyerahan_show_create_modal, false)
     |> assign(:penyerahan_form, to_form(%{}, as: :penyerahan))}
  end

  @impl true
  def handle_event("penyerahan_validate", %{"penyerahan" => penyerahan_params}, socket) do
    form = to_form(penyerahan_params, as: :penyerahan)
    {:noreply, assign(socket, :penyerahan_form, form)}
  end

  @impl true
  def handle_event("penyerahan_create", %{"penyerahan" => penyerahan_params}, socket) do
    project = socket.assigns[:project]
    project_id = project && Map.get(project, :id)

    tarikh_penyerahan =
      if penyerahan_params["tarikh_penyerahan"] && penyerahan_params["tarikh_penyerahan"] != "" do
        case Date.from_iso8601(penyerahan_params["tarikh_penyerahan"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    db_attrs =
      if project_id do
        %{
          project_id: project_id,
          nama_sistem: penyerahan_params["nama_sistem"],
          versi: penyerahan_params["versi"] || "",
          penerima: penyerahan_params["penerima"],
          pengurus_projek:
            if(penyerahan_params["pengurus_projek"] in [nil, ""],
              do: nil,
              else: penyerahan_params["pengurus_projek"]
            ),
          tarikh_penyerahan: tarikh_penyerahan
        }
      else
        nil
      end

    cond do
      is_nil(project_id) or is_nil(db_attrs) ->
        {:noreply,
         put_flash(socket, :error, "Projek tidak sah, penyerahan tidak dapat didaftarkan.")}

      true ->
        case Penyerahans.create_penyerahan(db_attrs) do
          {:ok, _penyerahan} ->
            # Refresh senarai penyerahan dari DB supaya UI sentiasa selaras
            updated_list = get_penyerahan_for_project(project)

            {:noreply,
             socket
             |> assign(:penyerahan, updated_list)
             |> assign(:penyerahan_show_create_modal, false)
             |> assign(:penyerahan_form, to_form(%{}, as: :penyerahan))
             |> put_flash(:info, "Penyerahan berjaya didaftarkan")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Gagal mendaftar penyerahan. Sila semak maklumat dan cuba lagi."
             )}
        end
    end
  end

  @impl true
  def handle_event("penyerahan_open_edit_modal", %{"penyerahan_id" => penyerahan_id}, socket) do
    penyerahan =
      Enum.find(socket.assigns.penyerahan, fn p -> to_string(p.id) == to_string(penyerahan_id) end)

    if penyerahan do
      form_data = %{
        "nama_sistem" => penyerahan.nama_sistem || "",
        "versi" => penyerahan.versi || "",
        "penerima" => penyerahan.penerima || "",
        "pengurus_projek" => penyerahan.pengurus_projek || "",
        "tarikh_penyerahan" =>
          if(penyerahan.tarikh_penyerahan,
            do: Calendar.strftime(penyerahan.tarikh_penyerahan, "%Y-%m-%d"),
            else: ""
          )
      }

      form = to_form(form_data, as: :penyerahan)

      {:noreply,
       socket
       |> assign(:penyerahan_show_edit_modal, true)
       |> assign(:penyerahan_editing_penyerahan, penyerahan)
       |> assign(:penyerahan_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("penyerahan_close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:penyerahan_show_edit_modal, false)
     |> assign(:penyerahan_editing_penyerahan, nil)
     |> assign(:penyerahan_form, to_form(%{}, as: :penyerahan))}
  end

  @impl true
  def handle_event("penyerahan_update", %{"penyerahan" => penyerahan_params}, socket) do
    editing_penyerahan = socket.assigns[:penyerahan_editing_penyerahan]

    if editing_penyerahan do
      penyerahan_id = editing_penyerahan.id
      project_id = socket.assigns.project && socket.assigns.project.id

      tarikh_penyerahan =
        if penyerahan_params["tarikh_penyerahan"] && penyerahan_params["tarikh_penyerahan"] != "" do
          case Date.from_iso8601(penyerahan_params["tarikh_penyerahan"]) do
            {:ok, date} -> date
            _ -> editing_penyerahan.tarikh_penyerahan
          end
        else
          editing_penyerahan.tarikh_penyerahan
        end

      updated_penyerahan_data = %{
        editing_penyerahan
        | versi: penyerahan_params["versi"] || editing_penyerahan.versi,
          penerima: penyerahan_params["penerima"] || editing_penyerahan.penerima,
          pengurus_projek:
            if(
              penyerahan_params["pengurus_projek"] == nil or
                penyerahan_params["pengurus_projek"] == "",
              do: nil,
              else: penyerahan_params["pengurus_projek"]
            ),
          tarikh_penyerahan: tarikh_penyerahan
      }

      updated_penyerahan_list =
        Enum.map(socket.assigns.penyerahan, fn penyerahan ->
          if penyerahan.id == penyerahan_id, do: updated_penyerahan_data, else: penyerahan
        end)

      # Persist to DB (create/update by project_id)
      if project_id do
        db_attrs = %{
          project_id: project_id,
          tarikh_penyerahan: tarikh_penyerahan,
          manual_pengguna: updated_penyerahan_data.manual_pengguna,
          surat_akuan_penerimaan: updated_penyerahan_data.surat_akuan_penerimaan
        }

        case Penyerahans.get_penyerahan_by_project_id(project_id) do
          nil -> Penyerahans.create_penyerahan(db_attrs)
          penyerahan -> Penyerahans.update_penyerahan(penyerahan, db_attrs)
        end
      end

      {:noreply,
       socket
       |> assign(:penyerahan, updated_penyerahan_list)
       |> assign(:penyerahan_show_edit_modal, false)
       |> assign(:penyerahan_editing_penyerahan, nil)
       |> assign(:penyerahan_form, to_form(%{}, as: :penyerahan))
       |> put_flash(:info, "Penyerahan berjaya dikemaskini")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "penyerahan_open_upload_modal",
        %{"penyerahan_id" => penyerahan_id} = params,
        socket
      ) do
    target = Map.get(params, "target", "manual")
    penyerahan_list = socket.assigns.penyerahan || []

    penyerahan =
      Enum.find(penyerahan_list, fn p -> to_string(p.id) == to_string(penyerahan_id) end)

    if penyerahan do
      {:noreply,
       socket
       |> assign(:penyerahan_show_upload_modal, true)
       |> assign(:penyerahan_upload_target, target)
       |> assign(:penyerahan_uploading_penyerahan_id, penyerahan_id)
       |> assign(:penyerahan_uploading_penyerahan, penyerahan)
       |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))
       |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("penyerahan_close_upload_modal", _params, socket) do
    {:noreply,
     socket
     |> maybe_cancel_penyerahan_uploads()
     |> assign(:penyerahan_show_upload_modal, false)
     |> assign(:penyerahan_upload_target, "manual")
     |> assign(:penyerahan_uploading_penyerahan_id, nil)
     |> assign(:penyerahan_uploading_penyerahan, nil)
     |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))
     |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
  end

  @impl true
  def handle_event("penyerahan_validate_upload_manual", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("penyerahan_validate_upload_surat", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("penyerahan_validate_upload_documents", _params, socket) do
    # Diperlukan supaya live_file_input menghantar fail ke pelayan apabila pengguna pilih fail
    {:noreply, socket}
  end

  @impl true
  def handle_event("penyerahan_upload_documents", params, socket) do
    penyerahan_id =
      params["penyerahan_id"] || socket.assigns[:penyerahan_uploading_penyerahan_id]

    if not penyerahan_id do
      {:noreply,
       socket
       |> put_flash(:error, "Sila pilih penyerahan terlebih dahulu")
       |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))
       |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
    else
      try do
        dest_dir = Path.join(File.cwd!(), "priv/static/uploads/penyerahan")
        File.mkdir_p!(dest_dir)

        saved_manual =
          consume_uploaded_entries(socket, :penyerahan_manual, fn %{path: path}, entry ->
            ext = Path.extname(entry.client_name) |> String.downcase()
            ext = if ext in [".pdf", ".doc", ".docx"], do: ext, else: ".pdf"
            filename = "manual_pengguna_#{penyerahan_id}#{ext}"
            dest = Path.join(dest_dir, filename)
            File.cp!(path, dest)
            {:ok, filename}
          end)
          |> List.first()

        saved_surat =
          consume_uploaded_entries(socket, :penyerahan_surat, fn %{path: path}, entry ->
            ext = Path.extname(entry.client_name) |> String.downcase()
            ext = if ext in [".pdf", ".doc", ".docx"], do: ext, else: ".pdf"
            filename = "surat_akuan_#{penyerahan_id}#{ext}"
            dest = Path.join(dest_dir, filename)
            File.cp!(path, dest)
            {:ok, filename}
          end)
          |> List.first()

        if saved_manual || saved_surat do
          current_penyerahan =
            Enum.find(socket.assigns.penyerahan, fn p ->
              to_string(p.id) == to_string(penyerahan_id)
            end) || editing_penyerahan_fallback(socket, penyerahan_id)

          updated_penyerahan =
            Enum.map(socket.assigns.penyerahan, fn penyerahan ->
              if to_string(penyerahan.id) == to_string(penyerahan_id) do
                penyerahan
                |> maybe_update(:manual_pengguna, saved_manual)
                |> maybe_update(:surat_akuan_penerimaan, saved_surat)
              else
                penyerahan
              end
            end)

          project_id = socket.assigns.project && socket.assigns.project.id

          if project_id do
            current =
              Enum.find(updated_penyerahan, fn p ->
                to_string(p.id) == to_string(penyerahan_id)
              end) || current_penyerahan

            db_attrs = %{
              project_id: project_id,
              tarikh_penyerahan: current && current.tarikh_penyerahan,
              manual_pengguna: current && current.manual_pengguna,
              surat_akuan_penerimaan: current && current.surat_akuan_penerimaan
            }

            case Penyerahans.get_penyerahan_by_project_id(project_id) do
              nil -> Penyerahans.create_penyerahan(db_attrs)
              penyerahan -> Penyerahans.update_penyerahan(penyerahan, db_attrs)
            end
          end

          updated_uploading_penyerahan =
            Enum.find(updated_penyerahan, fn p ->
              to_string(p.id) == to_string(penyerahan_id)
            end) || socket.assigns[:penyerahan_uploading_penyerahan]

          msg =
            cond do
              saved_manual && saved_surat -> "Manual pengguna dan Surat Akuan berjaya dimuat naik"
              saved_manual -> "Manual pengguna berjaya dimuat naik"
              true -> "Surat Akuan Penerimaan Aplikasi berjaya dimuat naik"
            end

          {:noreply,
           socket
           |> assign(:penyerahan, updated_penyerahan)
           |> assign(:penyerahan_uploading_penyerahan, updated_uploading_penyerahan)
           |> put_flash(:info, msg)
           |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))
           |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
        else
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Sila tunggu muat naik selesai atau pilih sekurang-kurangnya satu fail."
           )
           |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))
           |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
        end
      rescue
        e ->
          require Logger
          Logger.error("penyerahan_upload_documents failed: #{inspect(e)}")

          {:noreply,
           socket
           |> put_flash(
             :error,
             "Muat naik gagal. Sila pastikan fail selesai dimuat naik (100%) dan cuba lagi."
           )
           |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))
           |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
      end
    end
  end

  @impl true
  def handle_event("penyerahan_upload_manual", %{"upload_manual" => upload_params}, socket) do
    penyerahan_id =
      upload_params["penyerahan_id"] ||
        socket.assigns[:penyerahan_uploading_penyerahan_id]

    if not penyerahan_id do
      {:noreply,
       socket
       |> put_flash(:error, "Sila pilih penyerahan terlebih dahulu")
       |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))}
    else
      saved_filename =
        consume_uploaded_entries(socket, :penyerahan_manual, fn %{path: path}, entry ->
          ext = Path.extname(entry.client_name) |> String.downcase()
          ext = if ext in [".pdf", ".doc", ".docx"], do: ext, else: ".pdf"
          filename = "manual_pengguna_#{penyerahan_id}#{ext}"
          dest_dir = Path.join(File.cwd!(), "priv/static/uploads/penyerahan")
          File.mkdir_p!(dest_dir)
          dest = Path.join(dest_dir, filename)
          File.cp!(path, dest)
          {:ok, filename}
        end)
        |> List.first()

      if saved_filename do
        updated_penyerahan =
          Enum.map(socket.assigns.penyerahan, fn penyerahan ->
            if to_string(penyerahan.id) == to_string(penyerahan_id) do
              %{penyerahan | manual_pengguna: saved_filename}
            else
              penyerahan
            end
          end)

        project_id = socket.assigns.project && socket.assigns.project.id

        if project_id do
          current =
            Enum.find(updated_penyerahan, fn p ->
              to_string(p.id) == to_string(penyerahan_id)
            end) ||
              editing_penyerahan_fallback(socket, penyerahan_id)

          db_attrs = %{
            project_id: project_id,
            tarikh_penyerahan: current && current.tarikh_penyerahan,
            manual_pengguna: current && current.manual_pengguna,
            surat_akuan_penerimaan: current && current.surat_akuan_penerimaan
          }

          case Penyerahans.get_penyerahan_by_project_id(project_id) do
            nil -> Penyerahans.create_penyerahan(db_attrs)
            penyerahan -> Penyerahans.update_penyerahan(penyerahan, db_attrs)
          end
        end

        updated_uploading_penyerahan =
          Enum.find(updated_penyerahan, fn p ->
            to_string(p.id) == to_string(penyerahan_id)
          end) || socket.assigns[:penyerahan_uploading_penyerahan]

        {:noreply,
         socket
         |> assign(:penyerahan, updated_penyerahan)
         |> assign(:penyerahan_uploading_penyerahan, updated_uploading_penyerahan)
         |> put_flash(:info, "Manual pengguna berjaya dimuat naik")
         |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))}
      else
        {:noreply,
         socket
         |> put_flash(:error, "Sila pilih fail untuk dimuat naik")
         |> assign(:penyerahan_upload_manual_form, to_form(%{}, as: :upload_manual))}
      end
    end
  end

  @impl true
  def handle_event("penyerahan_upload_surat", %{"upload_surat" => upload_params}, socket) do
    penyerahan_id =
      upload_params["penyerahan_id"] ||
        socket.assigns[:penyerahan_uploading_penyerahan_id]

    if not penyerahan_id do
      {:noreply,
       socket
       |> put_flash(:error, "Sila pilih penyerahan terlebih dahulu")
       |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
    else
      saved_filename =
        consume_uploaded_entries(socket, :penyerahan_surat, fn %{path: path}, entry ->
          ext = Path.extname(entry.client_name) |> String.downcase()
          ext = if ext in [".pdf", ".doc", ".docx"], do: ext, else: ".pdf"
          filename = "surat_akuan_#{penyerahan_id}#{ext}"
          dest_dir = Path.join(File.cwd!(), "priv/static/uploads/penyerahan")
          File.mkdir_p!(dest_dir)
          dest = Path.join(dest_dir, filename)
          File.cp!(path, dest)
          {:ok, filename}
        end)
        |> List.first()

      if saved_filename do
        updated_penyerahan =
          Enum.map(socket.assigns.penyerahan, fn penyerahan ->
            if to_string(penyerahan.id) == to_string(penyerahan_id) do
              %{penyerahan | surat_akuan_penerimaan: saved_filename}
            else
              penyerahan
            end
          end)

        project_id = socket.assigns.project && socket.assigns.project.id

        if project_id do
          current =
            Enum.find(updated_penyerahan, fn p ->
              to_string(p.id) == to_string(penyerahan_id)
            end) ||
              editing_penyerahan_fallback(socket, penyerahan_id)

          db_attrs = %{
            project_id: project_id,
            tarikh_penyerahan: current && current.tarikh_penyerahan,
            manual_pengguna: current && current.manual_pengguna,
            surat_akuan_penerimaan: current && current.surat_akuan_penerimaan
          }

          case Penyerahans.get_penyerahan_by_project_id(project_id) do
            nil -> Penyerahans.create_penyerahan(db_attrs)
            penyerahan -> Penyerahans.update_penyerahan(penyerahan, db_attrs)
          end
        end

        updated_uploading_penyerahan =
          Enum.find(updated_penyerahan, fn p ->
            to_string(p.id) == to_string(penyerahan_id)
          end) || socket.assigns[:penyerahan_uploading_penyerahan]

        {:noreply,
         socket
         |> assign(:penyerahan, updated_penyerahan)
         |> assign(:penyerahan_uploading_penyerahan, updated_uploading_penyerahan)
         |> put_flash(:info, "Surat Akuan Penerimaan Aplikasi berjaya dimuat naik")
         |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
      else
        {:noreply,
         socket
         |> put_flash(:error, "Sila pilih fail untuk dimuat naik")
         |> assign(:penyerahan_upload_surat_form, to_form(%{}, as: :upload_surat))}
      end
    end
  end

  @impl true
  def handle_event("kes_open_edit_modal", %{"ujian_id" => ujian_id_str}, socket) do
    ujian_id = kes_parse_ujian_id(ujian_id_str)
    ujian = kes_get_ujian_by_id(ujian_id, ujian_id_str, socket)

    if ujian do
      form_data = %{
        "tarikh_permohonan" => kes_format_date_for_form(ujian[:tarikh_permohonan]),
        "tarikh_kelulusan" => kes_format_date_for_form(ujian[:tarikh_kelulusan]),
        "upload_file" => ujian[:upload_file] || "",
        "status_kelulusan" => ujian[:status_kelulusan] || "Lulus"
      }

      form = to_form(form_data, as: :ujian)

      {:noreply,
       socket
       |> assign(:kes_show_edit_modal, true)
       |> assign(:kes_editing_ujian, ujian)
       |> assign(:kes_editing_ujian_raw_id, ujian_id_str)
       |> assign(:kes_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("kes_close_edit_modal", _params, socket) do
    socket =
      socket
      |> maybe_cancel_kes_edit_file_uploads()
      |> assign(:kes_show_edit_modal, false)
      |> assign(:kes_editing_ujian, nil)
      |> assign(:kes_editing_ujian_raw_id, nil)
      |> assign(:kes_form, to_form(%{}, as: :ujian))

    {:noreply, socket}
  end

  @impl true
  def handle_event("kes_validate_ujian", %{"ujian" => ujian_params}, socket) do
    # Strip LiveView _unused_* keys so form state is not polluted (e.g. when file input triggers phx-change)
    params =
      Map.drop(
        ujian_params,
        Map.keys(ujian_params) |> Enum.filter(&String.starts_with?(&1, "_unused_"))
      )

    form = to_form(params, as: :ujian)
    {:noreply, assign(socket, :kes_form, form)}
  end

  @impl true
  def handle_event("kes_update_ujian", %{"ujian" => ujian_params}, socket) do
    editing_ujian = socket.assigns[:kes_editing_ujian] || socket.assigns[:kes_selected_ujian]
    raw_id = socket.assigns[:kes_editing_ujian_raw_id] || (editing_ujian && editing_ujian.id)
    project_id = socket.assigns.project.id

    if editing_ujian && project_id do
      tarikh_permohonan = kes_parse_date_param(ujian_params["tarikh_permohonan"])
      tarikh_kelulusan = kes_parse_date_param(ujian_params["tarikh_kelulusan"])

      status_kelulusan =
        (ujian_params["status_kelulusan"] || "Lulus")
        |> String.trim()
        |> then(fn s -> if s == "", do: nil, else: s end)

      upload_file_from_entries =
        consume_uploaded_entries(socket, :kes_edit_file, fn %{path: path}, entry ->
          filename = kes_upload_filename(project_id, entry)
          dest_dir = Path.join(File.cwd!(), "priv/static/uploads/ujian_keselamatan")
          File.mkdir_p!(dest_dir)
          dest = Path.join(dest_dir, filename)
          File.cp!(path, dest)
          {:ok, "ujian_keselamatan/#{filename}"}
        end)
        |> List.first()

      upload_file =
        if upload_file_from_entries do
          upload_file_from_entries
        else
          (ujian_params["upload_file"] || "")
          |> String.trim()
          |> then(fn s -> if s == "", do: nil, else: s end)
        end

      modul = editing_ujian[:modul] || editing_ujian["modul"] || "-"
      tajuk = editing_ujian[:tajuk] || editing_ujian["tajuk"] || "Ujian Keselamatan"

      attrs = %{
        project_id: project_id,
        modul: modul,
        tajuk: tajuk,
        tarikh_permohonan: tarikh_permohonan,
        tarikh_kelulusan: tarikh_kelulusan,
        upload_file: upload_file,
        status_kelulusan: status_kelulusan,
        tarikh_ujian: editing_ujian[:tarikh_ujian] || editing_ujian["tarikh_ujian"],
        tarikh_dijangka_siap:
          editing_ujian[:tarikh_dijangka_siap] || editing_ujian["tarikh_dijangka_siap"],
        status: editing_ujian[:status] || editing_ujian["status"] || "Menunggu",
        penguji: editing_ujian[:penguji] || editing_ujian["penguji"],
        hasil: editing_ujian[:hasil] || editing_ujian["hasil"] || "Belum Selesai",
        disahkan_oleh: editing_ujian[:disahkan_oleh] || editing_ujian["disahkan_oleh"],
        catatan: editing_ujian[:catatan] || editing_ujian["catatan"]
      }

      parsed_id = kes_parse_ujian_id(raw_id)

      result =
        cond do
          is_binary(raw_id) && String.starts_with?(to_string(raw_id), "module_") ->
            module_id = kes_parse_module_id_from_placeholder(to_string(raw_id))
            attrs = Map.put(attrs, :analisis_dan_rekabentuk_module_id, module_id)
            UjianKeselamatan.create_ujian(attrs)

          is_integer(parsed_id) ->
            case UjianKeselamatan.get_ujian(parsed_id) do
              nil -> {:error, :not_found}
              ujian -> UjianKeselamatan.update_ujian(ujian, attrs)
            end

          true ->
            {:error, :invalid_id}
        end

      case result do
        {:ok, _ujian} ->
          ujian =
            UjianKeselamatan.list_ujian_rows_for_project(
              project_id,
              socket.assigns.current_scope
            )

          {:noreply,
           socket
           |> assign(:ujian_keselamatan, ujian)
           |> assign(:kes_show_edit_modal, false)
           |> assign(:kes_editing_ujian, nil)
           |> assign(:kes_editing_ujian_raw_id, nil)
           |> assign(:kes_form, to_form(%{}, as: :ujian))
           |> put_flash(:info, "Ujian keselamatan berjaya dikemaskini")}

        {:error, %Ecto.Changeset{} = changeset} ->
          errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

          msg =
            if map_size(errors) > 0 do
              detail = errors |> Enum.map(fn {f, _} -> to_string(f) end) |> Enum.join(", ")
              "Gagal menyimpan ujian keselamatan (#{detail}). Sila semak data dan cuba lagi."
            else
              "Gagal menyimpan ujian keselamatan. Sila semak data dan cuba lagi."
            end

          {:noreply, socket |> put_flash(:error, msg)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Gagal menyimpan ujian keselamatan. Sila semak data dan cuba lagi."
           )}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("kes_edit_kes_ujian", %{"kes_id" => kes_id_str}, socket) do
    kes_id = kes_parse_kes_id(kes_id_str)

    if socket.assigns[:kes_selected_ujian] && socket.assigns.kes_selected_ujian.senarai_kes_ujian do
      kes =
        Enum.find(socket.assigns.kes_selected_ujian.senarai_kes_ujian, fn k ->
          k.id == kes_id || k.id == kes_id_str
        end)

      if kes do
        form_data = %{
          "senario" => kes.senario || "",
          "langkah" => kes.langkah || "",
          "keputusan_dijangka" => kes.keputusan_dijangka || "",
          "keputusan_sebenar" => kes.keputusan_sebenar || "",
          "hasil" => kes.hasil || "",
          "penguji" => Map.get(kes, :penguji, "") || "",
          "tarikh_ujian" =>
            if(kes.tarikh_ujian, do: Calendar.strftime(kes.tarikh_ujian, "%Y-%m-%d"), else: ""),
          "disahkan" => if(Map.get(kes, :disahkan, false), do: "true", else: ""),
          "disahkan_oleh" => Map.get(kes, :disahkan_oleh, "") || "",
          "tarikh_pengesahan" =>
            if(kes.tarikh_pengesahan,
              do: Calendar.strftime(kes.tarikh_pengesahan, "%Y-%m-%d"),
              else: ""
            )
        }

        form = to_form(form_data, as: :kes)

        {:noreply,
         socket
         |> assign(:kes_show_edit_kes_modal, true)
         |> assign(:kes_selected_kes, kes)
         |> assign(:kes_kes_form, form)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("kes_close_edit_kes_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:kes_show_edit_kes_modal, false)
     |> assign(:kes_selected_kes, nil)
     |> assign(:kes_kes_form, to_form(%{}, as: :kes))}
  end

  @impl true
  def handle_event("kes_validate_kes", %{"kes" => kes_params}, socket) do
    form = to_form(kes_params, as: :kes)
    {:noreply, assign(socket, :kes_kes_form, form)}
  end

  @impl true
  def handle_event("kes_update_kes", %{"kes" => kes_params}, socket) do
    kes_id = socket.assigns.kes_selected_kes.id
    kes = UjianKeselamatan.get_kes(kes_id)

    if kes && is_integer(kes_id) do
      tarikh_ujian = kes_parse_date_param(kes_params["tarikh_ujian"])
      tarikh_pengesahan = kes_parse_date_param(kes_params["tarikh_pengesahan"])

      attrs = %{
        senario: kes_params["senario"] || kes.senario,
        langkah: kes_params["langkah"] || "",
        keputusan_dijangka: kes_params["keputusan_dijangka"] || "",
        keputusan_sebenar:
          if(kes_params["keputusan_sebenar"] == "",
            do: nil,
            else: kes_params["keputusan_sebenar"]
          ),
        hasil: if(kes_params["hasil"] == "", do: nil, else: kes_params["hasil"]),
        penguji: if(kes_params["penguji"] == "", do: nil, else: kes_params["penguji"]),
        tarikh_ujian: tarikh_ujian,
        disahkan: kes_params["disahkan"] == "true",
        disahkan_oleh:
          if(kes_params["disahkan_oleh"] == "", do: nil, else: kes_params["disahkan_oleh"]),
        tarikh_pengesahan: tarikh_pengesahan
      }

      case UjianKeselamatan.update_kes(kes, attrs) do
        {:ok, _} ->
          ujian_id = socket.assigns.kes_selected_ujian.id
          updated = UjianKeselamatan.get_ujian_formatted(ujian_id)

          {:noreply,
           socket
           |> assign(:kes_selected_ujian, updated)
           |> assign(:kes_selected_kes, nil)
           |> assign(:kes_show_edit_kes_modal, false)
           |> assign(:kes_kes_form, to_form(%{}, as: :kes))
           |> put_flash(:info, "Kes ujian berjaya dikemaskini")}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal menyimpan kes ujian. Sila semak data dan cuba lagi.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("kes_add_new_kes", _params, socket) do
    try do
      selected = socket.assigns[:kes_selected_ujian]
      ujian_id = selected && (Map.get(selected, :id) || Map.get(selected, "id"))

      if selected && is_integer(ujian_id) do
        senarai =
          Map.get(selected, :senarai_kes_ujian, []) || Map.get(selected, "senarai_kes_ujian", [])

        existing_kods = Enum.map(senarai, fn k -> Map.get(k, :kod) || Map.get(k, "kod") end)

        new_number =
          existing_kods
          |> Enum.map(fn kod ->
            case kod && Regex.run(~r/SEC-(\d+)/, to_string(kod)) do
              [_, num_str] -> String.to_integer(num_str)
              _ -> 0
            end
          end)
          |> (fn list -> if list == [], do: [0], else: list end).()
          |> Enum.max()
          |> Kernel.+(1)

        kod = "SEC-#{String.pad_leading(Integer.to_string(new_number), 3, "0")}"

        attrs = %{
          ujian_keselamatan_id: ujian_id,
          kod: kod,
          senario: "",
          langkah: "",
          keputusan_dijangka: "",
          keputusan_sebenar: nil,
          hasil: nil,
          penguji: nil,
          tarikh_ujian: nil,
          disahkan: false,
          disahkan_oleh: nil,
          tarikh_pengesahan: nil
        }

        case UjianKeselamatan.create_kes(attrs) do
          {:ok, _} ->
            updated = UjianKeselamatan.get_ujian_formatted(ujian_id)

            if updated do
              {:noreply,
               socket
               |> assign(:kes_selected_ujian, updated)
               |> put_flash(:info, "Kes ujian baru berjaya ditambah")}
            else
              {:noreply,
               socket
               |> put_flash(
                 :error,
                 "Kes ujian ditambah tetapi data tidak dapat dimuat semula. Sila refresh halaman."
               )}
            end

          {:error, changeset} ->
            errors =
              try do
                Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
                |> Enum.flat_map(fn {_field, msgs} -> msgs end)
                |> Enum.join(", ")
              rescue
                _e -> ""
              end

            msg =
              if errors != "" do
                "Gagal menambah kes ujian: #{errors}"
              else
                "Gagal menambah kes ujian. Sila cuba lagi."
              end

            {:noreply, socket |> put_flash(:error, msg)}
        end
      else
        {:noreply,
         socket
         |> put_flash(:error, "Ujian tidak dijumpai. Sila kembali ke senarai dan cuba lagi.")}
      end
    rescue
      e ->
        require Logger
        Logger.error("kes_add_new_kes crashed: #{inspect(e)}")
        Logger.error(Exception.format(:error, e, __STACKTRACE__))
        err_msg = Exception.message(e)

        flash_msg =
          if String.length(err_msg) < 120 do
            "Ralat menambah kes ujian: #{err_msg}"
          else
            "Ralat menambah kes ujian. Sila cuba lagi atau hubungi pentadbir."
          end

        {:noreply, socket |> put_flash(:error, flash_msg)}
    end
  end

  @impl true
  def handle_event("kes_delete_kes_ujian", %{"kes_id" => kes_id_str}, socket) do
    kes_id = kes_parse_kes_id(kes_id_str)
    kes = is_integer(kes_id) && UjianKeselamatan.get_kes(kes_id)

    if kes do
      case UjianKeselamatan.delete_kes(kes) do
        {:ok, _} ->
          ujian_id = socket.assigns.kes_selected_ujian.id
          updated = UjianKeselamatan.get_ujian_formatted(ujian_id)

          {:noreply,
           socket
           |> assign(:kes_selected_ujian, updated)
           |> put_flash(:info, "Kes ujian berjaya dipadam")}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal memadam kes ujian. Sila cuba lagi.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_perubahan", %{"perubahan" => perubahan_params}, socket) do
    project_id = socket.assigns.project.id

    tarikh_dibuat =
      if perubahan_params["tarikh_dibuat"] && perubahan_params["tarikh_dibuat"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dibuat"]) do
          {:ok, date} -> date
          _ -> Date.utc_today()
        end
      else
        Date.utc_today()
      end

    tarikh_dijangka_siap =
      if perubahan_params["tarikh_dijangka_siap"] &&
           perubahan_params["tarikh_dijangka_siap"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    attrs = %{
      project_id: project_id,
      tajuk: perubahan_params["tajuk"],
      jenis: perubahan_params["jenis"],
      modul_terlibat: perubahan_params["modul_terlibat"],
      tarikh_dibuat: tarikh_dibuat,
      tarikh_dijangka_siap: tarikh_dijangka_siap,
      status: perubahan_params["status"] || "Dalam Semakan",
      keutamaan: empty_to_nil(perubahan_params["keutamaan"]),
      justifikasi: empty_to_nil(perubahan_params["justifikasi"]),
      kesan: empty_to_nil(perubahan_params["kesan"]),
      catatan: empty_to_nil(perubahan_params["catatan"])
    }

    case PermohonanPerubahan.create_permohonan_perubahan(attrs) do
      {:ok, _perubahan} ->
        perubahan = PermohonanPerubahan.list_by_project(project_id)

        {:noreply,
         socket
         |> assign(:perubahan, perubahan)
         |> assign(:show_create_modal, false)
         |> assign(:form, to_form(%{}, as: :perubahan))
         |> put_flash(:info, "Permohonan perubahan berjaya didaftarkan")}

      {:error, changeset} ->
        form = to_form(changeset, as: :perubahan)

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Gagal mendaftar. Sila semak maklumat.")}
    end
  end

  @impl true
  def handle_event("update_perubahan", %{"perubahan" => perubahan_params}, socket) do
    selected = socket.assigns.selected_perubahan
    project_id = socket.assigns.project.id

    tarikh_dibuat =
      if perubahan_params["tarikh_dibuat"] && perubahan_params["tarikh_dibuat"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dibuat"]) do
          {:ok, date} -> date
          _ -> selected.tarikh_dibuat
        end
      else
        selected.tarikh_dibuat
      end

    tarikh_dijangka_siap =
      if perubahan_params["tarikh_dijangka_siap"] &&
           perubahan_params["tarikh_dijangka_siap"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
          {:ok, date} -> date
          _ -> selected.tarikh_dijangka_siap
        end
      else
        nil
      end

    attrs = %{
      tajuk: perubahan_params["tajuk"],
      jenis: perubahan_params["jenis"],
      modul_terlibat: perubahan_params["modul_terlibat"],
      tarikh_dibuat: tarikh_dibuat,
      tarikh_dijangka_siap: tarikh_dijangka_siap,
      status: selected.status,
      keutamaan: empty_to_nil(perubahan_params["keutamaan"]),
      justifikasi: empty_to_nil(perubahan_params["justifikasi"]),
      kesan: empty_to_nil(perubahan_params["kesan"]),
      catatan: empty_to_nil(perubahan_params["catatan"])
    }

    case PermohonanPerubahan.update_permohonan_perubahan(selected, attrs) do
      {:ok, _updated} ->
        perubahan = PermohonanPerubahan.list_by_project(project_id)

        {:noreply,
         socket
         |> assign(:perubahan, perubahan)
         |> assign(:show_edit_modal, false)
         |> assign(:selected_perubahan, nil)
         |> assign(:form, to_form(%{}, as: :perubahan))
         |> put_flash(:info, "Perubahan berjaya dikemaskini")}

      {:error, changeset} ->
        form = to_form(changeset, as: :perubahan)

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Gagal mengemaskini. Sila semak maklumat.")}
    end
  end

  # --- Penempatan (tab) create modal ---
  def handle_event("open_penempatan_create_modal", _params, socket) do
    project = socket.assigns.project

    form_data = %{
      "nama_sistem" => project.nama || "",
      "versi" => "1.0.0",
      "lokasi" => "",
      "jenis" => "Produksi",
      "status" => "",
      "tarikh_penempatan" => "",
      "tarikh_dijangka" => "",
      "url" => "",
      "catatan" => "",
      "dibina_oleh" => ""
    }

    {:noreply,
     socket
     |> assign(:penempatan_show_create_modal, true)
     |> assign(:penempatan_form, to_form(form_data, as: :penempatan))
     |> assign(:penempatan_mode, "create")
     |> assign(:penempatan_editing_id, nil)}
  end

  def handle_event("close_penempatan_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:penempatan_show_create_modal, false)
     |> assign(:penempatan_form, to_form(%{}, as: :penempatan))
     |> assign(:penempatan_mode, "create")
     |> assign(:penempatan_editing_id, nil)}
  end

  def handle_event("maklumbalas_open_create_modal", _params, socket) do
    project = socket.assigns.project
    project_id = project && project.id
    jabatan_from_project = (project && Map.get(project, :jabatan)) || ""

    default =
      %{
        "project_id" => to_string(project_id),
        "tarikh_maklumbalas" => Date.utc_today() |> Date.to_iso8601(),
        "jabatan" => jabatan_from_project,
        "responden" => "",
        "butiran" => ""
      }

    form = to_form(default, as: :maklumbalas)

    {:noreply,
     socket
     |> assign(:maklumbalas_show_create_modal, true)
     |> assign(:maklumbalas_form, form)}
  end

  def handle_event("maklumbalas_close_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:maklumbalas_show_create_modal, false)
     |> assign(:maklumbalas_form, to_form(%{}, as: :maklumbalas))}
  end

  def handle_event("validate_maklumbalas", %{"maklumbalas" => params}, socket) do
    form = to_form(params, as: :maklumbalas)
    {:noreply, assign(socket, :maklumbalas_form, form)}
  end

  def handle_event("maklumbalas_create", %{"maklumbalas" => params}, socket) do
    project = socket.assigns.project
    project_id = project && project.id

    upload_meta =
      consume_uploaded_entries(socket, :maklumbalas_file, fn %{path: path}, entry ->
        filename = maklumbalas_upload_filename(project_id, entry)
        dest_dir = Path.join(File.cwd!(), "priv/static/uploads/maklumbalas")
        File.mkdir_p!(dest_dir)
        dest = Path.join(dest_dir, filename)
        File.cp!(path, dest)
        {:ok, %{path: "maklumbalas/#{filename}", original_name: entry.client_name}}
      end)
      |> List.first()

    {attachment_path, attachment_original_name} =
      case upload_meta do
        %{path: p, original_name: n} -> {p, n}
        _ -> {nil, nil}
      end

    tarikh_maklumbalas =
      if params["tarikh_maklumbalas"] && params["tarikh_maklumbalas"] != "" do
        case Date.from_iso8601(params["tarikh_maklumbalas"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    # Jabatan dari projek (penugasan / approved_projects)
    jabatan_from_project = (project && Map.get(project, :jabatan)) || ""

    attrs = %{
      project_id: project_id,
      tarikh_maklumbalas: tarikh_maklumbalas,
      jabatan: params["jabatan"] || jabatan_from_project,
      responden: params["responden"] || "",
      butiran: params["butiran"] || "",
      attachment_path: attachment_path,
      attachment_original_name: attachment_original_name
    }

    case Maklumbalas.create_maklumbalas(attrs) do
      {:ok, _maklumbalas} ->
        list = Maklumbalas.list_by_project_id(project_id)

        {:noreply,
         socket
         |> assign(:maklumbalas_list, list)
         |> assign(:maklumbalas_show_create_modal, false)
         |> assign(:maklumbalas_form, to_form(%{}, as: :maklumbalas))
         |> put_flash(:info, "Maklumbalas berjaya didaftarkan.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = to_form(changeset, as: :maklumbalas)

        {:noreply,
         socket
         |> assign(:maklumbalas_form, form)
         |> put_flash(:error, "Sila betulkan ralat dalam borang.")}
    end
  end

  def handle_event("maklumbalas_open_edit_modal", %{"id" => id}, socket) do
    maklumbalas =
      case Integer.parse(to_string(id)) do
        {int_id, _} -> Maklumbalas.get_maklumbalas(int_id)
        :error -> nil
      end

    if maklumbalas && maklumbalas.project_id == socket.assigns.project.id do
      form_data = %{
        "tarikh_maklumbalas" =>
          if(maklumbalas.tarikh_maklumbalas,
            do: Calendar.strftime(maklumbalas.tarikh_maklumbalas, "%Y-%m-%d"),
            else: ""
          ),
        "jabatan" => maklumbalas.jabatan || "",
        "responden" => maklumbalas.responden || "",
        "butiran" => maklumbalas.butiran || ""
      }

      form = to_form(form_data, as: :maklumbalas)

      {:noreply,
       socket
       |> assign(:maklumbalas_show_edit_modal, true)
       |> assign(:maklumbalas_editing, maklumbalas)
       |> assign(:maklumbalas_form, form)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("maklumbalas_close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:maklumbalas_show_edit_modal, false)
     |> assign(:maklumbalas_editing, nil)
     |> assign(:maklumbalas_form, to_form(%{}, as: :maklumbalas))}
  end

  def handle_event("maklumbalas_update", %{"maklumbalas" => params}, socket) do
    editing = socket.assigns[:maklumbalas_editing]
    project = socket.assigns.project
    project_id = project && project.id

    if editing && project_id do
      upload_meta =
        consume_uploaded_entries(socket, :maklumbalas_file, fn %{path: path}, entry ->
          filename = maklumbalas_upload_filename(project_id, entry)
          dest_dir = Path.join(File.cwd!(), "priv/static/uploads/maklumbalas")
          File.mkdir_p!(dest_dir)
          dest = Path.join(dest_dir, filename)
          File.cp!(path, dest)
          {:ok, %{path: "maklumbalas/#{filename}", original_name: entry.client_name}}
        end)
        |> List.first()

      tarikh_maklumbalas =
        if params["tarikh_maklumbalas"] && params["tarikh_maklumbalas"] != "" do
          case Date.from_iso8601(params["tarikh_maklumbalas"]) do
            {:ok, date} -> date
            _ -> editing.tarikh_maklumbalas
          end
        else
          editing.tarikh_maklumbalas
        end

      jabatan_from_project = (project && Map.get(project, :jabatan)) || ""

      base_attrs = %{
        tarikh_maklumbalas: tarikh_maklumbalas,
        jabatan: params["jabatan"] || jabatan_from_project || editing.jabatan,
        responden: params["responden"] || "",
        butiran: params["butiran"] || ""
      }

      attrs =
        case upload_meta do
          %{path: p, original_name: n} ->
            base_attrs
            |> Map.put(:attachment_path, p)
            |> Map.put(:attachment_original_name, n)

          _ ->
            base_attrs
        end

      case Maklumbalas.update_maklumbalas(editing, attrs) do
        {:ok, _updated} ->
          list = Maklumbalas.list_by_project_id(project_id)

          {:noreply,
           socket
           |> assign(:maklumbalas_list, list)
           |> assign(:maklumbalas_show_edit_modal, false)
           |> assign(:maklumbalas_editing, nil)
           |> assign(:maklumbalas_form, to_form(%{}, as: :maklumbalas))
           |> put_flash(:info, "Maklumbalas berjaya dikemaskini.")}

        {:error, %Ecto.Changeset{} = changeset} ->
          form = to_form(changeset, as: :maklumbalas)

          {:noreply,
           socket
           |> assign(:maklumbalas_form, form)
           |> put_flash(:error, "Sila betulkan ralat dalam borang.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_penempatan", %{"penempatan" => params}, socket) do
    form = to_form(params, as: :penempatan)
    {:noreply, assign(socket, :penempatan_form, form)}
  end

  @impl true
  def handle_event("open_penempatan_edit_modal", %{"id" => id}, socket) do
    project = socket.assigns.project

    penempatan =
      case Integer.parse(to_string(id)) do
        {int_id, _} -> Penempatans.get_penempatan(int_id)
        :error -> nil
      end

    if penempatan do
      form_data = %{
        "nama_sistem" => penempatan.nama_sistem || project.nama || "",
        "versi" => penempatan.versi || "1.0.0",
        "lokasi" => penempatan.lokasi || "",
        "jenis" => penempatan.jenis || "Produksi",
        "status" => penempatan.status || "",
        "tarikh_penempatan" =>
          if(penempatan.tarikh_penempatan,
            do: Calendar.strftime(penempatan.tarikh_penempatan, "%Y-%m-%d"),
            else: Date.utc_today() |> Date.to_iso8601()
          ),
        "tarikh_dijangka" =>
          if(penempatan.tarikh_dijangka,
            do: Calendar.strftime(penempatan.tarikh_dijangka, "%Y-%m-%d"),
            else: ""
          ),
        "url" => penempatan.url || "",
        "catatan" => penempatan.catatan || "",
        "dibina_oleh" => penempatan.dibina_oleh || ""
      }

      form = to_form(form_data, as: :penempatan)

      {:noreply,
       socket
       |> assign(:penempatan_show_create_modal, true)
       |> assign(:penempatan_form, form)
       |> assign(:penempatan_mode, "edit")
       |> assign(:penempatan_editing_id, penempatan.id)}
    else
      {:noreply, put_flash(socket, :error, "Penempatan tidak ditemui.")}
    end
  end

  def handle_event("create_penempatan", %{"penempatan" => params}, socket) do
    project_id = socket.assigns.project.id
    project = socket.assigns.project

    tarikh_penempatan = parse_date_param(params["tarikh_penempatan"])

    tarikh_dijangka = parse_date_param(params["tarikh_dijangka"])
    tarikh_dibina = parse_date_param(params["tarikh_dibina"])

    attrs = %{
      project_id: project_id,
      nama_sistem: params["nama_sistem"] || project.nama,
      versi: params["versi"] || "1.0.0",
      lokasi: params["lokasi"] || "",
      jenis: params["jenis"] || "Produksi",
      status: empty_to_nil(params["status"]),
      persekitaran: empty_to_nil(params["persekitaran"]),
      tarikh_penempatan: tarikh_penempatan,
      tarikh_dijangka: tarikh_dijangka,
      tarikh_dibina: tarikh_dibina,
      url: empty_to_nil(params["url"]),
      catatan: empty_to_nil(params["catatan"]),
      dibina_oleh: empty_to_nil(params["dibina_oleh"])
    }

    case Penempatans.create_penempatan(attrs) do
      {:ok, _} ->
        penempatan =
          get_penempatan_for_project(project_id, socket.assigns.current_scope, project)

        {:noreply,
         socket
         |> assign(:penempatan, penempatan)
         |> assign(:penempatan_show_create_modal, false)
         |> assign(:penempatan_form, to_form(%{}, as: :penempatan))
         |> assign(:penempatan_mode, "create")
         |> assign(:penempatan_editing_id, nil)
         |> put_flash(:info, "Penempatan berjaya didaftarkan")}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = to_form(changeset, as: :penempatan)

        {:noreply,
         socket
         |> assign(:penempatan_form, form)
         |> put_flash(:error, "Gagal mendaftar penempatan. Sila semak maklumat.")}
    end
  end

  @impl true
  def handle_event("delete_penempatan", %{"id" => id}, socket) do
    project = socket.assigns.project
    project_id = project.id

    penempatan =
      case Integer.parse(to_string(id)) do
        {int_id, _} -> Penempatans.get_penempatan(int_id)
        :error -> nil
      end

    socket =
      if penempatan do
        case Penempatans.delete_penempatan(penempatan) do
          {:ok, _} ->
            penempatan_list =
              get_penempatan_for_project(project_id, socket.assigns.current_scope, project)

            socket
            |> assign(:penempatan, penempatan_list)
            |> put_flash(:info, "Penempatan berjaya dipadam.")

          {:error, _} ->
            put_flash(socket, :error, "Gagal memadam penempatan. Sila cuba lagi.")
        end
      else
        put_flash(socket, :error, "Penempatan tidak ditemui.")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_penempatan", %{"penempatan" => params}, socket) do
    project = socket.assigns.project
    project_id = project.id
    editing_id = socket.assigns[:penempatan_editing_id]

    penempatan =
      case editing_id do
        nil ->
          nil

        int when is_integer(int) ->
          Penempatans.get_penempatan(int)

        other ->
          case Integer.parse(to_string(other)) do
            {int_id, _} -> Penempatans.get_penempatan(int_id)
            :error -> nil
          end
      end

    if penempatan do
      tarikh_penempatan =
        parse_date_param(params["tarikh_penempatan"]) ||
          penempatan.tarikh_penempatan ||
          Date.utc_today()

      tarikh_dijangka =
        parse_date_param(params["tarikh_dijangka"]) || penempatan.tarikh_dijangka

      tarikh_dibina =
        parse_date_param(params["tarikh_dibina"]) || penempatan.tarikh_dibina

      attrs = %{
        nama_sistem: params["nama_sistem"] || penempatan.nama_sistem || project.nama,
        versi: params["versi"] || penempatan.versi || "1.0.0",
        lokasi: params["lokasi"] || penempatan.lokasi || "",
        jenis: params["jenis"] || penempatan.jenis || "Produksi",
        status: empty_to_nil(params["status"]) || penempatan.status,
        tarikh_penempatan: tarikh_penempatan,
        tarikh_dijangka: tarikh_dijangka,
        tarikh_dibina: tarikh_dibina,
        url: empty_to_nil(params["url"]),
        catatan: empty_to_nil(params["catatan"]),
        dibina_oleh: empty_to_nil(params["dibina_oleh"])
      }

      case Penempatans.update_penempatan(penempatan, attrs) do
        {:ok, _} ->
          penempatan_list =
            get_penempatan_for_project(project_id, socket.assigns.current_scope, project)

          {:noreply,
           socket
           |> assign(:penempatan, penempatan_list)
           |> assign(:penempatan_show_create_modal, false)
           |> assign(:penempatan_form, to_form(%{}, as: :penempatan))
           |> assign(:penempatan_mode, "create")
           |> assign(:penempatan_editing_id, nil)
           |> put_flash(:info, "Penempatan berjaya dikemaskini.")}

        {:error, %Ecto.Changeset{} = changeset} ->
          form = to_form(changeset, as: :penempatan)

          {:noreply,
           socket
           |> assign(:penempatan_form, form)
           |> assign(:penempatan_mode, "edit")
           |> put_flash(:error, "Gagal mengemaskini penempatan. Sila semak maklumat.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Penempatan tidak ditemui.")}
    end
  end

  @impl true
  def handle_info(:close_settings_modal, socket) do
    {:noreply, assign(socket, :show_settings_modal, false)}
  end

  defp parse_date_param(nil), do: nil
  defp parse_date_param(""), do: nil

  defp parse_date_param(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_perubahan_id(perubahan_id) when is_binary(perubahan_id) do
    case Integer.parse(perubahan_id) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp parse_perubahan_id(perubahan_id) when is_integer(perubahan_id), do: perubahan_id
  defp parse_perubahan_id(_), do: nil

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(s) when is_binary(s), do: s
  defp empty_to_nil(other), do: other

  defp maybe_update(map, _key, nil), do: map
  defp maybe_update(map, key, value), do: Map.put(map, key, value)

  defp editing_penyerahan_fallback(socket, penyerahan_id) do
    Enum.find(socket.assigns.penyerahan || [], fn p ->
      to_string(p.id) == to_string(penyerahan_id)
    end) ||
      socket.assigns[:penyerahan_editing_penyerahan]
  end

  defp put_module_pagination_assigns(socket) do
    modules = socket.assigns.modules || []
    page_size = socket.assigns.module_page_size || @module_page_size
    total = length(modules)
    total_pages = if total == 0, do: 1, else: div(total + page_size - 1, page_size)
    page = min(max(socket.assigns.module_page || 1, 1), total_pages)
    start = (page - 1) * page_size
    paginated = Enum.slice(modules, start, page_size)
    page_numbers = module_page_numbers_for_pagination(page, total_pages)

    socket
    |> assign(:module_page, page)
    |> assign(:module_total_modules, total)
    |> assign(:module_total_pages, total_pages)
    |> assign(:module_paginated_modules, paginated)
    |> assign(:module_page_numbers, page_numbers)
  end

  defp module_page_numbers_for_pagination(_current, total_pages) when total_pages <= 7 do
    1..total_pages |> Enum.to_list()
  end

  defp module_page_numbers_for_pagination(current, total_pages) do
    cond do
      current <= 3 ->
        [1, 2, 3, 4, :ellipsis, total_pages]

      current >= total_pages - 2 ->
        [1, :ellipsis, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, :ellipsis, current - 1, current, current + 1, :ellipsis, total_pages]
    end
  end

  # Ujian Keselamatan (tab) helpers
  defp maybe_cancel_kes_file_uploads(socket) do
    entries = get_in(socket.assigns, [:uploads, :kes_file, :entries]) || []

    Enum.reduce(entries, socket, fn entry, acc ->
      cancel_upload(acc, :kes_file, entry.ref)
    end)
  rescue
    _ -> socket
  end

  defp maybe_cancel_kes_edit_file_uploads(socket) do
    entries = get_in(socket.assigns, [:uploads, :kes_edit_file, :entries]) || []

    Enum.reduce(entries, socket, fn entry, acc ->
      cancel_upload(acc, :kes_edit_file, entry.ref)
    end)
  rescue
    _ -> socket
  end

  defp maybe_cancel_penyerahan_uploads(socket) do
    socket
    |> cancel_penyerahan_upload_entries(:penyerahan_manual)
    |> cancel_penyerahan_upload_entries(:penyerahan_surat)
  rescue
    _ -> socket
  end

  defp cancel_penyerahan_upload_entries(socket, name) do
    entries = get_in(socket.assigns, [:uploads, name, :entries]) || []

    Enum.reduce(entries, socket, fn entry, acc ->
      cancel_upload(acc, name, entry.ref)
    end)
  end

  defp kes_get_ujian_by_id(ujian_id, _ujian_id_str, _socket) when is_integer(ujian_id) do
    UjianKeselamatan.get_ujian_formatted(ujian_id)
  end

  defp kes_get_ujian_by_id(_ujian_id, ujian_id_str, socket) when is_binary(ujian_id_str) do
    if socket.assigns[:ujian_keselamatan] && length(socket.assigns.ujian_keselamatan) > 0 do
      Enum.find(socket.assigns.ujian_keselamatan, fn u -> u.id == ujian_id_str end)
    else
      nil
    end
  end

  defp kes_get_ujian_by_id(_, _, _), do: nil

  defp kes_parse_ujian_id(id) when is_integer(id), do: id

  defp kes_parse_ujian_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, _} -> int_id
      :error -> id
    end
  end

  defp kes_parse_ujian_id(_), do: nil

  defp kes_format_date_for_form(nil), do: ""
  defp kes_format_date_for_form(%Date{} = d), do: Calendar.strftime(d, "%Y-%m-%d")
  defp kes_format_date_for_form(_), do: ""

  defp maklumbalas_upload_filename(project_id, entry) do
    ext = Path.extname(entry.client_name || "")
    uniq = System.unique_integer([:positive])
    "maklumbalas_p#{project_id || "na"}_#{uniq}#{ext}"
  end

  # Builds a unique filename that keeps the original document name (sanitized).
  defp kes_upload_filename(project_id, entry) do
    ext = Path.extname(entry.client_name)
    base = entry.client_name |> Path.basename() |> Path.rootname()

    safe =
      base
      |> String.replace(~r/[^\p{L}\p{N}\s\-_.]/u, "")
      |> String.replace(~r/\s+/, "_")
      |> String.slice(0, 120)

    name_part = if safe == "", do: "dokumen", else: safe
    "#{project_id}_#{System.unique_integer([:positive])}_#{name_part}#{ext}"
  end

  # Returns display name for upload file (hides project_id and unique number prefix).
  def kes_display_filename(path) when is_binary(path) do
    base = Path.basename(path)

    case Regex.run(~r/^\d+_\d+_(.+)$/, base) do
      [_, rest] -> rest
      nil -> base
    end
  end

  def kes_display_filename(_), do: ""

  def kes_upload_error_to_string(:too_many_files), do: "Terlalu banyak fail dipilih (maks 1)"
  def kes_upload_error_to_string(:too_large), do: "Fail terlalu besar (maks 10MB)"
  def kes_upload_error_to_string(:not_accepted), do: "Jenis fail tidak diterima"
  def kes_upload_error_to_string(:external_client_failure), do: "Muat naik gagal"
  def kes_upload_error_to_string({:writer_failure, _}), do: "Gagal menyimpan fail"
  def kes_upload_error_to_string(other), do: "Ralat: #{inspect(other)}"

  defp kes_parse_date_param(""), do: nil
  defp kes_parse_date_param(nil), do: nil

  defp kes_parse_date_param(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp kes_parse_module_id_from_placeholder("module_" <> rest) do
    case Integer.parse(rest) do
      {id, _} -> id
      :error -> nil
    end
  end

  defp kes_parse_kes_id(kes_id) when is_integer(kes_id), do: kes_id

  defp kes_parse_kes_id(kes_id) when is_binary(kes_id) do
    case Integer.parse(kes_id) do
      {int_id, _} -> int_id
      :error -> kes_id
    end
  end

  # Penyerahan (delivery) - selaraskan dengan PenyerahanLive untuk tab projek
  defp versi_for_project(nil), do: "1.0.0"

  defp versi_for_project(project) do
    AnalisisDanRekabentuk.get_versi_by_project_ids([project.id])
    |> Map.get(project.id, "1.0.0")
  end

  defp get_penyerahan_for_project(project) do
    nama_sistem =
      if project,
        do: project.nama || "Sistem Pengurusan Permohonan",
        else: "Sistem Pengurusan Permohonan"

    versi = versi_for_project(project)

    jabatan =
      if project && Map.get(project, :jabatan) && project.jabatan != "" do
        project.jabatan
      else
        "Tidak Ditetapkan"
      end

    pengurus_projek =
      if project && Map.get(project, :pengurus_projek) && project.pengurus_projek != "" do
        project.pengurus_projek
      else
        "Tidak Ditetapkan"
      end

    project_id = project && Map.get(project, :id)

    penyerahans_from_db =
      if project_id do
        Penyerahans.list_penyerahans_by_project_id(project_id)
      else
        []
      end

    Enum.map(penyerahans_from_db, fn p ->
      %{
        id: p.id,
        nama_sistem: nama_sistem,
        versi: versi,
        tarikh_penyerahan: p.tarikh_penyerahan,
        penerima: jabatan,
        pembangun_team: nil,
        pengurus_projek: pengurus_projek,
        manual_pengguna: p.manual_pengguna,
        manual_pengguna_nama: p.manual_pengguna_nama || p.manual_pengguna,
        surat_akuan_penerimaan: p.surat_akuan_penerimaan,
        surat_akuan_nama: p.surat_akuan_nama || p.surat_akuan_penerimaan
      }
    end)
  end

  # Penempatan (deployment) - data from DB, same source as halaman penempatan (PenempatanLive)
  defp get_penempatan_for_project(project_id, _current_scope, project) do
    list = Penempatans.list_penempatans_by_project_ids([project_id])
    versi_by_id = AnalisisDanRekabentuk.get_versi_by_project_ids([project_id])
    project_nama = project && project.nama

    Enum.map(list, fn p ->
      nama_sistem = p.nama_sistem || project_nama
      versi = p.versi || Map.get(versi_by_id, p.project_id, p.versi)

      penempatan_struct_to_display_map(p)
      |> Map.put(:nama_sistem, nama_sistem || p.nama_sistem)
      |> Map.put(:versi, versi || p.versi)
      |> Map.put(:projek_id, p.project_id)
    end)
  end

  defp penempatan_struct_to_display_map(p) do
    %{
      id: p.id,
      nama_sistem: p.nama_sistem,
      versi: p.versi,
      lokasi: p.lokasi,
      tarikh_penempatan: p.tarikh_penempatan,
      tarikh_dijangka: p.tarikh_dijangka,
      status: p.status,
      jenis: p.jenis,
      persekitaran: p.persekitaran,
      url: p.url,
      catatan: p.catatan,
      dibina_oleh: p.dibina_oleh,
      disemak_oleh: p.disemak_oleh,
      diluluskan_oleh: p.diluluskan_oleh,
      tarikh_dibina: p.tarikh_dibina,
      tarikh_disemak: p.tarikh_disemak,
      tarikh_diluluskan: p.tarikh_diluluskan,
      projek_id: p.project_id
    }
  end

  # Prepare jadual (Gantt) data for a single project
  defp prepare_jadual_data_for_project(project) do
    today = Date.utc_today()
    tarikh_mula = project.tarikh_mula || today
    tarikh_siap = project.tarikh_siap || today

    projects =
      if project.tarikh_mula && project.tarikh_siap do
        min_date = Date.add(tarikh_mula, -30)
        max_date = Date.add(tarikh_siap, 30)
        total_days = Date.diff(max_date, min_date)

        start_offset = Date.diff(tarikh_mula, min_date)
        duration = Date.diff(tarikh_siap, tarikh_mula)

        progress =
          if project.status == "Selesai" do
            100
          else
            cond do
              duration <= 0 -> 0
              Date.diff(today, tarikh_mula) < 0 -> 0
              Date.diff(today, tarikh_mula) >= duration -> 95
              true -> div(Date.diff(today, tarikh_mula) * 100, duration)
            end
          end

        project_with_positions =
          Map.merge(project, %{
            start_offset: start_offset,
            duration: duration,
            progress: progress,
            start_percent: if(total_days > 0, do: start_offset / total_days * 100, else: 0),
            width_percent: if(total_days > 0, do: duration / total_days * 100, else: 0),
            isu: Map.get(project, :isu, "Tiada"),
            tindakan: Map.get(project, :tindakan, "-")
          })

        gantt_data = %{
          projects: [project_with_positions],
          min_date: min_date,
          max_date: max_date,
          total_days: total_days,
          today_offset: Date.diff(today, min_date),
          today_percent:
            if(total_days > 0, do: Date.diff(today, min_date) / total_days * 100, else: 0)
        }

        month_labels = generate_jadual_month_labels(min_date, max_date)
        {gantt_data, month_labels}
      else
        {%{projects: [], min_date: today, max_date: today, total_days: 0, today_percent: 0}, []}
      end

    projects
  end

  defp generate_jadual_month_labels(min_date, max_date) do
    current = %Date{year: min_date.year, month: min_date.month, day: 1}
    end_date = %Date{year: max_date.year, month: max_date.month, day: 1}
    total_days = Date.diff(max_date, min_date)
    generate_jadual_month_labels_recursive(current, end_date, total_days, [])
  end

  defp generate_jadual_month_labels_recursive(current, end_date, total_days, acc) do
    if Date.compare(current, end_date) != :gt do
      month_name =
        case current.month do
          1 -> "Jan"
          2 -> "Feb"
          3 -> "Mac"
          4 -> "Apr"
          5 -> "Mei"
          6 -> "Jun"
          7 -> "Jul"
          8 -> "Ogs"
          9 -> "Sep"
          10 -> "Okt"
          11 -> "Nov"
          12 -> "Dis"
          _ -> "?"
        end

      days_in_month = Date.days_in_month(current)
      width_percent = if total_days > 0, do: days_in_month / total_days * 100, else: 0

      month_data = %{month: month_name, year: current.year, width_percent: width_percent}

      next_month =
        if current.month == 12 do
          %Date{year: current.year + 1, month: 1, day: 1}
        else
          %Date{year: current.year, month: current.month + 1, day: 1}
        end

      generate_jadual_month_labels_recursive(
        next_month,
        end_date,
        total_days,
        acc ++ [month_data]
      )
    else
      acc
    end
  end

  defp jadual_status_color(status) do
    case status do
      "Selesai" -> "#10b981"
      "Dalam Pembangunan" -> "#3b82f6"
      "Ujian Penerimaan Pengguna" -> "#8b5cf6"
      "Ditangguhkan" -> "#f59e0b"
      "Pengurusan Perubahan" -> "#ec4899"
      _ -> "#6b7280"
    end
  end

  defp jadual_status_badge_class(status) do
    case status do
      "Selesai" -> "bg-green-100 text-green-800"
      "Dalam Pembangunan" -> "bg-blue-100 text-blue-800"
      "Ujian Penerimaan Pengguna" -> "bg-purple-100 text-purple-800"
      "Ditangguhkan" -> "bg-amber-100 text-amber-800"
      "Pengurusan Perubahan" -> "bg-pink-100 text-pink-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  # Get a single project by ID from database
  defp get_project_by_id(project_id, current_scope, user_role) do
    current_user_id = current_scope.user.id

    # Fetch project from database based on user role
    project =
      case user_role do
        "ketua penolong pengarah" ->
          # Directors/Admins can view any project
          Projects.get_project_by_id(project_id)

        "ketua unit" ->
          # Ketua unit can view any project (they control assignments)
          Projects.get_project_by_id(project_id)

        "pembangun sistem" ->
          # Developers can only view projects where their no_kp is in the approved_project's pembangun_sistem
          case Projects.get_project_by_id(project_id) do
            nil ->
              nil

            p ->
              user_no_kp = current_scope.user.no_kp
              if Projects.has_access_to_project?(p, user_no_kp), do: p, else: nil
          end

        "pengurus projek" ->
          # Project managers can view projects where they are assigned via:
          # 1. approved_project.pengurus_projek (by no_kp), OR
          # 2. approved_project.pembangun_sistem (since assigned PMs are auto-added), OR
          # 3. project_manager_id (legacy/fallback)
          case Projects.get_project_by_id(project_id) do
            nil ->
              nil

            p ->
              user_no_kp = current_scope.user.no_kp
              # Check if they have PM access (via pengurus_projek assignment)
              has_pm_access = Projects.has_pm_access_to_project?(p, current_user_id, user_no_kp)
              # Also check if they're in pembangun_sistem list
              has_dev_access = Projects.has_access_to_project?(p, user_no_kp)
              # Fallback to project_manager_id check
              has_legacy_access = p.project_manager_id == current_user_id

              if has_pm_access || has_dev_access || has_legacy_access, do: p, else: nil
          end

        _ ->
          nil
      end

    # Format project for display if found
    if project do
      project
      |> Projects.format_project_for_display()
    else
      nil
    end
  end

  # UAT tab: build ujian list based purely on stored records per project.
  # This ensures setiap rekod dalam jadual `ujian_penerimaan_pengguna` untuk projek tersebut dipaparkan.
  defp build_uat_list(project_id, _current_scope) when is_integer(project_id) do
    UjianPenerimaanPengguna.list_ujian_for_project(project_id)
  end

  defp uat_paginate(ujian, page, per_page) do
    start_index = (page - 1) * per_page
    Enum.slice(ujian, start_index, per_page)
  end

  defp uat_total_pages(0, _per_page), do: 1

  defp uat_total_pages(total, per_page) do
    pages = div(total, per_page)
    if rem(total, per_page) == 0, do: pages, else: pages + 1
  end

  defp parse_ujian_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> id
    end
  end

  defp parse_ujian_id(id) when is_integer(id), do: id
  defp parse_ujian_id(_), do: nil

  defp parse_kes_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> id
    end
  end

  defp parse_kes_id(id) when is_integer(id), do: id
  defp parse_kes_id(_), do: nil

  defp uat_parse_date(nil, default), do: default
  defp uat_parse_date("", default), do: default

  defp uat_parse_date(str, default) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> default
    end
  end

  defp uat_empty_to_nil(""), do: nil
  defp uat_empty_to_nil(nil), do: nil
  defp uat_empty_to_nil(s) when is_binary(s), do: if(String.trim(s) == "", do: nil, else: s)
  defp uat_empty_to_nil(other), do: other

  # Papar status dalam dropdown modal = status dari lajur jadual yang diklik.
  # row_status ialah nilai yang dihantar dari baris jadual (phx-value-status).
  def uat_status_display_value(show_edit_modal, row_status, _editing_ujian, form) do
    raw =
      if show_edit_modal && is_binary(row_status) && row_status != "" do
        row_status
      else
        case form[:status] do
          %{value: v} when is_binary(v) and v != "" -> v
          _ -> nil
        end
      end

    uat_status_normalize(raw)
  end

  defp uat_status_normalize(nil), do: "Dalam Progres"
  defp uat_status_normalize(""), do: "Dalam Progres"
  defp uat_status_normalize("Lulus"), do: "Lulus"
  defp uat_status_normalize("Gagal"), do: "Gagal"
  defp uat_status_normalize(_), do: "Dalam Progres"
end
