defmodule SppaWeb.DashboardKKLive do
  use SppaWeb, :live_view

  import Ecto.Query, warn: false

  alias Sppa.Repo
  alias Sppa.Projects
  alias Sppa.ActivityLogs
  alias Sppa.ApprovedProjects.ApprovedProject

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role == "ketua unit" do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Papan Pemuka Ketua Unit")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:status_filter, "")
        |> assign(:search_query, "")
        |> assign(:page, 1)
        |> assign(:per_page, 10)

      if connected?(socket) do
        stats = Projects.get_dashboard_stats(socket.assigns.current_scope)

        raw_activities =
          ActivityLogs.list_recent_assignment_activities_for_ketua_unit(10)

        activities =
          Enum.map(raw_activities, fn a ->
            a
            |> Map.put(:action_label, ActivityLogs.action_label(a.action))
            |> Map.put(:nama, a.resource_name)
            |> Map.put(:pengurus_display, extract_pengurus_from_details(a.details))
            |> Map.put(:ketua_unit_display, actor_display(a.actor))
          end)

        notifications_count = length(activities)

        projects = list_projects(socket)
        total_pages = calculate_total_pages(socket)
        pagination_pages = pagination_pages(1, total_pages)

        {:ok,
         socket
         |> assign(:stats, stats)
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)
         |> assign(:projects, projects)
         |> assign(:total_pages, total_pages)
         |> assign(:pagination_pages, pagination_pages)}
      else
        {:ok,
         socket
         |> assign(:stats, %{
           total_projects: 0,
           in_development: 0,
           completed: 0,
           on_hold: 0,
           uat: 0,
           change_management: 0
         })
         |> assign(:activities, [])
         |> assign(:notifications_count, 0)
         |> assign(:projects, [])
         |> assign(:total_pages, 0)
         |> assign(:pagination_pages, [])}
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

  defp actor_display(nil), do: nil

  defp actor_display(actor) do
    actor.name || actor.email || actor.no_kp
  end

  defp extract_pengurus_from_details(nil), do: nil
  defp extract_pengurus_from_details(""), do: nil

  defp extract_pengurus_from_details(details) when is_binary(details) do
    cond do
      String.starts_with?(details, "Pengurus projek dikeluarkan: ") ->
        String.trim_leading(details, "Pengurus projek dikeluarkan: ")

      String.starts_with?(details, "Pengurus projek: ") ->
        String.trim_leading(details, "Pengurus projek: ")

      true ->
        details
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, Phoenix.Component.update(socket, :sidebar_open, &(!&1))}
  end

  @impl true
  def handle_event("close_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, false)}
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply,
     socket
     |> Phoenix.Component.update(:notifications_open, &(!&1))
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
     |> Phoenix.Component.update(:profile_menu_open, &(!&1))
     |> assign(:notifications_open, false)}
  end

  @impl true
  def handle_event("close_profile_menu", _params, socket) do
    {:noreply, assign(socket, :profile_menu_open, false)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    status = Map.get(params, "status", "") || ""
    search = Map.get(params, "search", "") || ""

    socket =
      socket
      |> assign(:status_filter, status)
      |> assign(:search_query, search)
      |> assign(:page, 1)

    projects = list_projects(socket)
    total_pages = calculate_total_pages(socket)

    {:noreply,
     socket
     |> assign(:projects, projects)
     |> assign(:total_pages, total_pages)
     |> assign(:pagination_pages, pagination_pages(socket.assigns.page, total_pages))}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    socket = assign(socket, :page, page)
    projects = list_projects(socket)
    total_pages = socket.assigns.total_pages

    {:noreply,
     socket
     |> assign(:projects, projects)
     |> assign(:pagination_pages, pagination_pages(page, total_pages))}
  end

  @impl true
  def handle_event("sync_external_data", _params, socket) do
    try do
      case Sppa.Workers.ExternalSyncWorker.perform(%{}) do
        :ok ->
          projects = list_projects(socket)
          total_pages = calculate_total_pages(socket)

          {:noreply,
           socket
           |> assign(:projects, projects)
           |> assign(:total_pages, total_pages)
           |> assign(:pagination_pages, pagination_pages(socket.assigns.page, total_pages))
           |> put_flash(:info, "Sinkronisasi data telah selesai.")}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Gagal memuat data daripada Sistem Permohonan Aplikasi: #{inspect(reason)}"
           )}
      end
    rescue
      e ->
        Logger.error("Exception during sync: #{inspect(e)}")

        {:noreply,
         socket
         |> put_flash(:error, "Ralat: #{Exception.message(e)}. Pastikan Oban sedang berjalan.")}
    end
  end

  @impl true
  def handle_info(:reload_projects, socket) do
    projects = list_projects(socket)
    total_pages = calculate_total_pages(socket)

    {:noreply,
     socket
     |> assign(:projects, projects)
     |> assign(:total_pages, total_pages)
     |> assign(:pagination_pages, pagination_pages(socket.assigns.page, total_pages))
     |> put_flash(:info, "Data telah dikemaskini")}
  end

  defp list_projects(socket) do
    base_query =
      from ap in ApprovedProject,
        left_join: p in assoc(ap, :project),
        preload: [project: [:project_manager, :approved_project]]

    search_q = socket.assigns.search_query || ""

    base_query =
      if search_q != "" do
        search_term = "%#{search_q}%"
        where(base_query, [ap, _p], ilike(ap.nama_projek, ^search_term))
      else
        base_query
      end

    base_query =
      case socket.assigns.status_filter do
        "Belum lantik pengurus" ->
          where(base_query, [ap, p], is_nil(ap.pengurus_projek) or ap.pengurus_projek == "")
          |> where([ap, p], is_nil(p.id) or is_nil(p.project_manager_id))

        filter when is_binary(filter) and filter != "" ->
          where(base_query, [_ap, p], p.status == ^filter)

        _ ->
          base_query
      end

    offset = (socket.assigns.page - 1) * socket.assigns.per_page

    base_query
    |> order_by(
      [ap, p],
      asc:
        fragment(
          "CASE WHEN ((? IS NULL OR ? = '') AND (? IS NULL OR ? IS NULL)) THEN 0 ELSE 1 END",
          ap.pengurus_projek,
          ap.pengurus_projek,
          p.id,
          p.project_manager_id
        ),
      desc: ap.external_updated_at
    )
    |> limit(^socket.assigns.per_page)
    |> offset(^offset)
    |> Repo.all()
  end

  defp calculate_total_pages(socket) do
    base_query =
      from ap in ApprovedProject,
        left_join: p in assoc(ap, :project)

    search_q = socket.assigns.search_query || ""

    base_query =
      if search_q != "" do
        search_term = "%#{search_q}%"
        where(base_query, [ap, _p], ilike(ap.nama_projek, ^search_term))
      else
        base_query
      end

    base_query =
      case socket.assigns.status_filter do
        "Belum lantik pengurus" ->
          where(base_query, [ap, p], is_nil(ap.pengurus_projek) or ap.pengurus_projek == "")
          |> where([ap, p], is_nil(p.id) or is_nil(p.project_manager_id))

        filter when is_binary(filter) and filter != "" ->
          where(base_query, [_ap, p], p.status == ^filter)

        _ ->
          base_query
      end

    total = Repo.aggregate(base_query, :count, :id)
    ceil(total / socket.assigns.per_page)
  end

  def pengurus_projek_display(approved_project) do
    if approved_project.project do
      Projects.project_pengurus_projek_display(approved_project.project)
    else
      Projects.approved_project_pengurus_display(approved_project)
    end
  end

  def status_display(approved_project) do
    pengurus_dilantik? =
      (approved_project.project && approved_project.project.project_manager_id) ||
        (approved_project.pengurus_projek && approved_project.pengurus_projek != "")

    if pengurus_dilantik? do
      if approved_project.project && approved_project.project.status &&
           approved_project.project.status != "" do
        approved_project.project.status
      else
        "Sudah Lantik Pengurus"
      end
    else
      "Belum Lantik Pengurus"
    end
  end

  defp pagination_pages(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages - 1, total_pages]

      current_page >= total_pages - 3 ->
        [
          1,
          2,
          :ellipsis,
          total_pages - 4,
          total_pages - 3,
          total_pages - 2,
          total_pages - 1,
          total_pages
        ]

      true ->
        [
          1,
          2,
          :ellipsis,
          current_page - 1,
          current_page,
          current_page + 1,
          :ellipsis,
          total_pages - 1,
          total_pages
        ]
    end
  end
end
