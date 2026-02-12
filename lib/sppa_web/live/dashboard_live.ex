defmodule SppaWeb.DashboardLive do
  use SppaWeb, :live_view

  alias Sppa.ActivityLogs
  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

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

      # Always load stats and activities from database so metric cards show actual counts
      stats = Projects.get_dashboard_stats(socket.assigns.current_scope)
      raw_activities = ActivityLogs.list_recent_activities(socket.assigns.current_scope, 20)
      activities =
        Enum.map(raw_activities, fn a ->
          Map.put(a, :action_label, ActivityLogs.action_label(a.action))
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
end
