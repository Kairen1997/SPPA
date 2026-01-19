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
    {:noreply, assign(socket, :current_tab, normalize_tab(tab))}
  end

  defp normalize_tab("soal-selidik"), do: "Soal Selidik"
  # Backwards compatible: keep old slug working, but rename the tab display.
  defp normalize_tab("spesifikasi-aplikasi"), do: "Analisis dan Rekabentuk"
  defp normalize_tab("analisis-dan-rekabentuk"), do: "Analisis dan Rekabentuk"
  defp normalize_tab("jadual-projek"), do: "Jadual Projek"
  defp normalize_tab("pengaturcaraan"), do: "Pengaturcaraan"
  defp normalize_tab("pengurus-perubahan"), do: "Pengurus Perubahan"
  defp normalize_tab("ujian-keselamatan"), do: "Ujian Keselamatan"
  defp normalize_tab("maklumbalas-pelanggan"), do: "Maklumbalas Pelanggan"
  defp normalize_tab(_), do: "Soal Selidik"

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
           |> assign(:soal_selidik_pdf_data, Sppa.SoalSelidik.pdf_data(nama_sistem: project_name))
           |> assign(
             :analisis_pdf_data,
             Sppa.AnalisisDanRekabentuk.pdf_data(
               nama_projek: project_name,
               modules: Sppa.AnalisisDanRekabentuk.initial_modules()
             )
           )
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
        developer_id: 1,
        project_manager_id: 2,
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
        developer_id: 1,
        project_manager_id: 3,
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
        developer_id: 2,
        project_manager_id: 4,
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
        developer_id: 3,
        project_manager_id: 5,
        isu: "Menunggu kelulusan bajet tambahan",
        tindakan: "Sambung semula selepas kelulusan"
      },
      %{
        id: 5,
        nama: "Aplikasi Mobile E",
        status: "Dalam Pembangunan",
        fasa: "Pengaturcaraan",
        tarikh_mula: ~D[2024-03-01],
        tarikh_siap: ~D[2024-09-30],
        pengurus_projek: "Lim Wei Ming",
        developer_id: 1,
        project_manager_id: 2,
        isu: "Masalah integrasi dengan API",
        tindakan: "Selesaikan integrasi API"
      },
      %{
        id: 6,
        nama: "Sistem Pengurusan Inventori F",
        status: "Dalam Pembangunan",
        fasa: "Pengaturcaraan",
        tarikh_mula: ~D[2024-04-15],
        tarikh_siap: ~D[2024-10-31],
        pengurus_projek: "Ahmad bin Abdullah",
        developer_id: 2,
        project_manager_id: 2,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan modul inventori"
      },
      %{
        id: 7,
        nama: "Portal Pelanggan G",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2023-12-01],
        tarikh_siap: ~D[2024-07-15],
        pengurus_projek: "Siti Nurhaliza",
        developer_id: 2,
        project_manager_id: 3,
        isu: "Isu keselamatan data perlu disemak",
        tindakan: "Lengkapkan audit keselamatan"
      },
      %{
        id: 8,
        nama: "Sistem Laporan Automatik H",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-08-01],
        tarikh_siap: ~D[2024-02-28],
        pengurus_projek: "Mohd Faizal",
        developer_id: 3,
        project_manager_id: 4,
        isu: "Tiada",
        tindakan: "Projek telah diserahkan dan beroperasi"
      },
      %{
        id: 9,
        nama: "Aplikasi Web Responsif I",
        status: "Dalam Pembangunan",
        fasa: "Pengaturcaraan",
        tarikh_mula: ~D[2024-05-01],
        tarikh_siap: ~D[2024-11-30],
        pengurus_projek: "Nurul Aina",
        developer_id: 1,
        project_manager_id: 5,
        isu: "Perlu penambahbaikan pada reka bentuk UI",
        tindakan: "Kemaskini reka bentuk mengikut spesifikasi"
      },
      %{
        id: 10,
        nama: "Sistem Integrasi API J",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2024-01-10],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Lim Wei Ming",
        developer_id: 3,
        project_manager_id: 2,
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
        developer_id: 2,
        project_manager_id: 2,
        isu: "Tiada",
        tindakan: "Sistem telah diserahkan dan beroperasi"
      },
      %{
        id: 12,
        nama: "Portal Pentadbiran L",
        status: "Dalam Pembangunan",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: ~D[2024-06-01],
        tarikh_siap: ~D[2024-12-31],
        pengurus_projek: "Siti Nurhaliza",
        developer_id: 1,
        project_manager_id: 3,
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
        fasa: "soal selidik",
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
        fasa: "analisis dan rekabentuk",
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
        fasa: "pengaturcaraan",
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
        fasa: "pengaturcaraan",
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
        fasa: "pengaturcaraan",
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
        fasa: "pengaturcaraan",
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
        fasa: "pengaturcaraan",
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
        fasa: "penyerahan",
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
        fasa: "pengaturcaraan",
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
        fasa: "pengaturcaraan",
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
        fasa: "penyerahan",
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
        fasa: "analisis dan rekabentuk",
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

  # Format date in Malay format (e.g., "10 Mac 2025")
  defp format_date_malay(date) do
    month_names = %{
      1 => "Januari",
      2 => "Februari",
      3 => "Mac",
      4 => "April",
      5 => "Mei",
      6 => "Jun",
      7 => "Julai",
      8 => "Ogos",
      9 => "September",
      10 => "Oktober",
      11 => "November",
      12 => "Disember"
    }

    day = date.day
    month = month_names[date.month]
    year = date.year

    "#{day} #{month} #{year}"
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
