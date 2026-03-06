defmodule SppaWeb.PenyerahanProjekLive do
  @moduledoc """
  LiveView "Penyerahan" for Ketua Unit: displays all approved projects from the external link,
  similar to Senarai Projek Diluluskan for Pengurus Projek. View-only (no Daftar Projek / Projek Baru).
  """
  use SppaWeb, :live_view

  alias Sppa.Repo
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
        |> assign(:notifications_count, 0)
        |> assign(:activities, [])
        |> assign(:status_filter, "")
        |> assign(:search_query, "")
        |> assign(:page, 1)
        |> assign(:per_page, 10)

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
  def handle_event("filter", %{"status" => status, "search" => search}, socket) do
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
      job = Sppa.Workers.ExternalSyncWorker.new(%{})

      case Oban.insert(job) do
        {:ok, _inserted_job} ->
          Process.send_after(self(), :reload_projects, 3000)

          {:noreply,
           socket
           |> put_flash(:info, "Sinkronisasi data telah dimulakan. Sila tunggu sebentar...")}

        {:error, reason} ->
          Logger.error("Failed to insert sync job: #{inspect(reason)}")

          {:noreply,
           socket
           |> put_flash(:error, "Ralat semasa memulakan sinkronisasi: #{inspect(reason)}")}
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
      from ap in Sppa.ApprovedProjects.ApprovedProject,
        left_join: p in assoc(ap, :project),
        preload: [project: p]

    base_query =
      if socket.assigns.search_query != "" do
        search_term = "%#{socket.assigns.search_query}%"
        where(base_query, [ap, _p], ilike(ap.nama_projek, ^search_term))
      else
        base_query
      end

    base_query =
      if socket.assigns.status_filter != "" do
        where(base_query, [_ap, p], p.status == ^socket.assigns.status_filter)
      else
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

    base_query =
      if socket.assigns.search_query != "" do
        search_term = "%#{socket.assigns.search_query}%"
        where(base_query, [ap, _p], ilike(ap.nama_projek, ^search_term))
      else
        base_query
      end

    base_query =
      if socket.assigns.status_filter != "" do
        where(base_query, [_ap, p], p.status == ^socket.assigns.status_filter)
      else
        base_query
      end

    total = Repo.aggregate(base_query, :count, :id)
    ceil(total / socket.assigns.per_page)
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
