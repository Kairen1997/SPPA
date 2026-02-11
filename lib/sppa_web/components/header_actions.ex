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

  attr :notifications_open, :boolean,
    default: false,
    doc: "Whether notifications dropdown is open"

  attr :notifications_count, :integer, default: 0, doc: "Number of notifications"
  attr :activities, :list, default: [], doc: "List of activities for notifications"
  attr :profile_menu_open, :boolean, default: false, doc: "Whether profile dropdown menu is open"
  attr :current_scope, :any, default: nil, doc: "The current user scope"

  def header_actions(assigns) do
    ~H"""
    <div class="flex items-center gap-2 sm:gap-3">
      <%!-- Notification Icon --%>
      <div class="relative" id="notification-container">
        <button
          id="notification-toggle-btn"
          type="button"
          phx-click="toggle_notifications"
          class="text-white hover:text-blue-100 hover:bg-blue-500/40 p-1.5 sm:p-2 rounded-lg transition-all duration-200 relative focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-blue-600 focus-visible:ring-white flex-shrink-0 cursor-pointer"
          aria-label="Notifikasi"
          aria-expanded={@notifications_open}
        >
          <.icon name="hero-bell" class="w-4 h-4 sm:w-5 sm:h-5 pointer-events-none" />
          <%= if @notifications_count > 0 do %>
            <span class="absolute -top-0.5 -right-0.5 inline-flex items-center justify-center px-1.5 h-4 min-w-[1rem] rounded-full bg-red-500 text-[0.6rem] font-semibold leading-none text-white shadow-sm">
              {@notifications_count}
            </span>
          <% end %>
        </button>
        <div
          id="notification-dropdown"
          class={[
            "absolute right-0 mt-3 w-80 bg-white rounded-xl shadow-2xl border border-blue-100 overflow-hidden z-50 origin-top-right transition-all duration-200",
            if(@notifications_open,
              do: "opacity-100 scale-100 pointer-events-auto",
              else: "opacity-0 scale-95 pointer-events-none"
            )
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
                      <p class="text-xs font-semibold text-gray-900 truncate">{activity.nama}</p>
                      
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
       <%!-- Profile Menu Dropdown --%>
      <div class="relative" id="profile-menu-container" phx-click-away="close_profile_menu">
        <button
          id="profile-menu-toggle-btn"
          type="button"
          phx-click="toggle_profile_menu"
          class="text-white hover:text-blue-100 hover:bg-blue-500/40 p-1.5 sm:p-2 rounded-lg transition-all duration-200 focus:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-blue-600 focus-visible:ring-white flex-shrink-0 cursor-pointer"
          aria-label="Menu Profil"
          aria-expanded={@profile_menu_open}
        >
          <.icon name="hero-user-circle" class="w-5 h-5 sm:w-6 sm:h-6 pointer-events-none" />
        </button>
        <div
          id="profile-menu-dropdown"
          class={[
            "absolute right-0 mt-3 w-56 bg-white rounded-xl shadow-2xl border border-blue-100 overflow-hidden z-50 origin-top-right transition-all duration-200",
            if(@profile_menu_open,
              do: "opacity-100 scale-100 pointer-events-auto",
              else: "opacity-0 scale-95 pointer-events-none"
            )
          ]}
        >
          <%!-- User Info Header --%>
          <div class="px-4 py-3 bg-gradient-to-r from-blue-600 to-blue-700 border-b border-blue-500">
            <p class="text-sm font-semibold text-white">
              <%= if @current_scope && @current_scope.user do %>
                {@current_scope.user.no_kp || "Pengguna"}
              <% else %>
                Pengguna
              <% end %>
            </p>
            
            <%= if @current_scope && @current_scope.user && @current_scope.user.role do %>
              <p class="text-xs text-blue-100 mt-0.5">{@current_scope.user.role}</p>
            <% end %>
          </div>
           <%!-- Menu Items --%>
          <div class="py-1 bg-white">
            <%!-- Settings Link --%>
            <.link
              navigate={~p"/users/settings"}
              class="flex items-center gap-3 px-4 py-2.5 text-sm text-gray-700 hover:bg-blue-50 transition-colors duration-150"
              phx-click="close_profile_menu"
            >
              <.icon name="hero-cog-6-tooth" class="w-4 h-4 text-gray-500" /> <span>Tetapan</span>
            </.link> <%!-- Divider --%>
            <div class="my-1 border-t border-gray-100"></div>
             <%!-- Logout Button --%>
            <.form for={%{}} action={~p"/users/log-out"} method="delete" class="inline w-full">
              <button
                type="submit"
                class="flex items-center gap-3 w-full px-4 py-2.5 text-sm text-red-600 hover:bg-red-50 transition-colors duration-150"
                aria-label="Log keluar"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4" /> <span>Log Keluar</span>
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
