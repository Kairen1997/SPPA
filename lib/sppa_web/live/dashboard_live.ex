defmodule SppaWeb.DashboardLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role = socket.assigns.current_scope && socket.assigns.current_scope.user && socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      socket = assign(socket, :hide_root_header, true)
      socket = assign(socket, :page_title, "Papan Pemuka")
      # Sidebar starts closed on mobile, but we'll show it by default on desktop via CSS
      socket = assign(socket, :sidebar_open, false)

      if connected?(socket) do
        stats = Projects.get_dashboard_stats(socket.assigns.current_scope)
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)

        {:ok,
         socket
         |> assign(:stats, stats)
         |> assign(:activities, activities)}
      else
        {:ok,
         socket
         |> assign(:stats, %{})
         |> assign(:activities, [])}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Anda tidak mempunyai kebenaran untuk mengakses halaman ini.")
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

end
