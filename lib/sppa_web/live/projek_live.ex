defmodule SppaWeb.ProjekLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Halaman ini kini khusus untuk senarai projek sahaja
    mount_index(socket)
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
        |> assign(:page_title, "Senarai Sistem")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:page, 1)
        |> assign(:per_page, 10)
        |> assign(:search_term, "")
        |> assign(:status_filter, "")
        |> assign(:fasa_filter, "")

      # Always load projects on mount so data is shown on first render.
      # (When connected? is false, we still need to load so the initial HTML has the table.)
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

      activities =
        if connected?(socket) do
          Projects.list_recent_activities(socket.assigns.current_scope, 10)
        else
          []
        end

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
end
