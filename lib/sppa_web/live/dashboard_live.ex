defmodule SppaWeb.DashboardLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua unit", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Sidebar starts closed on mobile, but we'll show it by default on desktop via CSS
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Papan Pemuka")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:show_settings_modal, false)

      # Always load stats and activities from database so metric cards show actual counts
      stats = Projects.get_dashboard_stats(socket.assigns.current_scope)
      # Aktiviti Terkini: recently registered projects (from external link), latest first (visible to current role)
      registered = Projects.list_recently_registered_projects(socket.assigns.current_scope, 20)
      activities =
        Enum.map(registered, fn p ->
          %{
            action: "projek_didaftar",
            action_label: "Projek didaftarkan",
            resource_name: p.nama || "-",
            resource_id: p.id,
            actor: nil,
            pengurus_projek_display: Projects.project_pengurus_projek_display(p),
            details: "Didaftar dari pautan luar",
            inserted_at: p.inserted_at
          }
        end)

      notifications_count = length(activities)

      {:ok,
       socket
       |> assign(:stats, stats)
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
  def handle_event("open_settings_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_settings_modal, true)
     |> assign(:profile_menu_open, false)}
  end

  @impl true
  def handle_info(:close_settings_modal, socket) do
    {:noreply, assign(socket, :show_settings_modal, false)}
  end
end
