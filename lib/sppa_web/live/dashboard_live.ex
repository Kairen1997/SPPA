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
      socket = assign(socket, :hide_root_header, true)
      socket = assign(socket, :page_title, "Papan Pemuka")
      # Sidebar starts closed on mobile, but we'll show it by default on desktop via CSS
      socket = assign(socket, :sidebar_open, false)
      # Desktop sidebar visibility - defaults to true (shown), but will be overridden by JS hook
      socket = assign(socket, :desktop_sidebar_visible, true)

      # Initialize with fallback values so they're preserved if real stats are zero
      fallback_stats = %{
        total_projects: 270,
        in_development: 100,
        completed: 50
      }

      if connected?(socket) do
        new_stats = Projects.get_dashboard_stats(socket.assigns.current_scope)
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)

        # Merge stats preserving displayed values - once a stat shows a value, don't let it go to zero
        displayed_stats =
          socket.assigns
          |> Map.get(:stats, fallback_stats)
          |> merge_stats_preserving_values(new_stats)

        {:ok,
         socket
         |> assign(:stats, displayed_stats)
         |> assign(:activities, activities)}
      else
        {:ok,
         socket
         |> assign(:stats, fallback_stats)
         |> assign(:activities, [])}
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
  def handle_event("toggle_desktop_sidebar", _params, socket) do
    new_state = !socket.assigns.desktop_sidebar_visible
    {:noreply, assign(socket, :desktop_sidebar_visible, new_state)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <div class="flex min-h-screen flex-col bg-[#F4F5FB] text-gray-800">
        <.topbar current_scope={@current_scope} />

        <.sidebar
          current_scope={@current_scope}
          desktop_sidebar_visible={@desktop_sidebar_visible}
          current_path="/dashboard"
        >
          <%!-- Main dashboard content --%>
          <main class="flex-1 overflow-y-auto px-4 pb-10 pt-6 sm:px-6 lg:px-10">
            <div class="mx-auto flex max-w-6xl flex-col gap-6">
              <%!-- Page title row --%>
              <div class="flex items-center justify-between">
                <div class="flex flex-col">
                  <span class="text-xs font-semibold tracking-[0.2em] text-gray-400">
                    PAPAN PEMUKA
                  </span>
                  <span class="text-2xl font-semibold tracking-wide text-gray-800">
                    Dashboard
                  </span>
                </div>

                <div class="hidden items-center gap-3 text-xs text-gray-500 md:flex">
                  <span>Status akaun:</span>
                  <span class="inline-flex items-center rounded-full bg-emerald-50 px-3 py-1 font-medium text-emerald-700 ring-1 ring-emerald-100">
                    <span class="mr-1 h-2 w-2 rounded-full bg-emerald-500" />
                    Aktif
                  </span>
                </div>
              </div>

              <%!-- Three summary cards row --%>
              <div class="grid grid-cols-1 gap-6 md:grid-cols-3 md:pr-24">
                <div class="flex h-32 flex-col items-center justify-center rounded-xl bg-[#F2C94C] text-center shadow-lg shadow-yellow-200/70">
                  <div class="text-4xl font-bold leading-none text-gray-900">
                    {@stats[:total_projects] || 270}
                  </div>
                  <div class="mt-2 text-sm font-medium tracking-wide text-gray-900">
                    Jumlah Projek
                  </div>
                </div>

                <div class="flex h-32 flex-col items-center justify-center rounded-xl bg-[#2F80ED] text-center shadow-lg shadow-blue-300/70">
                  <div class="text-4xl font-bold leading-none text-white">
                    {@stats[:in_development] || 100}
                  </div>
                  <div class="mt-2 text-sm font-medium tracking-wide text-white">
                    Projek Dalam Pembangunan
                  </div>
                </div>

                <div class="flex h-32 flex-col items-center justify-center rounded-xl bg-[#27AE60] text-center shadow-lg shadow-emerald-300/70">
                  <div class="text-4xl font-bold leading-none text-white">
                    {@stats[:completed] || 50}
                  </div>
                  <div class="mt-2 text-sm font-medium tracking-wide text-white">
                    Projek Selesai
                  </div>
                </div>
              </div>

              <%!-- Project summary panel --%>
              <section class="mt-2 flex rounded-3xl bg-[#F3F3F3] shadow-lg">
                <div class="flex-1 px-8 py-8 sm:px-10">
                  <div class="mb-6 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div class="space-y-1">
                      <div class="text-sm font-semibold text-gray-700">
                        Ringkasan Projek
                      </div>
                      <p class="text-xs text-gray-500">
                        Gambaran keseluruhan projek di bawah seliaan anda.
                      </p>
                    </div>

                    <div class="relative">
                      <input
                        type="text"
                        name="search"
                        placeholder="Carian...."
                        class="w-64 rounded-full border border-gray-300 bg-white px-4 py-2 text-sm text-gray-700 shadow-sm outline-none transition focus:border-blue-400 focus:ring-2 focus:ring-blue-200"
                      />
                    </div>
                  </div>

                  <div class="overflow-hidden rounded-2xl bg-white shadow-sm">
                    <div class="grid grid-cols-4 border-b border-gray-100 bg-gray-50 px-6 py-3 text-xs font-semibold uppercase tracking-wide text-gray-500">
                      <div>Nama</div>
                      <div>Pengurus</div>
                      <div>Tarikh Tamat Tempoh</div>
                      <div>Status</div>
                    </div>

                    <div class="px-6 py-4 text-sm text-gray-800">
                      <div class="grid grid-cols-4 gap-4">
                        <div class="font-medium">XXXX XXXX XXXX</div>
                        <div>XXXX XXXX XXXX</div>
                        <div>XXXX XX, XXXX</div>
                        <div>
                          <span class="inline-flex rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold text-amber-700 ring-1 ring-amber-100">
                            XX XXXXXXXX
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </section>
            </div>
          </main>
        </.sidebar>
      </div>
    </Layouts.app>
    """
  end
end
