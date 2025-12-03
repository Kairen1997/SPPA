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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <div class="flex h-screen flex-col bg-[#F4F5FB] text-gray-800">
        <%!-- Top blue header with agency logos and logout icon --%>
        <header class="flex h-16 w-full items-center justify-between bg-[#0057D9] px-6 shadow-md">
          <div class="flex items-center gap-4">
            <img
              src={~p"/images/logojpkn-1-1-6.png"}
              alt="Logo Negeri"
              class="h-10 w-auto"
            />
            <img
              src={~p"/images/Logo JPKN.png"}
              alt="Logo JPKN"
              class="h-8 w-auto"
            />
          </div>

          <div class="flex items-center gap-4">
            <div class="flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-sm">
              <.icon name="hero-user-circle" class="h-5 w-5 text-white" />
              <span class="text-white">
                {@current_scope && @current_scope.user && @current_scope.user.no_kp || "Nama Pengguna"}
              </span>
            </div>

            <.form for={%{}} action={~p"/users/log-out"} method="delete" class="inline">
              <button
                type="submit"
                class="inline-flex h-10 w-10 items-center justify-center rounded-full text-white transition hover:bg-white/10"
                aria-label="Log keluar"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="h-6 w-6" />
              </button>
            </.form>
          </div>
        </header>

        <div class="flex flex-1 overflow-hidden">
          <%!-- Left sidebar --%>
          <aside class="flex w-64 flex-col bg-[#05243A] text-white">
            <div class="flex flex-col px-6 pt-10 pb-6">
              <div class="mb-4 h-16 w-16 rounded-full bg-gray-400"></div>
              <div class="text-lg font-semibold">Nama Pengguna</div>
              <div class="text-sm text-gray-300">Jawatan</div>
            </div>

            <nav class="mt-4 flex-1">
              <.link
                navigate={~p"/dashboard"}
                class="flex items-center gap-3 border-l-4 border-yellow-300 bg-[#0C304B] px-6 py-3 text-sm font-medium shadow-inner"
              >
                <.icon name="hero-home" class="h-5 w-5 text-yellow-300" />
                <span>Dashboard</span>
              </.link>

              <.link
                navigate={~p"/projects"}
                class="flex items-center gap-3 px-6 py-3 text-sm text-gray-200 transition hover:bg-[#0C304B]"
              >
                <.icon name="hero-folder" class="h-5 w-5 text-gray-300" />
                <span>Projek</span>
              </.link>
            </nav>
          </aside>

          <%!-- Main dashboard content --%>
          <main class="flex-1 overflow-y-auto px-10 pb-10 pt-8">
            <%!-- Page title row with subtle menu icon --%>
            <div class="mb-8 flex items-center gap-4">
              <button
                type="button"
                class="flex h-10 w-10 items-center justify-center rounded-full border border-gray-300 bg-white shadow-sm"
                aria-label="Menu"
              >
                <.icon name="hero-bars-3" class="h-5 w-5 text-gray-600" />
              </button>
              <span class="text-lg font-semibold tracking-wide text-gray-700">
                DASHBOARD
              </span>
            </div>

            <%!-- Three summary cards row --%>
            <div class="mb-12 grid grid-cols-1 gap-8 md:grid-cols-3 md:pr-24">
              <div class="flex h-32 flex-col items-center justify-center rounded-md bg-[#F2C94C] text-center shadow-md">
                <div class="text-4xl font-bold text-gray-800">
                  {@stats[:total_projects] || 270}
                </div>
                <div class="mt-1 text-sm text-gray-800">Jumlah Projek</div>
              </div>

              <div class="flex h-32 flex-col items-center justify-center rounded-md bg-[#2F80ED] text-center shadow-md">
                <div class="text-4xl font-bold text-white">
                  {@stats[:in_development] || 100}
                </div>
                <div class="mt-1 text-sm text-white">Projek Dalam Pembangunan</div>
              </div>

              <div class="flex h-32 flex-col items-center justify-center rounded-md bg-[#27AE60] text-center shadow-md">
                <div class="text-4xl font-bold text-white">
                  {@stats[:completed] || 50}
                </div>
                <div class="mt-1 text-sm text-white">Projek Selesai</div>
              </div>
            </div>

            <%!-- Project summary panel --%>
            <section class="mr-10 flex rounded-2xl bg-[#F3F3F3] shadow-md">
              <div class="flex-1 px-10 py-8">
                <div class="mb-6 flex items-center justify-between">
                  <div class="text-sm font-semibold text-gray-700">
                    Ringkasan Projek
                  </div>

                  <div class="relative">
                    <input
                      type="text"
                      name="search"
                      placeholder="Carian...."
                      class="w-64 rounded-full border border-gray-300 bg-white px-4 py-2 text-sm text-gray-700 shadow-sm outline-none focus:border-blue-400 focus:ring-1 focus:ring-blue-400"
                    />
                  </div>
                </div>

                <div class="overflow-hidden rounded-xl bg-white/0">
                  <div class="grid grid-cols-4 border-b border-transparent px-2 pb-4 text-xs font-semibold uppercase tracking-wide text-gray-600">
                    <div>Nama</div>
                    <div>Pengurus</div>
                    <div>Tarikh Tamat Tempoh</div>
                    <div>Status</div>
                  </div>

                  <div class="mt-2 rounded-xl bg-white px-6 py-4 text-sm text-gray-800 shadow-sm">
                    <div class="grid grid-cols-4 gap-4">
                      <div>XXXX XXXX XXXX</div>
                      <div>XXXX XXXX XXXX</div>
                      <div>XXXX XX, XXXX</div>
                      <div>XX XXXXXXXX</div>
                    </div>
                  </div>
                </div>
              </div>
            </section>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
