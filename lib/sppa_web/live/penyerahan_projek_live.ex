defmodule SppaWeb.PenyerahanProjekLive do
  @moduledoc """
  LiveView "Penyerahan" for Ketua Unit: displays all approved projects from the external link,
  similar to Senarai Projek Diluluskan for Pengurus Projek. View-only (no Daftar Projek / Projek Baru).
  """
  use SppaWeb, :live_view

  alias Sppa.Repo
  alias Sppa.Projects
  alias Sppa.ActivityLogs
  alias Oban
  require Logger
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role == "ketua unit" do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Penyerahan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:status_filter, "")
        |> assign(:search_query, "")
        |> assign(:page, 1)
        |> assign(:per_page, 10)

      {activities, notifications_count} =
        if connected?(socket) do
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

          {activities, length(activities)}
        else
          {[], 0}
        end

      socket =
        socket
        |> assign(:activities, activities)
        |> assign(:notifications_count, notifications_count)

      projects = list_projects(socket)
      total_pages = calculate_total_pages(socket)
      pagination_pages = pagination_pages(1, total_pages)

      {:ok,
       socket
       |> assign(:projects, projects)
       |> assign(:total_pages, total_pages)
       |> assign(:pagination_pages, pagination_pages)}
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
      # Run sync immediately in this process so the user
      # sees updated data without relying on background workers.
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

  defp list_projects(socket) do
    base_query =
      from ap in Sppa.ApprovedProjects.ApprovedProject,
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
          # Projek yang tiada pengurus dilantik: tiada project_manager_id dan tiada pengurus_projek
          where(base_query, [ap, p], is_nil(ap.pengurus_projek) or ap.pengurus_projek == "")
          |> where([ap, p], is_nil(p.id) or is_nil(p.project_manager_id))

        filter when is_binary(filter) and filter != "" ->
          where(base_query, [_ap, p], p.status == ^filter)

        _ ->
          base_query
      end

    offset = (socket.assigns.page - 1) * socket.assigns.per_page

    base_query
    |> order_by([ap, _p], desc: ap.external_updated_at)
    |> limit(^socket.assigns.per_page)
    |> offset(^offset)
    |> Repo.all()
  end

  defp calculate_total_pages(socket) do
    base_query =
      from ap in Sppa.ApprovedProjects.ApprovedProject,
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

  # Returns status label for table: "Belum Lantik Pengurus" if no pengurus appointed;
  # selepas lantikan, paparkan "Sudah Lantik Pengurus" jika tiada status projek
  # khusus, atau status projek (cth. "Dalam Pembangunan" / "Selesai") jika ada.
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
