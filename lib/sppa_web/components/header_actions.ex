defmodule SppaWeb.Components.HeaderActions do
  @moduledoc """
  Header actions component for notification and logout buttons.
  """
  use Phoenix.Component
  import SppaWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: SppaWeb.Endpoint,
    router: SppaWeb.Router,
    statics: SppaWeb.static_paths()

  attr :notifications_open, :boolean, default: false, doc: "Whether notifications dropdown is open"
  attr :notifications_count, :integer, default: 0, doc: "Number of notifications"
  attr :activities, :list, default: [], doc: "List of activities for notifications"

  def header_actions(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <%!-- Notification Icon --%>
      <div class="relative" id="notification-container">
        <button
          id="notification-toggle-btn"
          type="button"
          phx-click="toggle_notifications"
          phx-hook="NotificationToggle"
          class="text-white hover:text-blue-100 hover:bg-blue-500/40 p-2 rounded-lg transition-all duration-200 relative focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-blue-600 focus-visible:ring-white"
          aria-label="Notifikasi"
          aria-expanded={@notifications_open}
        >
          <.icon name="hero-bell" class="w-5 h-5" />
          <%= if @notifications_count > 0 do %>
            <span class="absolute -top-0.5 -right-0.5 inline-flex items-center justify-center px-1.5 h-4 min-w-[1rem] rounded-full bg-red-500 text-[0.6rem] font-semibold leading-none text-white shadow-sm">
              {@notifications_count}
            </span>
          <% else %>
            <span class="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
          <% end %>
        </button>
        <div
          id="notification-dropdown"
          class={[
            "absolute right-0 mt-3 w-80 bg-white rounded-xl shadow-2xl border border-blue-100 overflow-hidden z-50 origin-top-right transition-all duration-200",
            if(@notifications_open, do: "opacity-100 scale-100 pointer-events-auto", else: "opacity-0 scale-95 pointer-events-none")
          ]}
          phx-click-away="close_notifications"
        >
            <div class="px-4 py-3 bg-gradient-to-r from-blue-600 to-blue-700">
              <p class="text-sm font-semibold text-white">Notifikasi</p>

              <p class="text-xs text-blue-100">
                <%= if @notifications_count > 0 do %>
                  Anda mempunyai {@notifications_count} aktiviti terkini
                <% else %>
                  Tiada notifikasi baharu buat masa ini
                <% end %>
              </p>
            </div>

            <div class="max-h-80 overflow-y-auto divide-y divide-gray-100 bg-white">
              <%= if Enum.empty?(@activities) do %>
                <div class="px-4 py-6 flex flex-col items-center justify-center text-center">
                  <.icon name="hero-inbox" class="w-10 h-10 text-gray-300 mb-2" />
                  <p class="text-sm font-medium text-gray-600">Tiada aktiviti terkini</p>

                  <p class="text-xs text-gray-400 mt-1">
                    Notifikasi baharu akan dipaparkan di sini sebaik sahaja terdapat kemaskini.
                  </p>
                </div>
              <% else %>
                <%= for activity <- @activities do %>
                  <div class="px-4 py-3 hover:bg-blue-50/60 transition-colors duration-150">
                    <div class="flex items-start gap-3">
                      <div class="mt-0.5 flex h-8 w-8 items-center justify-center rounded-full bg-gradient-to-br from-blue-500 to-blue-600 shadow-sm">
                        <.icon name="hero-bell-alert" class="w-4 h-4 text-white" />
                      </div>

                      <div class="flex-1 min-w-0">
                        <p class="text-xs font-semibold text-gray-900 truncate">
                          {activity.name}
                        </p>

                        <p class="mt-0.5 text-[0.70rem] text-gray-600 line-clamp-2">
                          Status terkini projek dikemaskini kepada <span class="font-semibold">{activity.status}</span>.
                        </p>

                        <div class="mt-1 flex items-center gap-2 text-[0.65rem] text-gray-400">
                          <.icon name="hero-clock" class="w-3 h-3" />
                          <%= if activity.last_updated do %>
                            {Calendar.strftime(activity.last_updated, "%d/%m/%Y %H:%M")}
                          <% else %>
                            <span>-</span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
      </div>

      <%!-- User Settings Link --%>
      <.link
        navigate={~p"/users/settings"}
        class="text-white hover:text-blue-100 hover:bg-blue-500/40 p-2 rounded-lg transition-all duration-200"
      >
        <.icon name="hero-user-circle" class="w-6 h-6" />
      </.link>

      <%!-- Logout Button --%>
      <.form for={%{}} action={~p"/users/log-out"} method="delete" class="inline">
        <button
          type="submit"
          class="text-white hover:text-red-100 hover:bg-red-500/30 p-2 rounded-lg transition-all duration-200"
          aria-label="Log keluar"
        >
          <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" />
        </button>
      </.form>
    </div>
    """
  end
end
