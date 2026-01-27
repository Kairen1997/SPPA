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

    socket =
      socket
      |> assign(:current_tab, normalized_tab)
      |> maybe_assign_modules(normalized_tab)
      |> maybe_assign_change_requests(normalized_tab)

    {:noreply, socket}
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

      if connected?(socket) do
        # Get project details - will be replaced with database query later
        project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)

        if project do
          project_name = Map.get(project, :nama) || Map.get(project, :name) || "Projek"

          activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
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
          activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
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
        {:ok,
         socket
         |> assign(:project, nil)
         |> assign(:projects, [])
         |> assign(:activities, [])
         |> assign(:notifications_count, 0)
         |> assign(:page, 1)
         |> assign(:per_page, 10)
         |> assign(:total_pages, 0)
         |> assign(:total_count, 0)
         |> assign(:search_term, "")
         |> assign(:status_filter, "")
         |> assign(:fasa_filter, "")}
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

  # Mock data function - will be replaced with database queries later
  # Filters projects based on user role:
  # - Developers see projects where they are assigned as developer
  # - Project managers see projects where they are assigned as project manager
  # - Directors/Admins see all projects
  defp list_projects(current_scope, user_role) do
    _current_user_id = current_scope.user.id

    all_projects = [
      %{
        id: 1,
        nama: "Sistem Pengurusan Projek A",
        status: "Dalam Pembangunan",
        fasa: "Pengaturcaraan",
        tarikh_mula: ~D[2024-01-15],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Ahmad bin Abdullah",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: 2,
        dokumen_sokongan: 3,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan"
      },
      %{
        id: 2,
        nama: "Sistem Analisis Data B",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2023-11-01],
        tarikh_siap: ~D[2024-05-15],
        pengurus_projek: "Siti Nurhaliza",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: 3,
        dokumen_sokongan: 2,
        isu: "Perlu pembetulan pada modul laporan",
        tindakan: "Selesaikan isu sebelum penyerahan"
      },
      %{
        id: 3,
        nama: "Portal E-Services C",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-06-01],
        tarikh_siap: ~D[2024-01-31],
        pengurus_projek: "Mohd Faizal",
        pembangun_sistem: "Ahmad bin Ismail",
        developer_id: 2,
        project_manager_id: 4,
        dokumen_sokongan: 5,
        isu: "Tiada",
        tindakan: "Projek telah diserahkan"
      },
      %{
        id: 4,
        nama: "Sistem Pengurusan Dokumen D",
        status: "Dalam Pembangunan",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: ~D[2024-02-01],
        tarikh_siap: ~D[2024-08-31],
        pengurus_projek: "Nurul Aina",
        pembangun_sistem: "Siti Fatimah",
        developer_id: 3,
        project_manager_id: 5,
        dokumen_sokongan: 1,
        isu: "Menunggu kelulusan bajet tambahan",
        tindakan: "Sambung semula selepas kelulusan"
      },
      %{
        id: 5,
        nama: "Aplikasi Mobile E",
        status: "Dalam Pembangunan",
        fasa: "Soal Selidik",
        tarikh_mula: ~D[2024-03-01],
        tarikh_siap: ~D[2024-09-30],
        pengurus_projek: "Lim Wei Ming",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: 2,
        dokumen_sokongan: 0,
        isu: "Masalah integrasi dengan API",
        tindakan: "Selesaikan integrasi API"
      },
      %{
        id: 6,
        nama: "Sistem Pengurusan Inventori F",
        status: "Dalam Pembangunan",
        fasa: "Jadual Projek",
        tarikh_mula: ~D[2024-04-15],
        tarikh_siap: ~D[2024-10-31],
        pengurus_projek: "Ahmad bin Abdullah",
        pembangun_sistem: "Ahmad bin Ismail",
        developer_id: 2,
        project_manager_id: 2,
        dokumen_sokongan: 4,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan modul inventori"
      },
      %{
        id: 7,
        nama: "Portal Pelanggan G",
        status: "Ujian Penerimaan Pengguna",
        fasa: "Ujian Keselamatan",
        tarikh_mula: ~D[2023-12-01],
        tarikh_siap: ~D[2024-07-15],
        pengurus_projek: "Siti Nurhaliza",
        pembangun_sistem: "Ahmad bin Ismail",
        developer_id: 2,
        project_manager_id: 3,
        dokumen_sokongan: 2,
        isu: "Isu keselamatan data perlu disemak",
        tindakan: "Lengkapkan audit keselamatan"
      },
      %{
        id: 8,
        nama: "Sistem Laporan Automatik H",
        status: "Selesai",
        fasa: "Maklumbalas Pelanggan",
        tarikh_mula: ~D[2023-08-01],
        tarikh_siap: ~D[2024-02-28],
        pengurus_projek: "Mohd Faizal",
        pembangun_sistem: "Siti Fatimah",
        developer_id: 3,
        project_manager_id: 4,
        dokumen_sokongan: 6,
        isu: "Tiada",
        tindakan: "Projek telah diserahkan dan beroperasi"
      },
      %{
        id: 9,
        nama: "Aplikasi Web Responsif I",
        status: "Dalam Pembangunan",
        fasa: "Pengurusan Perubahan",
        tarikh_mula: ~D[2024-05-01],
        tarikh_siap: ~D[2024-11-30],
        pengurus_projek: "Nurul Aina",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: 5,
        dokumen_sokongan: 0,
        isu: "Perlu penambahbaikan pada reka bentuk UI",
        tindakan: "Kemaskini reka bentuk mengikut spesifikasi"
      },
      %{
        id: 10,
        nama: "Sistem Integrasi API J",
        status: "Ujian Penerimaan Pengguna",
        fasa: "Penempatan",
        tarikh_mula: ~D[2024-01-10],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Lim Wei Ming",
        pembangun_sistem: "Siti Fatimah",
        developer_id: 3,
        project_manager_id: 2,
        dokumen_sokongan: 3,
        isu: "Masalah dengan endpoint tertentu",
        tindakan: "Betulkan endpoint yang bermasalah"
      },
      %{
        id: 11,
        nama: "Sistem Backup dan Pemulihan K",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-09-15],
        tarikh_siap: ~D[2024-03-31],
        pengurus_projek: "Ahmad bin Abdullah",
        pembangun_sistem: "Ahmad bin Ismail",
        developer_id: 2,
        project_manager_id: 2,
        dokumen_sokongan: 4,
        isu: "Tiada",
        tindakan: "Sistem telah diserahkan dan beroperasi"
      },
      %{
        id: 12,
        nama: "Portal Pentadbiran L",
        status: "Dalam Pembangunan",
        fasa: "Soal Selidik",
        tarikh_mula: ~D[2024-06-01],
        tarikh_siap: ~D[2024-12-31],
        pengurus_projek: "Siti Nurhaliza",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: 3,
        dokumen_sokongan: 1,
        isu: "Menunggu kelulusan dari pihak pengurusan",
        tindakan: "Sambung semula selepas kelulusan"
      }
    ]
    |> Enum.map(&normalize_project_status/1)

    # Filter based on user role
    # Temporarily showing all projects for pagination testing
    # TODO: Re-enable role-based filtering when ready
    case user_role do
      "ketua penolong pengarah" ->
        # Directors/Admins see all projects
        all_projects

      _ ->
        # For testing pagination, show all projects to all roles
        # TODO: Re-enable role-based filtering:
        # "pembangun sistem" -> Enum.filter(all_projects, fn p -> p.developer_id == current_user_id end)
        # "pengurus projek" -> Enum.filter(all_projects, fn p -> p.project_manager_id == current_user_id end)
        all_projects
    end
  end

  # Get a single project by ID - will be replaced with database query later
  defp get_project_by_id(project_id, current_scope, _user_role) do
    _current_user_id = current_scope.user.id

    all_projects = [
      %{
        id: 1,
        nama: "Sistem Pengurusan Projek A",
        status: "Dalam Pembangunan",
        fasa: "Soal Selidik",
        tarikh_mula: ~D[2024-01-15],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Ahmad bin Abdullah",
        developer_id: 1,
        project_manager_id: 2,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan",
        keterangan:
          "Sistem pengurusan projek yang komprehensif untuk menguruskan semua aspek projek IT di JPKN."
      },
      %{
        id: 2,
        nama: "Sistem Analisis Data B",
        status: "Ujian Penerimaan Pengguna",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: ~D[2023-11-01],
        tarikh_siap: ~D[2024-05-15],
        pengurus_projek: "Siti Nurhaliza",
        developer_id: 1,
        project_manager_id: 3,
        isu: "Perlu pembetulan pada modul laporan",
        tindakan: "Selesaikan isu sebelum penyerahan",
        keterangan: "Sistem untuk menganalisis data dan menjana laporan automatik."
      },
      %{
        id: 3,
        nama: "Portal E-Services C",
        status: "Selesai",
        fasa: "Pengaturcaraan",
        tarikh_mula: ~D[2023-06-01],
        tarikh_siap: ~D[2024-01-31],
        pengurus_projek: "Mohd Faizal",
        developer_id: 2,
        project_manager_id: 4,
        isu: "Tiada",
        tindakan: "Projek telah diserahkan",
        keterangan:
          "Portal e-services untuk kemudahan awam mengakses perkhidmatan JPKN secara dalam talian."
      },
      %{
        id: 4,
        nama: "Sistem Pengurusan Dokumen D",
        status: "Dalam Pembangunan",
        fasa: "Pengaturcaraan",
        tarikh_mula: ~D[2024-02-01],
        tarikh_siap: ~D[2024-08-31],
        pengurus_projek: "Nurul Aina",
        developer_id: 3,
        project_manager_id: 5,
        isu: "Menunggu kelulusan bajet tambahan",
        tindakan: "Sambung semula selepas kelulusan",
        keterangan: "Sistem untuk menguruskan dokumen digital dengan sistem pengesanan dan versi."
      },
      %{
        id: 5,
        nama: "Aplikasi Mobile E",
        status: "Dalam Pembangunan",
        fasa: "Soal Selidik",
        tarikh_mula: ~D[2024-03-01],
        tarikh_siap: ~D[2024-09-30],
        pengurus_projek: "Lim Wei Ming",
        developer_id: 1,
        project_manager_id: 2,
        isu: "Masalah integrasi dengan API",
        tindakan: "Selesaikan integrasi API",
        keterangan:
          "Aplikasi mobile untuk akses mudah kepada perkhidmatan JPKN melalui telefon pintar."
      },
      %{
        id: 6,
        nama: "Sistem Pengurusan Inventori F",
        status: "Dalam Pembangunan",
        fasa: "Jadual Projek",
        tarikh_mula: ~D[2024-04-15],
        tarikh_siap: ~D[2024-10-31],
        pengurus_projek: "Ahmad bin Abdullah",
        developer_id: 2,
        project_manager_id: 2,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan modul inventori",
        keterangan:
          "Sistem untuk menguruskan inventori peralatan dan aset JPKN dengan kemas kini masa nyata."
      },
      %{
        id: 7,
        nama: "Portal Pelanggan G",
        status: "Ujian Penerimaan Pengguna",
        fasa: "Ujian Keselamatan",
        tarikh_mula: ~D[2023-12-01],
        tarikh_siap: ~D[2024-07-15],
        pengurus_projek: "Siti Nurhaliza",
        developer_id: 2,
        project_manager_id: 3,
        isu: "Isu keselamatan data perlu disemak",
        tindakan: "Lengkapkan audit keselamatan",
        keterangan:
          "Portal untuk pelanggan mengakses maklumat dan perkhidmatan JPKN dengan mudah."
      },
      %{
        id: 8,
        nama: "Sistem Laporan Automatik H",
        status: "Selesai",
        fasa: "Maklumbalas Pelanggan",
        tarikh_mula: ~D[2023-08-01],
        tarikh_siap: ~D[2024-02-28],
        pengurus_projek: "Mohd Faizal",
        developer_id: 3,
        project_manager_id: 4,
        isu: "Tiada",
        tindakan: "Projek telah diserahkan dan beroperasi",
        keterangan: "Sistem untuk menjana laporan automatik berdasarkan data yang dikumpulkan."
      },
      %{
        id: 9,
        nama: "Aplikasi Web Responsif I",
        status: "Dalam Pembangunan",
        fasa: "Pengurusan Perubahan",
        tarikh_mula: ~D[2024-05-01],
        tarikh_siap: ~D[2024-11-30],
        pengurus_projek: "Nurul Aina",
        developer_id: 1,
        project_manager_id: 5,
        isu: "Perlu penambahbaikan pada reka bentuk UI",
        tindakan: "Kemaskini reka bentuk mengikut spesifikasi",
        keterangan: "Aplikasi web yang responsif untuk akses melalui pelbagai peranti."
      },
      %{
        id: 10,
        nama: "Sistem Integrasi API J",
        status: "Ujian Penerimaan Pengguna",
        fasa: "Penempatan",
        tarikh_mula: ~D[2024-01-10],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Lim Wei Ming",
        developer_id: 3,
        project_manager_id: 2,
        isu: "Masalah dengan endpoint tertentu",
        tindakan: "Betulkan endpoint yang bermasalah",
        keterangan: "Sistem untuk mengintegrasikan pelbagai sistem melalui API yang standard."
      },
      %{
        id: 11,
        nama: "Sistem Backup dan Pemulihan K",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-09-15],
        tarikh_siap: ~D[2024-03-31],
        pengurus_projek: "Ahmad bin Abdullah",
        developer_id: 2,
        project_manager_id: 2,
        isu: "Tiada",
        tindakan: "Sistem telah diserahkan dan beroperasi",
        keterangan: "Sistem untuk backup dan pemulihan data secara automatik dan berkala."
      },
      %{
        id: 12,
        nama: "Portal Pentadbiran L",
        status: "Dalam Pembangunan",
        fasa: "Soal Selidik",
        tarikh_mula: ~D[2024-06-01],
        tarikh_siap: ~D[2024-12-31],
        pengurus_projek: "Siti Nurhaliza",
        developer_id: 1,
        project_manager_id: 3,
        isu: "Menunggu kelulusan dari pihak pengurusan",
        tindakan: "Sambung semula selepas kelulusan",
        keterangan:
          "Portal untuk pentadbiran dalaman dengan akses terhad kepada kakitangan yang berkenaan."
      }
    ]
    |> Enum.map(&normalize_project_status/1)

    # Find project by ID
    project = Enum.find(all_projects, fn p -> p.id == project_id end)

    # Check if user has permission to view this project
    # Temporarily allowing all users to view all projects (consistent with list_projects)
    # TODO: Re-enable role-based filtering when ready:
    # cond do
    #   is_nil(project) ->
    #     nil
    #
    #   user_role == "pembangun sistem" ->
    #     if project.developer_id == current_user_id, do: project, else: nil
    #
    #   user_role == "pengurus projek" ->
    #     if project.project_manager_id == current_user_id, do: project, else: nil
    #
    #   user_role == "ketua penolong pengarah" ->
    #     project
    #
    #   true ->
    #     nil
    # end

    # For now, allow all authenticated users to view all projects (for testing)
    project
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
      String.contains?(String.downcase(project.nama), search_lower) ||
        String.contains?(String.downcase(project.pengurus_projek || ""), search_lower) ||
        String.contains?(String.downcase(project.pembangun_sistem || ""), search_lower) ||
        String.contains?(String.downcase(project.isu || ""), search_lower)
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
