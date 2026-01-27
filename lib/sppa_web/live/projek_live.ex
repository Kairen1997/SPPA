defmodule SppaWeb.ProjekLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Handle show action - view project details
    mount_show(String.to_integer(id), socket)
  end

  def mount(_params, _session, socket) do
    # Handle index action - list all projects
    mount_index(socket)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "soal-selidik")
    normalized_tab = normalize_tab(tab)

    # If we have a project_id but no project loaded yet, load it now
    socket =
      socket
      |> maybe_load_project(params)
      |> assign(:current_tab, normalized_tab)
      |> maybe_assign_modules(normalized_tab)
      |> maybe_assign_change_requests(normalized_tab)

    {:noreply, socket}
  end

  # Load project if project_id exists in assigns but project is not yet loaded
  defp maybe_load_project(socket, _params) do
    project_id = socket.assigns[:project_id]

    if project_id && !socket.assigns[:project] do
      user_role =
        socket.assigns.current_scope && socket.assigns.current_scope.user &&
          socket.assigns.current_scope.user.role

      project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)

      if project do
        project_name = Map.get(project, :nama) || Map.get(project, :name) || "Projek"

        socket
        |> assign(:project, project)
        |> assign(:soal_selidik_document, get_soal_selidik_document(project.nama))
        |> assign(
          :analisis_pdf_data,
          Sppa.AnalisisDanRekabentuk.pdf_data(
            nama_projek: project_name,
            modules: Sppa.AnalisisDanRekabentuk.initial_modules()
          )
        )
        |> assign(:modules, get_modules_from_analisis_dan_rekabentuk())
        |> assign(:change_requests, get_change_requests())
      else
        socket
      end
    else
      socket
    end
  end

  defp maybe_assign_modules(socket, "Pengaturcaraan") do
    modules = get_modules_from_analisis_dan_rekabentuk()
    assign(socket, :modules, modules)
  end

  defp maybe_assign_modules(socket, _) do
    # Ensure modules is always assigned, even if empty
    if Map.has_key?(socket.assigns, :modules) do
      socket
    else
      assign(socket, :modules, [])
    end
  end

  defp maybe_assign_change_requests(socket, "Pengurus Perubahan") do
    change_requests = get_change_requests()
    assign(socket, :change_requests, change_requests)
  end

  defp maybe_assign_change_requests(socket, _) do
    # Ensure change_requests is always assigned, even if empty
    if Map.has_key?(socket.assigns, :change_requests) do
      socket
    else
      assign(socket, :change_requests, [])
    end
  end

  defp normalize_tab("soal-selidik"), do: "Soal Selidik"
  defp normalize_tab("analisis-dan-rekabentuk"), do: "Analisis dan Rekabentuk"
  defp normalize_tab("jadual-projek"), do: "Jadual Projek"
  defp normalize_tab("pengaturcaraan"), do: "Pengaturcaraan"
  defp normalize_tab("pengurus-perubahan"), do: "Pengurus Perubahan"
  defp normalize_tab("ujian-keselamatan"), do: "Ujian Keselamatan"
  defp normalize_tab("maklumbalas-pelanggan"), do: "Maklumbalas Pelanggan"
  defp normalize_tab(_), do: "Soal Selidik"

  # Convert phase name (fasa) to tab slug for navigation
  def fasa_to_tab_slug(fasa) when is_binary(fasa) do
    fasa_lower = String.downcase(fasa) |> String.trim()

    case fasa_lower do
      "soal selidik" -> "soal-selidik"
      "analisis dan rekabentuk" -> "analisis-dan-rekabentuk"
      "jadual projek" -> "jadual-projek"
      "pengaturcaraan" -> "pengaturcaraan"
      "pengurusan perubahan" -> "pengurus-perubahan"
      "pengurus perubahan" -> "pengurus-perubahan"
      "uat" -> "uat"
      "ujian keselamatan" -> "ujian-keselamatan"
      "penempatan" -> "penempatan"
      "penyerahan" -> "penyerahan"
      "maklumbalas pelanggan" -> "maklumbalas-pelanggan"
    end
  end

  def fasa_to_tab_slug(_), do: "soal-selidik"

  # Helper function to build navigation path with tab parameter
  def build_project_navigate_path(project, user_role) do
    tab_slug = fasa_to_tab_slug(project.fasa)
    base_path = if(user_role == "pembangun sistem",
      do: "/projek/#{project.id}/details",
      else: "/projek/#{project.id}"
    )
    "#{base_path}?tab=#{tab_slug}"
  end

  defp mount_index(socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Senarai Projek")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:page, 1)
        |> assign(:per_page, 10)
        |> assign(:search_term, "")
        |> assign(:status_filter, "")
        |> assign(:fasa_filter, "")

      if connected?(socket) do
        # Mock data - will be replaced with database queries later
        # Filter projects based on user role
        all_projects = list_projects(socket.assigns.current_scope, user_role)

        filtered_projects =
          filter_projects(
            all_projects,
            socket.assigns.search_term,
            socket.assigns.status_filter,
            socket.assigns.fasa_filter
          )

        {paginated_projects, total_pages} =
          paginate_projects(filtered_projects, socket.assigns.page, socket.assigns.per_page)

        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
        notifications_count = length(activities)

        {:ok,
         socket
         |> assign(:projects, paginated_projects)
         |> assign(:all_projects, all_projects)
         |> assign(:filtered_projects, filtered_projects)
         |> assign(:total_pages, total_pages)
         |> assign(:total_count, length(filtered_projects))
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        {:ok,
         socket
         |> assign(:projects, [])
         |> assign(:all_projects, [])
         |> assign(:filtered_projects, [])
         |> assign(:total_pages, 0)
         |> assign(:total_count, 0)
         |> assign(:activities, [])
         |> assign(:notifications_count, 0)}
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

  defp mount_show(project_id, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Butiran Projek")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:project_id, project_id)

      # Load project immediately, even if not connected yet, to avoid showing list view
      project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)

      if project do
        project_name = Map.get(project, :nama) || Map.get(project, :name) || "Projek"

        activities =
          if connected?(socket) do
            Projects.list_recent_activities(socket.assigns.current_scope, 10)
          else
            []
          end

        notifications_count = length(activities)

        {:ok,
         socket
         |> assign(:project, project)
         |> assign(:projects, [])
         |> assign(:current_tab, "Soal Selidik")
         |> assign(:soal_selidik_document, get_soal_selidik_document(project.nama))
         |> assign(
           :analisis_pdf_data,
           Sppa.AnalisisDanRekabentuk.pdf_data(
             nama_projek: project_name,
             modules: Sppa.AnalisisDanRekabentuk.initial_modules()
           )
         )
         |> assign(:modules, get_modules_from_analisis_dan_rekabentuk())
         |> assign(:change_requests, get_change_requests())
         |> assign(:page, 1)
         |> assign(:per_page, 10)
         |> assign(:total_pages, 0)
         |> assign(:total_count, 0)
         |> assign(:search_term, "")
         |> assign(:status_filter, "")
         |> assign(:fasa_filter, "")
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        activities =
          if connected?(socket) do
            Projects.list_recent_activities(socket.assigns.current_scope, 10)
          else
            []
          end

        notifications_count = length(activities)

        socket =
          socket
          |> assign(:project, nil)
          |> assign(:projects, [])
          |> assign(:page, 1)
          |> assign(:per_page, 10)
          |> assign(:total_pages, 0)
          |> assign(:total_count, 0)
          |> assign(:search_term, "")
          |> assign(:status_filter, "")
          |> assign(:fasa_filter, "")
          |> assign(:activities, activities)
          |> assign(:notifications_count, notifications_count)
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
  def handle_event("change_page", %{"page" => page}, socket) do
    page = String.to_integer(page)

    filtered_projects =
      filter_projects(
        socket.assigns.all_projects,
        socket.assigns.search_term,
        socket.assigns.status_filter,
        socket.assigns.fasa_filter
      )

    {paginated_projects, total_pages} =
      paginate_projects(filtered_projects, page, socket.assigns.per_page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:projects, paginated_projects)
     |> assign(:filtered_projects, filtered_projects)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, length(filtered_projects))}
  end

  @impl true
  def handle_event("filter_projects", params, socket) do
    search_term = Map.get(params, "search_term", "") |> String.trim()
    status_filter = Map.get(params, "status_filter", "")
    fasa_filter = Map.get(params, "fasa_filter", "")

    filtered_projects =
      filter_projects(socket.assigns.all_projects, search_term, status_filter, fasa_filter)

    {paginated_projects, total_pages} =
      paginate_projects(filtered_projects, 1, socket.assigns.per_page)

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:status_filter, status_filter)
     |> assign(:fasa_filter, fasa_filter)
     |> assign(:page, 1)
     |> assign(:projects, paginated_projects)
     |> assign(:filtered_projects, filtered_projects)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, length(filtered_projects))}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {paginated_projects, total_pages} =
      paginate_projects(socket.assigns.all_projects, 1, socket.assigns.per_page)

    {:noreply,
     socket
     |> assign(:search_term, "")
     |> assign(:status_filter, "")
     |> assign(:fasa_filter, "")
     |> assign(:page, 1)
     |> assign(:projects, paginated_projects)
     |> assign(:filtered_projects, socket.assigns.all_projects)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, length(socket.assigns.all_projects))}
  end

  # Fetches projects from database based on user role:
  # - Developers see projects where they are assigned as developer
  # - Project managers see projects where they are assigned as project manager
  # - Directors/Admins see all projects
  defp list_projects(current_scope, user_role) do
    projects =
      case user_role do
        "ketua penolong pengarah" ->
          # Directors/Admins see all projects
          Projects.list_all_projects()

        "pembangun sistem" ->
          # Developers see projects where they are assigned as developer
          Projects.list_projects_for_pembangun_sistem(current_scope)

        "pengurus projek" ->
          # Project managers see projects where they are assigned as project manager
          Projects.list_projects_for_pengurus_projek(current_scope)

        _ ->
          # Default: return empty list for unknown roles
          []
      end

    # Normalize status for consistency
    Enum.map(projects, &normalize_project_status/1)
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

        "pembangun sistem" ->
          # Developers can only view projects where they are assigned as developer
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.developer_id == current_user_id, do: p, else: nil
          end

        "pengurus projek" ->
          # Project managers can only view projects where they are assigned as project manager
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.project_manager_id == current_user_id, do: p, else: nil
          end

        _ ->
          nil
      end

    # Format project for display if found
    if project do
      project
      |> Projects.format_project_for_display()
      |> normalize_project_status()
    else
      nil
    end
  end

  defp normalize_project_status(project) do
    Map.update!(project, :status, &normalize_status/1)
  end

  defp normalize_status(status) do
    case status do
      "Selesai" -> "Selesai"
      "Dalam Pembangunan" -> "Dalam Pembangunan"
      _ -> "Dalam Pembangunan"
    end
  end

  # Filter projects based on search term, status, and fasa
  defp filter_projects(projects, search_term, status_filter, fasa_filter) do
    projects
    |> filter_by_search(search_term)
    |> filter_by_status(status_filter)
    |> filter_by_fasa(fasa_filter)
  end

  defp filter_by_search(projects, ""), do: projects

  defp filter_by_search(projects, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(projects, fn project ->
      String.contains?(String.downcase(project.nama || ""), search_lower) ||
        String.contains?(String.downcase(project.pengurus_projek || ""), search_lower) ||
        String.contains?(String.downcase(project.pembangun_sistem || ""), search_lower)
    end)
  end

  defp filter_by_status(projects, ""), do: projects

  defp filter_by_status(projects, status) do
    Enum.filter(projects, fn project -> project.status == status end)
  end

  defp filter_by_fasa(projects, ""), do: projects

  defp filter_by_fasa(projects, fasa) do
    Enum.filter(projects, fn project -> project.fasa == fasa end)
  end

  # Paginate projects list
  defp paginate_projects(projects, page, per_page) do
    total_count = length(projects)
    total_pages = if total_count > 0, do: div(total_count + per_page - 1, per_page), else: 0
    page = max(1, min(page, total_pages))

    start_index = (page - 1) * per_page
    paginated = Enum.slice(projects, start_index, per_page)

    {paginated, total_pages}
  end

  # Get modules that were registered in Analisis dan Rekabentuk page
  # This uses the same initial modules structure as AnalisisDanRekabentukLive
  # TODO: In the future, this should be retrieved from a database or context module
  defp get_modules_from_analisis_dan_rekabentuk do
    [
      %{
        id: "module_1",
        number: 1,
        name: "Modul Pengurusan Pengguna",
        priority: "Tinggi",
        version: "1.0.0",
        status: "Sedang Dibangunkan",
        tarikh_mula: ~D[2024-10-01],
        tarikh_jangka_siap: ~D[2024-12-31],
        catatan: "Pembangunan sedang dijalankan mengikut jadual",
        functions: [
          %{id: "func_1_1", name: "Pendaftaran Pengguna", sub_functions: [%{id: "sub_1_1_1", name: "Pengesahan Pendaftaran"}]},
          %{id: "func_1_2", name: "Laman Log Masuk", sub_functions: []},
          %{id: "func_1_3", name: "Penyelenggaraan Profail", sub_functions: [%{id: "sub_1_3_1", name: "Pengemaskinian Profil"}]}
        ]
      },
      %{
        id: "module_2",
        number: 2,
        name: "Penyelenggaraan Kata Laluan",
        priority: "Tinggi",
        version: "1.0.0",
        status: "Belum Mula",
        tarikh_mula: nil,
        tarikh_jangka_siap: ~D[2025-01-15],
        catatan: nil,
        functions: []
      },
      %{
        id: "module_3",
        number: 3,
        name: "Modul Permohonan",
        priority: "Sangat Tinggi",
        version: "2.1.0",
        status: "Dalam Ujian",
        tarikh_mula: ~D[2024-09-15],
        tarikh_jangka_siap: ~D[2024-12-20],
        catatan: "Sedang menjalani ujian QA, menunggu maklumbalas",
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
        priority: "Sangat Tinggi",
        version: "2.0.0",
        status: "Selesai",
        tarikh_mula: ~D[2024-08-01],
        tarikh_jangka_siap: ~D[2024-11-30],
        catatan: "Modul telah selesai dan diserahkan untuk deployment",
        functions: [
          %{id: "func_4_1", name: "Verifikasi Permohonan", sub_functions: []},
          %{id: "func_4_2", name: "Kelulusan Permohonan", sub_functions: []}
        ]
      },
      %{
        id: "module_5",
        number: 5,
        name: "Modul Laporan",
        priority: "Sederhana",
        version: "1.5.0",
        status: "Sedang Dibangunkan",
        tarikh_mula: ~D[2024-12-01],
        tarikh_jangka_siap: ~D[2025-02-28],
        catatan: "Perlu integrasi dengan sistem sedia ada",
        functions: [
          %{id: "func_5_1", name: "Laporan mengikut tahun", sub_functions: []},
          %{id: "func_5_2", name: "Laporan mengikut lokasi/daerah", sub_functions: []}
        ]
      },
      %{
        id: "module_6",
        number: 6,
        name: "Modul Dashboard",
        priority: "Rendah",
        version: "1.0.0",
        status: "Belum Mula",
        tarikh_mula: nil,
        tarikh_jangka_siap: ~D[2025-03-15],
        catatan: nil,
        functions: []
      }
    ]
  end

  # Get change requests data - will be replaced with database query later
  defp get_change_requests do
    [
      %{
        id: "perubahan_1",
        tajuk: "Perubahan Modul Pengurusan Pengguna",
        jenis: "Perubahan Fungsian",
        modul_terlibat: "Modul Pengurusan Pengguna",
        status: "Dalam Semakan",
        tarikh_dibuat: ~D[2024-11-15],
        justifikasi: "Perlu menambah fungsi pengesahan dua faktor untuk meningkatkan keselamatan sistem",
        kesan: "Akan meningkatkan keselamatan sistem tetapi memerlukan latihan tambahan untuk pengguna",
        catatan: "Menunggu kelulusan dari ketua bahagian"
      },
      %{
        id: "perubahan_2",
        tajuk: "Pembaikan Bug dalam Modul Permohonan",
        jenis: "Pembaikan Bug",
        modul_terlibat: "Modul Permohonan",
        status: "Diluluskan",
        tarikh_dibuat: ~D[2024-11-20],
        justifikasi: "Bug menyebabkan data permohonan tidak dapat disimpan dengan betul",
        kesan: "Akan membetulkan masalah kritikal yang menghalang pengguna menyimpan permohonan",
        catatan: "Perlu diselesaikan segera"
      },
      %{
        id: "perubahan_3",
        tajuk: "Penambahbaikan Antara Muka Pengguna",
        jenis: "Penambahbaikan",
        modul_terlibat: "Modul Dashboard",
        status: "Ditolak",
        tarikh_dibuat: ~D[2024-11-25],
        justifikasi: "Meningkatkan pengalaman pengguna dengan reka bentuk yang lebih moden dan intuitif",
        kesan: "Akan meningkatkan kepuasan pengguna tetapi memerlukan masa pembangunan tambahan",
        catatan: "Ditangguhkan ke fasa seterusnya"
      },
      %{
        id: "perubahan_4",
        tajuk: "Integrasi dengan Sistem Luar",
        jenis: "Perubahan Fungsian",
        modul_terlibat: "Modul Laporan",
        status: "Dalam Semakan",
        tarikh_dibuat: ~D[2024-12-01],
        justifikasi: "Perlu integrasi dengan sistem e-Sabah untuk pertukaran data automatik",
        kesan: "Akan memudahkan pertukaran data tetapi memerlukan koordinasi dengan pihak luar",
        catatan: "Menunggu maklumbalas dari pihak e-Sabah"
      }
    ]
  end

  # Get soal selidik document data - will be replaced with database query later
  defp get_soal_selidik_document(system_name) do
    %{
      document_id: "JPKN-BPA-01/B1",
      system_name: system_name,
      sections: [
        %{
          title: "PENDAFTARAN DAN LOG MASUK",
          questions: [
            %{
              number: 1,
              question:
                "Adakah sistem perlu pendaftaran pengguna baru? (atau hanya menggunakan pengguna SM2)",
              response: nil,
              notes: nil
            },
            %{
              number: 2,
              question: "Apakah jenis login yang digunakan?",
              response: nil,
              notes: nil,
              options: ["ID/EMEL & Kata Laluan", "Single Sign On", "Integrasi sistem sedia ada"]
            },
            %{
              number: 3,
              question: "Adakah perlu log audit untuk semua aktiviti pengguna?",
              response: nil,
              notes: nil
            }
          ]
        },
        %{
          title: "PENGURUSAN DATA",
          questions: [
            %{
              number: 4,
              question: "Apakah jenis data yang perlu dikendalikan oleh sistem?",
              response: nil,
              notes: nil
            }
          ]
        }
      ]
    }
  end
end
