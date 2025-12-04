defmodule SppaWeb.DashboardLive do
  use SppaWeb, :live_view

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

      if connected?(socket) do
        new_stats = Projects.get_dashboard_stats(socket.assigns.current_scope)
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
        notifications_count = length(activities)

        # Merge stats preserving displayed values - once a stat shows a value, don't let it go to zero
        fallback_stats = %{}

        displayed_stats =
          socket.assigns
          |> Map.get(:stats, fallback_stats)
          |> merge_stats_preserving_values(new_stats)

        {:ok,
         socket
         |> assign(:stats, displayed_stats)
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        {:ok,
         socket
         |> assign(:stats, %{})
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

  # Helper function to merge stats, preserving displayed values
  # Once a stat has been displayed with a value, it won't revert to zero
  defp merge_stats_preserving_values(existing_stats, new_stats) do
    Enum.reduce(new_stats, existing_stats, fn {key, new_value}, acc ->
      existing_value = Map.get(acc, key)

      # If we have an existing value that was displayed (non-zero), preserve it when new value is zero
      # Otherwise, use the new value
      updated_value =
        cond do
          # If existing value exists and is non-zero, and new value is zero, keep existing
          existing_value && existing_value > 0 && new_value == 0 ->
            existing_value

          # Always use new value if it's greater than 0
          new_value && new_value > 0 ->
            new_value

          # If new value is zero, preserve existing value (which could be a fallback)
          true ->
            existing_value
        end

      Map.put(acc, key, updated_value)
    end)
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
    {:noreply, update(socket, :notifications_open, &(!&1))}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
  end
end
