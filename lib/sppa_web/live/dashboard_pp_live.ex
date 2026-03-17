defmodule SppaWeb.DashboardPPLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.ApprovedProjects
  alias Sppa.Accounts
  alias Sppa.ActivityLogs

  @impl true
  def mount(_params, _session, socket) do
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role == "pengurus projek" do
      # Match the pembangun sistem dashboard layout: overlay sidebar + top header
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Papan Pemuka Pengurus Projek")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:show_settings_modal, false)

      if connected?(socket) do
        # Subscribe to approved projects updates for live updates
        Phoenix.PubSub.subscribe(Sppa.PubSub, "approved_projects")

        # Stats: kad kuning = projek ditugaskan; kad biru = dalam pembangunan; kad hijau = selesai dibangun
        assigned =
          Projects.list_approved_projects_for_pengurus_projek(socket.assigns.current_scope)

        stats =
          ApprovedProjects.get_dashboard_stats()
          |> Map.put(:jumlah, length(assigned))
          |> Map.put(:jumlah_dalam_pembangunan, count_dalam_pembangunan(assigned))
          |> Map.put(:jumlah_selesai, count_selesai(assigned))

        project_activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)

        assignment_activities =
          ActivityLogs.list_recent_assignment_activities_for_pengurus_projek(
            socket.assigns.current_scope,
            10
          )

        notification_activities =
          merge_activities_for_notifications(project_activities, assignment_activities, 10)

        {:ok,
         socket
         |> assign(:stats, stats)
         |> assign(:activities, project_activities)
         |> assign(:notification_activities, notification_activities)
         |> assign(:notifications_count, length(notification_activities))}
      else
        {:ok,
         socket
         |> assign(:stats, %{
           jumlah: 0,
           jumlah_projek_berdaftar: 0,
           jumlah_projek_perlu_didaftar: 0,
           jumlah_dalam_pembangunan: 0,
           jumlah_selesai: 0
         })
         |> assign(:activities, [])
         |> assign(:notification_activities, [])
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

  @impl true
  def handle_info({:created, _approved_project}, socket) do
    assigned = Projects.list_approved_projects_for_pengurus_projek(socket.assigns.current_scope)

    stats =
      ApprovedProjects.get_dashboard_stats()
      |> Map.put(:jumlah, length(assigned))
      |> Map.put(:jumlah_dalam_pembangunan, count_dalam_pembangunan(assigned))
      |> Map.put(:jumlah_selesai, count_selesai(assigned))

    {:noreply, assign(socket, :stats, stats)}
  end

  @impl true
  def handle_info({:updated, _approved_project}, socket) do
    assigned = Projects.list_approved_projects_for_pengurus_projek(socket.assigns.current_scope)

    stats =
      ApprovedProjects.get_dashboard_stats()
      |> Map.put(:jumlah, length(assigned))
      |> Map.put(:jumlah_dalam_pembangunan, count_dalam_pembangunan(assigned))
      |> Map.put(:jumlah_selesai, count_selesai(assigned))

    {:noreply, assign(socket, :stats, stats)}
  end

  @impl true
  def handle_info(:close_settings_modal, socket) do
    {:noreply, assign(socket, :show_settings_modal, false)}
  end

  @impl true
  def handle_info(_message, socket) do
    {:noreply, socket}
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

  # Helper function to get all team members (developers and project managers) with their roles
  defp get_team_members(project) do
    dev_no_kps =
      if project.approved_project && project.approved_project.pembangun_sistem do
        parse_pembangun_sistem(project.approved_project.pembangun_sistem)
      else
        []
      end

    team_members = []

    # Add main developer if exists
    team_members =
      if project.developer do
        [%{user: project.developer, role: "pembangun sistem"} | team_members]
      else
        team_members
      end

    # Add main project manager if exists
    team_members =
      if project.project_manager do
        [%{user: project.project_manager, role: "pengurus projek"} | team_members]
      else
        team_members
      end

    # Add developers from approved_project's pembangun_sistem
    team_members =
      if project.approved_project && project.approved_project.pembangun_sistem do
        no_kps = parse_pembangun_sistem(project.approved_project.pembangun_sistem)

        additional_developers =
          no_kps
          |> Enum.map(&Accounts.get_user_by_no_kp/1)
          |> Enum.filter(&(&1 != nil))
          |> Enum.filter(fn user -> user.role == "pembangun sistem" end)
          |> Enum.map(fn user -> %{user: user, role: "pembangun sistem"} end)

        team_members ++ additional_developers
      else
        team_members
      end

    # Add project managers from approved_project's pengurus_projek
    team_members =
      if project.approved_project && project.approved_project.pengurus_projek do
        no_kps = parse_pengurus_projek(project.approved_project.pengurus_projek)

        additional_pms =
          no_kps
          |> Enum.map(&Accounts.get_user_by_no_kp/1)
          |> Enum.filter(&(&1 != nil))
          |> Enum.filter(fn user -> user.role == "pengurus projek" end)
          |> Enum.map(fn user -> %{user: user, role: "pengurus projek"} end)

        team_members ++ additional_pms
      else
        team_members
      end

    # Remove duplicates by user id and return formatted list
    team_members
    |> Enum.uniq_by(fn %{user: user} -> user.id end)
    |> Enum.map(fn %{user: user, role: role} ->
      name =
        cond do
          user.name && user.name != "" -> user.name
          user.email && user.email != "" -> user.email
          user.no_kp && user.no_kp != "" -> user.no_kp
          true -> "N/A"
        end

      is_developer =
        role == "pembangun sistem" ||
          (user.no_kp && user.no_kp in dev_no_kps)

      %{name: name, role: role, is_developer: is_developer}
    end)
    |> Enum.filter(fn %{name: name} -> name != nil end)
    |> Enum.sort_by(fn %{role: role} ->
      # Sort: pengurus projek first (0), then pembangun sistem (1)
      case role do
        "pengurus projek" -> 0
        "pembangun sistem" -> 1
        _ -> 2
      end
    end)
  end

  # Kira projek yang "dalam pembangunan": pengurus sudah melantik pembangun
  # (approved_project.pembangun_sistem tidak kosong ATAU project.developer_id ada)
  defp count_dalam_pembangunan(approved_projects) when is_list(approved_projects) do
    Enum.count(approved_projects, fn ap ->
      has_pembangun =
        (is_binary(ap.pembangun_sistem) and String.trim(ap.pembangun_sistem) != "") or
          ((ap.project && is_struct(ap.project)) and ap.project.developer_id != nil)

      has_pembangun
    end)
  end

  # Kira projek yang telah selesai dibangun: projek dalaman dengan status "Selesai"
  defp count_selesai(approved_projects) when is_list(approved_projects) do
    Enum.count(approved_projects, fn ap ->
      (ap.project && is_struct(ap.project)) and ap.project.status == "Selesai"
    end)
  end

  # Merge project-based activities and assignment activities (ketua unit menugaskan projek)
  # for the notification dropdown, sorted by date descending.
  defp merge_activities_for_notifications(project_activities, assignment_activities, limit) do
    project_items =
      Enum.map(project_activities, fn p ->
        sort_at = p.last_updated || Map.get(p, :updated_at) || DateTime.utc_now()
        %{nama: p.nama, status: p.status, last_updated: p.last_updated, sort_at: sort_at}
      end)

    assignment_items =
      Enum.map(assignment_activities, fn a ->
        sort_at = a.inserted_at || DateTime.utc_now()

        %{
          resource_name: a.resource_name,
          action_label: a.action_label,
          details: a.details,
          inserted_at: a.inserted_at,
          sort_at: sort_at
        }
      end)

    (project_items ++ assignment_items)
    |> Enum.sort_by(& &1.sort_at, {:desc, DateTime})
    |> Enum.take(limit)
    |> Enum.map(&Map.delete(&1, :sort_at))
  end

  # Parse comma-separated pengurus_projek string into list of no_kp values
  defp parse_pengurus_projek(nil), do: []
  defp parse_pengurus_projek(""), do: []

  defp parse_pengurus_projek(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_pengurus_projek(_), do: []

  # Parse comma-separated pembangun_sistem string into list of no_kp values
  defp parse_pembangun_sistem(nil), do: []
  defp parse_pembangun_sistem(""), do: []

  defp parse_pembangun_sistem(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_pembangun_sistem(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <%= if @show_settings_modal do %>
        <.live_component
          module={SppaWeb.Components.SettingsModalLive}
          id="settings-modal"
          current_scope={@current_scope}
        />
      <% end %>
      
      <div class="fixed inset-0 flex h-screen bg-gradient-to-br from-gray-50 to-gray-100 z-50">
        <%!-- Overlay --%>
        <div
          class={[
            "fixed inset-0 bg-blue-900/60 z-40 transition-opacity duration-300",
            if(@sidebar_open, do: "opacity-100", else: "opacity-0 pointer-events-none")
          ]}
          phx-click="close_sidebar"
        >
        </div>
         <%!-- Sidebar --%>
        <.dashboard_sidebar
          sidebar_open={@sidebar_open}
          dashboard_path={~p"/dashboard-pp"}
          logo_src={~p"/images/logojpkn.png"}
          current_scope={@current_scope}
          current_path="/dashboard-pp"
        /> <%!-- Main Content --%>
        <div class="flex-1 flex flex-col overflow-hidden">
          <%!-- Header --%>
          <header class="bg-gradient-to-r from-blue-600 to-blue-700 border-b border-blue-700 px-3 sm:px-6 py-3 sm:py-4 flex items-center shadow-md relative gap-2 sm:gap-4">
            <div
              class="flex items-center gap-2 sm:gap-4 flex-shrink-0"
              style="max-width: min(30%, 200px);"
            >
              <button
                phx-click="toggle_sidebar"
                class="text-white hover:text-blue-100 hover:bg-blue-500/40 p-1.5 sm:p-2 rounded-lg transition-all duration-200 flex-shrink-0"
              >
                <.icon name="hero-bars-3" class="w-5 h-5 sm:w-6 sm:h-6" />
              </button> <.header_logos height_class="h-12 sm:h-14 md:h-16" />
            </div>
            
            <div class="flex-1 flex justify-center min-w-0"><.system_title /></div>
            
            <div class="flex items-center gap-2 sm:gap-3 flex-shrink-0">
              <.header_actions
                notifications_open={@notifications_open}
                notifications_count={@notifications_count}
                activities={@notification_activities}
                profile_menu_open={@profile_menu_open}
                current_scope={@current_scope}
              />
            </div>
          </header>
           <%!-- Dashboard Content --%>
          <main class="flex-1 overflow-y-auto bg-gradient-to-br from-gray-50 to-white p-6 md:p-8">
            <div class="max-w-7xl mx-auto">
              <div class="mb-8">
                <h1 class="text-3xl font-bold text-gray-900 mb-2">Dashboard Pengurus Projek</h1>
                
                <p class="text-gray-600">Gambaran keseluruhan projek dan aktiviti terkini</p>
              </div>
               <%!-- Summary Cards --%>
              <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
                <%!-- Jumlah projek ditugaskan kepada pengurus --%>
                <div class="bg-gradient-to-br from-yellow-400 to-yellow-500 rounded-xl p-6 shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1">
                  <div class="flex items-center justify-between mb-4">
                    <.icon name="hero-folder-open" class="w-8 h-8 text-yellow-800 opacity-80" />
                  </div>
                  
                  <div class="text-4xl font-bold text-gray-900 mb-1">{@stats[:jumlah] || 0}</div>
                  
                  <div class="text-sm font-medium text-gray-800">
                    Jumlah projek ditugaskan kepada anda
                  </div>
                </div>
                 <%!-- Dalam Pembangunan: projek yang pengurus sudah melantik pembangun --%>
                <div class="bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl p-6 shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1">
                  <div class="flex items-center justify-between mb-4">
                    <.icon name="hero-cog-6-tooth" class="w-8 h-8 text-white opacity-90" />
                  </div>
                  
                  <div class="text-4xl font-bold text-white mb-1">
                    {@stats[:jumlah_dalam_pembangunan] || 0}
                  </div>
                  
                  <div class="text-sm font-medium text-blue-50">Dalam Pembangunan</div>
                  
                  <p class="text-xs text-blue-100/90 mt-1">
                    Projek yang anda sudah melantik pembangun
                  </p>
                </div>
                 <%!-- Selesai: projek yang telah selesai dibangun --%>
                <div class="bg-gradient-to-br from-green-500 to-green-600 rounded-xl p-6 shadow-lg hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1">
                  <div class="flex items-center justify-between mb-4">
                    <.icon name="hero-check-badge" class="w-8 h-8 text-white opacity-90" />
                  </div>
                  
                  <div class="text-4xl font-bold text-white mb-1">{@stats[:jumlah_selesai] || 0}</div>
                  
                  <div class="text-sm font-medium text-green-50">Selesai</div>
                  
                  <p class="text-xs text-green-100/90 mt-1">Projek yang telah selesai dibangun</p>
                </div>
              </div>
               <%!-- Latest Activities --%>
              <div class="bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden">
                <div class="px-6 py-4 border-b border-gray-200 bg-gradient-to-r from-gray-50 to-white">
                  <div class="flex items-center justify-between">
                    <div class="flex items-center gap-3">
                      <.icon name="hero-clock" class="w-5 h-5 text-gray-600" />
                      <h2 class="text-xl font-semibold text-gray-900">Aktiviti Terkini</h2>
                    </div>
                  </div>
                </div>
                
                <div class="overflow-x-auto">
                  <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                      <tr>
                        <th class="px-6 py-4 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                          Nama Projek
                        </th>
                        
                        <th class="px-6 py-4 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                          Pembangun
                        </th>
                        
                        <th class="px-6 py-4 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                          Status Terkini
                        </th>
                        
                        <th class="px-6 py-4 text-left text-xs font-semibold text-gray-700 uppercase tracking-wider">
                          Tarikh Akhir Kemaskini
                        </th>
                      </tr>
                    </thead>
                    
                    <tbody class="bg-white divide-y divide-gray-200">
                      <%= if Enum.empty?(@activities) do %>
                        <tr>
                          <td colspan="4" class="px-6 py-12 text-center">
                            <div class="flex flex-col items-center justify-center">
                              <.icon name="hero-inbox" class="w-12 h-12 text-gray-400 mb-3" />
                              <p class="text-gray-500 font-medium">Tiada aktiviti terkini</p>
                            </div>
                          </td>
                        </tr>
                      <% else %>
                        <%= for activity <- @activities do %>
                          <tr class="hover:bg-gray-50 transition-colors duration-150">
                            <td class="px-6 py-4 whitespace-nowrap">
                              <div class="flex items-center">
                                <div class="flex-shrink-0 h-10 w-10 bg-gradient-to-br from-blue-500 to-blue-600 rounded-lg flex items-center justify-center mr-3">
                                  <.icon name="hero-folder" class="w-5 h-5 text-white" />
                                </div>
                                
                                <div class="text-sm font-medium text-gray-900">{activity.nama}</div>
                              </div>
                            </td>
                            
                            <td class="px-6 py-4">
                              <div class="text-sm text-gray-600">
                                <%= case Enum.filter(get_team_members(activity), fn member ->
                                      member.is_developer
                                    end) do %>
                                  <% [] -> %>
                                    <span class="text-gray-400">Tiada pembangun</span>
                                  <% developers -> %>
                                    <div class="flex flex-col gap-1">
                                      <%= for member <- developers do %>
                                        <span class="font-medium text-gray-900">{member.name}</span>
                                      <% end %>
                                    </div>
                                <% end %>
                              </div>
                            </td>
                            
                            <td class="px-6 py-4 whitespace-nowrap">
                              <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                <%= if Enum.any?(
                                      Enum.filter(get_team_members(activity), fn member ->
                                        member.is_developer
                                      end)
                                    ) do %>
                                  {activity.status}
                                <% else %>
                                  Belum lantik pembangun
                                <% end %>
                              </span>
                            </td>
                            
                            <td class="px-6 py-4 whitespace-nowrap">
                              <div class="flex items-center text-sm text-gray-600">
                                <.icon name="hero-calendar" class="w-4 h-4 text-gray-400 mr-2" />
                                <%= if activity.last_updated do %>
                                  {Calendar.strftime(activity.last_updated, "%d/%m/%Y %H:%M")}
                                <% else %>
                                  <span class="text-gray-400">-</span>
                                <% end %>
                              </div>
                            </td>
                          </tr>
                        <% end %>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
