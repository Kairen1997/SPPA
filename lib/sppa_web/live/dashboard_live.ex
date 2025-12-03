defmodule SppaWeb.DashboardLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :hide_root_header, true)
    socket = assign(socket, :page_title, "Papan Pemuka")

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
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <div class="fixed inset-0 flex h-screen bg-gray-100 z-50">
        <%!-- Sidebar --%>
        <aside class="w-64 bg-gray-800 text-white">
          <div class="p-4">
            <button class="text-white hover:text-gray-300">
              <.icon name="hero-bars-3" class="w-6 h-6" />
            </button>
          </div>
          <nav class="mt-4">
            <.link navigate={~p"/dashboard"} class="block px-4 py-2 bg-gray-700 text-white">Papan Pemuka</.link>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Senarai Projek</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Soal Selidik</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Analisis dan Rekabentuk</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Jadual Projek</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Pembangunan</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Pengurusan Perubahan</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Ujian Penerimaan Pengguna</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Ujian Keselamatan</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Penempatan</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Penyerahan</a>
            <a href="#" class="block px-4 py-2 hover:bg-gray-700 text-gray-300">Maklumbalas</a>
          </nav>
        </aside>

        <%!-- Main Content --%>
        <div class="flex-1 flex flex-col overflow-hidden">
          <%!-- Header --%>
          <header class="bg-blue-600 text-white px-6 py-4 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <div class="border-2 border-red-500 px-2 py-1 rounded">
                <span class="text-sm font-bold">JPKM</span>
              </div>
            </div>
            <div class="flex items-center gap-4">
              <button class="hover:bg-blue-700 p-2 rounded">
                <.icon name="hero-user-circle" class="w-6 h-6" />
              </button>
              <a href={~p"/users/log-out"} method="delete" class="hover:bg-blue-700 p-2 rounded">
                <.icon name="hero-arrow-right-on-rectangle" class="w-6 h-6" />
              </a>
            </div>
          </header>

          <%!-- Dashboard Content --%>
          <main class="flex-1 overflow-y-auto bg-white p-6">
            <h1 class="text-3xl font-bold text-gray-800 mb-6">Papan Pemuka</h1>

            <%!-- Summary Cards --%>
            <div class="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-6 gap-4 mb-8">
              <%!-- Total Projects --%>
              <div class="bg-yellow-400 rounded-lg p-6 shadow-md">
                <div class="text-4xl font-bold text-gray-800 mb-2">
                  {@stats[:total_projects] || 0}
                </div>
                <div class="text-sm text-gray-700">Jumlah Projek</div>
              </div>

              <%!-- In Development --%>
              <div class="bg-blue-400 rounded-lg p-6 shadow-md">
                <div class="text-4xl font-bold text-white mb-2">
                  {@stats[:in_development] || 0}
                </div>
                <div class="text-sm text-white">Projek Dalam Pembangunan</div>
              </div>

              <%!-- Completed --%>
              <div class="bg-green-400 rounded-lg p-6 shadow-md">
                <div class="text-4xl font-bold text-white mb-2">
                  {@stats[:completed] || 0}
                </div>
                <div class="text-sm text-white">Projek Selesai</div>
              </div>

              <%!-- On Hold --%>
              <div class="bg-red-400 rounded-lg p-6 shadow-md">
                <div class="text-4xl font-bold text-white mb-2">
                  {@stats[:on_hold] || 0}
                </div>
                <div class="text-sm text-white">Projek Ditangguhkan</div>
              </div>

              <%!-- UAT --%>
              <div class="bg-purple-400 rounded-lg p-6 shadow-md">
                <div class="text-4xl font-bold text-white mb-2">
                  {@stats[:uat] || 0}
                </div>
                <div class="text-sm text-white">UAT</div>
              </div>

              <%!-- Change Management --%>
              <div class="bg-orange-400 rounded-lg p-6 shadow-md">
                <div class="text-4xl font-bold text-white mb-2">
                  {@stats[:change_management] || 0}
                </div>
                <div class="text-sm text-white">Pengurusan Perubahan</div>
              </div>
            </div>

            <%!-- Latest Activities --%>
            <div class="mt-8">
              <h2 class="text-xl font-semibold text-gray-600 mb-4">Aktiviti Terkini</h2>
              <div class="overflow-x-auto">
                <table class="min-w-full bg-white border border-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b">
                        Nama Projek
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b">
                        Pembangun / Pengurus Projek
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b">
                        Status Terkini
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b">
                        Tarikh Akhir Kemaskini
                      </th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= if Enum.empty?(@activities) do %>
                      <tr>
                        <td colspan="4" class="px-6 py-4 text-center text-gray-500">
                          Tiada aktiviti terkini
                        </td>
                      </tr>
                    <% else %>
                      <%= for activity <- @activities do %>
                        <tr class="hover:bg-gray-50">
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                            {activity.name}
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <%= if activity.developer do %>
                              {activity.developer.email}
                            <% end %>
                            <%= if activity.project_manager do %>
                              / {activity.project_manager.email}
                            <% end %>
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            {activity.status}
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                            <%= if activity.last_updated do %>
                              {Calendar.strftime(activity.last_updated, "%d/%m/%Y %H:%M")}
                            <% else %>
                              -
                            <% end %>
                          </td>
                        </tr>
                      <% end %>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
