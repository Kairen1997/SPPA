defmodule SppaWeb.ProjectListLive do
  use SppaWeb, :live_view

  import Ecto.Query

  alias Sppa.ApprovedProjects.ApprovedProject
  alias Sppa.Projects
  alias Sppa.Repo
  alias Sppa.Workers.ExternalSyncWorker

  @impl true
  def mount(_params, _session, socket) do
    # Only allow pengurus projek to access this page
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Senarai Projek Diluluskan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:search_term, "")
        |> assign(:status_filter, "")

      # Always load current data from the database so the initial (static) render
      # already shows the latest approved projects, even if LiveView JS fails.
      projects = list_approved_projects()

      # Only subscribe + load activities when the LiveView websocket is connected.
      {activities, notifications_count} =
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Sppa.PubSub, "approved_projects")

          activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
          {activities, length(activities)}
        else
          {[], 0}
        end

      filtered = filter_projects(projects, socket.assigns.search_term, socket.assigns.status_filter)

      {:ok,
       socket
       |> assign(:projects, filtered)
       |> assign(:all_projects, projects)
       |> assign(:filtered_projects, filtered)
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

  ## PubSub updates

  @impl true
  def handle_info({:created, _approved_project}, socket) do
    refresh_projects(socket)
  end

  @impl true
  def handle_info({:updated, _approved_project}, socket) do
    refresh_projects(socket)
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  ## Header / sidebar events

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

  ## Filter + sync events

  @impl true
  def handle_event("filter_projects", params, socket) do
    search_term = Map.get(params, "search_term", "") |> String.trim()
    status_filter = Map.get(params, "status_filter", "")

    filtered = filter_projects(socket.assigns.all_projects, search_term, status_filter)

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:status_filter, status_filter)
     |> assign(:projects, filtered)
     |> assign(:filtered_projects, filtered)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    filtered = filter_projects(socket.assigns.all_projects, "", "")

    {:noreply,
     socket
     |> assign(:search_term, "")
     |> assign(:status_filter, "")
     |> assign(:projects, filtered)
     |> assign(:filtered_projects, filtered)}
  end

  @impl true
  def handle_event("sync_data", _params, socket) do
    # Enqueue the external sync worker – it will fetch and upsert approved projects
    job = ExternalSyncWorker.new(%{})

    case Oban.insert(job) do
      {:ok, _job} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Sinkronisasi data telah dimulakan. Projek akan dikemaskini dalam beberapa saat."
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Ralat semasa memulakan sinkronisasi: #{inspect(reason)}")}
    end
  end

  ## Helpers

  defp refresh_projects(socket) do
    projects = list_approved_projects()
    filtered = filter_projects(projects, socket.assigns.search_term, socket.assigns.status_filter)

    {:noreply,
     socket
     |> assign(:projects, filtered)
     |> assign(:all_projects, projects)
     |> assign(:filtered_projects, filtered)}
  end

  # Same base query as the PDF controller, so the list and the PDF match.
  defp list_approved_projects do
    base_query =
      from ap in ApprovedProject,
        left_join: p in assoc(ap, :project),
        preload: [project: p]

    base_query
    |> order_by([ap, _p], desc: ap.external_updated_at)
    |> Repo.all()
  end

  defp filter_projects(projects, search_term, status_filter) do
    projects
    |> filter_by_search(search_term)
    |> filter_by_status(status_filter)
  end

  defp filter_by_search(projects, ""), do: projects

  defp filter_by_search(projects, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(projects, fn project ->
      String.contains?(String.downcase(project.nama_projek || ""), search_lower) ||
        String.contains?(String.downcase(project.pengurus_email || ""), search_lower) ||
        String.contains?(String.downcase(project.jabatan || ""), search_lower)
    end)
  end

  defp filter_by_status(projects, ""), do: projects
  defp filter_by_status(projects, "Semua"), do: projects

  defp filter_by_status(projects, "Berdaftar") do
    Enum.filter(projects, fn project -> not is_nil(project.project) end)
  end

  defp filter_by_status(projects, "Perlu Didaftar") do
    Enum.filter(projects, fn project -> is_nil(project.project) end)
  end

  defp filter_by_status(projects, _), do: projects
end
