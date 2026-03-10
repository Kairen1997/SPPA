defmodule SppaWeb.DashboardKKLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.ActivityLogs

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

        {:ok,
         socket
         |> assign(:stats, stats)
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
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
