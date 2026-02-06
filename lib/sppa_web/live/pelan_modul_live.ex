defmodule SppaWeb.PelanModulLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.ProjectModules

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    # Verify user is pengurus projek
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      project_id = String.to_integer(project_id)

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Pelan Modul - Pengurus Projek")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:project_id, project_id)

      # Always load project + modules immediately so the Gantt chart can be
      # built from the current tasks even before the LV socket connects.
      project =
        try do
          Projects.get_project!(project_id, socket.assigns.current_scope)
        rescue
          Ecto.NoResultsError -> nil
        end

      if project do
        modules = ProjectModules.list_modules_for_project(socket.assigns.current_scope, project_id)
        gantt_data = build_gantt_data_for_project(project, modules)

        {:ok,
         socket
         |> assign(:project, project)
         |> assign(:modules, modules)
         |> assign(:gantt_data, gantt_data)}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Projek tidak ditemui atau anda tidak mempunyai kebenaran untuk mengakses projek ini."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/senarai-projek-diluluskan")

        {:ok, socket}
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

  # Build Gantt chart data for a specific project
  defp build_gantt_data_for_project(project, modules) do
    if Enum.empty?(modules) do
      nil
    else
      # Derive project-wide start/end from project or its approved_project
      project_start =
        project.tarikh_mula ||
          (project.approved_project && project.approved_project.tarikh_mula) ||
          get_earliest_date(modules)

      project_end =
        project.tarikh_siap ||
          (project.approved_project && project.approved_project.tarikh_jangkaan_siap) ||
          get_latest_date(modules)

      # Normalise modules with derived start/end dates and developer names
      enriched_modules =
        Enum.map(modules, fn m ->
          start_date = m.tarikh_mula || project_start
          end_date = m.due_date || project_end || project_start

          developer_name =
            cond do
              m.developer && m.developer.email && m.developer.email != "" -> m.developer.email
              m.developer && m.developer.no_kp && m.developer.no_kp != "" -> m.developer.no_kp
              true -> nil
            end

          beyond_end? =
            end_date && project_end && Date.compare(end_date, project_end) == :gt

          Map.merge(
            m,
            %{
              start_date: start_date,
              end_date: end_date,
              developer_name: developer_name,
              beyond_end?: beyond_end?
            }
          )
        end)

      # Sort modules: first by phase (numeric), then by version (numeric) within each phase
      sorted_modules = sort_modules_by_phase_and_version(enriched_modules)

      %{
        project: project,
        modules: sorted_modules,
        start_date: project_start,
        end_date: project_end
      }
    end
  end

  # Sort modules by phase first, then by version within each phase
  # Ensures sequential ordering: Phase 1 (v1, v2, v3...) -> Phase 2 (v1, v2...) -> Phase 3...
  defp sort_modules_by_phase_and_version(modules) do
    Enum.sort_by(modules, fn module ->
      # Convert phase and version to integers for proper numeric sorting
      # Handle cases where fasa/versi might not be numeric strings
      phase_num = parse_numeric(module.fasa)
      version_num = parse_numeric(module.versi)
      {phase_num, version_num}
    end)
  end

  # Safely parse numeric string to integer, defaulting to 0 if not numeric
  defp parse_numeric(value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_numeric(value) when is_integer(value), do: value
  defp parse_numeric(_), do: 0

  # Helper functions
  defp get_earliest_date(modules) do
    if Enum.empty?(modules) do
      Date.utc_today()
    else
      modules
      |> Enum.flat_map(fn m ->
        dates = []
        dates = if m.tarikh_mula, do: [m.tarikh_mula | dates], else: dates
        dates = if m.due_date, do: [m.due_date | dates], else: dates
        dates
      end)
      |> case do
        [] -> Date.utc_today()
        dates -> Enum.min(dates)
      end
    end
  end

  defp get_latest_date(modules) do
    if Enum.empty?(modules) do
      Date.utc_today()
    else
      modules
      |> Enum.map(& &1.due_date)
      |> Enum.filter(& &1)
      |> case do
        [] -> Date.utc_today()
        dates -> Enum.max(dates)
      end
    end
  end

  # Helper function to get status color (public for template access)
  def status_color("in_progress"), do: "bg-blue-100 text-blue-800 border border-blue-200"
  def status_color("done"), do: "bg-green-100 text-green-800 border border-green-200"
  def status_color(_), do: "bg-gray-100 text-gray-800 border border-gray-200"

  # Helper function to get status label (public for template access)
  def status_label("in_progress"), do: "Dalam Proses"
  def status_label("done"), do: "Selesai"
  def status_label(_), do: "Dalam Proses"

  # Helper function to get priority color (public for template access)
  def priority_color("high"), do: "bg-orange-100 text-orange-800 border-orange-200"
  def priority_color("medium"), do: "bg-amber-100 text-amber-800 border-amber-200"
  def priority_color("low"), do: "bg-pink-100 text-pink-800 border-pink-200"
  def priority_color(_), do: "bg-gray-100 text-gray-800 border-gray-200"

  # Helper function to get priority label (public for template access)
  def priority_label("high"), do: "Tinggi"
  def priority_label("medium"), do: "Sederhana"
  def priority_label("low"), do: "Rendah"
  def priority_label(_), do: "Sederhana"

  # Calculate days between dates
  def days_between(start_date, end_date) do
    Date.diff(end_date, start_date) + 1
  end

  # Calculate days from today to start date
  def days_from_today(date) do
    Date.diff(date, Date.utc_today())
  end
end
