defmodule SppaWeb.PengurusProjekLive do
  use SppaWeb, :live_view

  alias Sppa.Accounts

  @impl true
  def mount(_params, _session, socket) do
    # Verify user is pengurus projek
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Senarai Projek - Pengurus Projek")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:notifications_count, 0)
        |> assign(:activities, [])
        |> assign(:page, 1)
        |> assign(:per_page, 10)
        |> assign(:search_term, "")
        |> assign(:show_new_project_modal, false)
        |> assign(:form, to_form(%{}, as: :project))

      if connected?(socket) do
        # Get all users for dropdowns in new project form
        users = Accounts.list_users()

        # Filter projects based on user role - pengurus projek sees projects where they are assigned
        all_projects = list_projects(socket.assigns.current_scope)

        filtered_projects =
          filter_projects(all_projects, socket.assigns.search_term)

        {paginated_projects, total_pages} =
          paginate_projects(filtered_projects, socket.assigns.page, socket.assigns.per_page)

        {:ok,
         socket
         |> assign(:projects, paginated_projects)
         |> assign(:all_projects, all_projects)
         |> assign(:filtered_projects, filtered_projects)
         |> assign(:total_pages, total_pages)
         |> assign(:total_count, length(filtered_projects))
         |> assign(:users, users)}
      else
        {:ok,
         socket
         |> assign(:projects, [])
         |> assign(:all_projects, [])
         |> assign(:filtered_projects, [])
         |> assign(:total_pages, 0)
         |> assign(:total_count, 0)
         |> assign(:users, [])
         |> assign(:notifications_count, 0)
         |> assign(:activities, [])}
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
      filter_projects(socket.assigns.all_projects, socket.assigns.search_term)

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

    filtered_projects = filter_projects(socket.assigns.all_projects, search_term)

    {paginated_projects, total_pages} =
      paginate_projects(filtered_projects, 1, socket.assigns.per_page)

    {:noreply,
     socket
     |> assign(:search_term, search_term)
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
     |> assign(:page, 1)
     |> assign(:projects, paginated_projects)
     |> assign(:filtered_projects, socket.assigns.all_projects)
     |> assign(:total_pages, total_pages)
     |> assign(:total_count, length(socket.assigns.all_projects))}
  end

  @impl true
  def handle_event("open_new_project_modal", _params, socket) do
    {:noreply, assign(socket, :show_new_project_modal, true)}
  end

  @impl true
  def handle_event("close_new_project_modal", _params, socket) do
    {:noreply, assign(socket, :show_new_project_modal, false)}
  end

  @impl true
  def handle_event("validate_new_project", %{"project" => project_params}, socket) do
    # For now, just keep the form as is since we're not saving to database
    form = to_form(project_params, as: :project)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save_new_project", %{"project" => _project_params}, socket) do
    # For now, just close the modal since we're not saving to database
    {:noreply,
     socket
     |> assign(:show_new_project_modal, false)
     |> assign(:form, to_form(%{}, as: :project))
     |> put_flash(:info, "Projek akan disimpan selepas penambahan medan pangkalan data")}
  end

  # Mock data function - will be replaced with database queries later
  # Pengurus projek sees projects where they are assigned as project manager
  defp list_projects(current_scope) do
    current_user_id = current_scope.user.id

    all_projects = [
      %{
        id: 1,
        nama: "Sistem Pengurusan Projek A",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-01-15],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Ahmad bin Abdullah",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: current_user_id,
        dokumen_sokongan: 3,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan"
      },
      %{
        id: 2,
        nama: "Sistem Analisis Data B",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2023-11-01],
        tarikh_siap: ~D[2024-05-15],
        pengurus_projek: "Siti Nurhaliza",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: current_user_id,
        dokumen_sokongan: 2,
        isu: "Perlu pembetulan pada modul laporan",
        tindakan: "Selesaikan isu sebelum penyerahan"
      },
      %{
        id: 3,
        nama: "Portal E-Services C",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-06-01],
        tarikh_siap: ~D[2024-01-31],
        pengurus_projek: "Mohd Faizal",
        pembangun_sistem: "Ahmad bin Ismail",
        developer_id: 2,
        project_manager_id: current_user_id,
        dokumen_sokongan: 5,
        isu: "Tiada",
        tindakan: "Projek telah diserahkan"
      },
      %{
        id: 4,
        nama: "Sistem Pengurusan Dokumen D",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah",
        status: "Ditangguhkan",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: ~D[2024-02-01],
        tarikh_siap: ~D[2024-08-31],
        pengurus_projek: "Nurul Aina",
        pembangun_sistem: "Siti Fatimah",
        developer_id: 3,
        project_manager_id: current_user_id,
        dokumen_sokongan: 1,
        isu: "Menunggu kelulusan bajet tambahan",
        tindakan: "Sambung semula selepas kelulusan"
      },
      %{
        id: 5,
        nama: "Aplikasi Mobile E",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-03-01],
        tarikh_siap: ~D[2024-09-30],
        pengurus_projek: "Lim Wei Ming",
        pembangun_sistem: "Ali bin Hassan",
        developer_id: 1,
        project_manager_id: current_user_id,
        dokumen_sokongan: 0,
        isu: "Masalah integrasi dengan API",
        tindakan: "Selesaikan integrasi API"
      }
    ]

    # Filter projects where current user is the project manager
    # For now, showing all projects for testing (since we're using mock data)
    # TODO: Re-enable filtering when database is ready:
    # Enum.filter(all_projects, fn p -> p.project_manager_id == current_user_id end)
    all_projects
  end

  # Filter projects based on search term
  defp filter_projects(projects, search_term) do
    filter_by_search(projects, search_term)
  end

  defp filter_by_search(projects, ""), do: projects

  defp filter_by_search(projects, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(projects, fn project ->
      String.contains?(String.downcase(project.nama || ""), search_lower) ||
        String.contains?(String.downcase(project.jabatan || ""), search_lower) ||
        String.contains?(String.downcase(project.pengurus_projek || ""), search_lower) ||
        String.contains?(String.downcase(project.pembangun_sistem || ""), search_lower)
    end)
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
end
