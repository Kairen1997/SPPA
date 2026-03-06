defmodule SppaWeb.PelanModulLive do
  use SppaWeb, :live_view

  alias Sppa.GanttData
  alias Sppa.Projects
  alias Sppa.ProjectModules

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      project_id = String.to_integer(project_id)

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Pelan Modul")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:show_settings_modal, false)
        |> assign(:project_id, project_id)

      current_scope = socket.assigns.current_scope
      current_user = current_scope && current_scope.user

      project =
        case {user_role, current_user} do
          {"pembangun sistem", %{id: user_id, no_kp: no_kp}} ->
            case Projects.get_project_by_id(project_id) do
              nil ->
                nil

              p ->
                if p.developer_id == user_id or Projects.has_access_to_project?(p, no_kp),
                  do: p,
                  else: nil
            end

          {role, _} when role in ["pengurus projek", "ketua penolong pengarah"] ->
            Projects.get_project_by_id(project_id)

          _ ->
            nil
        end

      if project do
        all_modules = ProjectModules.list_modules_by_project_id(project_id)

        modules =
          case {user_role, current_user} do
            {"pembangun sistem", %{id: user_id}} ->
              Enum.filter(all_modules, fn m -> m.developer_id == user_id end)

            _ ->
              all_modules
          end

        gantt_data = GanttData.build_project_gantt(project, modules)

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
  def handle_event("open_settings_modal", _params, socket) do
    {:noreply, assign(socket, :show_settings_modal, true)}
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply, update(socket, :notifications_open, &(!&1))}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
  end

  @impl true
  def handle_info(:close_settings_modal, socket) do
    {:noreply, assign(socket, :show_settings_modal, false)}
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
