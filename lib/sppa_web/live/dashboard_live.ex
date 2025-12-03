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
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <div class="flex min-h-screen flex-col bg-[#F4F5FB] text-gray-800">
        <%!-- Top blue header with agency logos and logout icon --%>
        <header class="flex h-20 w-full items-center justify-between bg-[#0057D9] px-8 shadow-md">
          <div class="flex items-center gap-5">
            <img
              src={~p"/images/channels4_profile-1-48.png"}
              alt="Logo Negeri"
              class="h-10 w-10 rounded-md bg-white/10 p-1 shadow-sm"
            />
            <img
              src={~p"/images/logojpkn-1-1-6.png"}
              alt="Logo JPKN"
              class="h-10 w-auto drop-shadow-sm"
            />
          </div>

          <div class="flex items-center gap-5">
            <div class="hidden flex-col items-end text-xs text-blue-100 sm:flex">
              <span class="uppercase tracking-wide opacity-80">Pengguna Log Masuk</span>
              <span class="font-semibold text-white">
                {(@current_scope && @current_scope.user && @current_scope.user.no_kp) ||
                  "Nama Pengguna"}
              </span>
            </div>

            <div class="flex items-center gap-2 rounded-full bg-white/10 px-4 py-1.5 text-sm shadow-sm">
              <.icon name="hero-user-circle" class="h-5 w-5 text-white" />
              <span class="text-white sm:hidden">
                {(@current_scope && @current_scope.user && @current_scope.user.no_kp) ||
                  "Nama Pengguna"}
              </span>
            </div>

            <.form for={%{}} action={~p"/users/log-out"} method="delete" class="inline">
              <button
                type="submit"
                class="inline-flex h-10 w-10 items-center justify-center rounded-full text-white transition hover:bg-white/10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-offset-[#0057D9] focus-visible:ring-white"
                aria-label="Log keluar"
              >
                <.icon name="hero-arrow-right-on-rectangle" class="h-6 w-6" />
              </button>
            </.form>
          </div>
        </header>

        <div class="flex flex-1 overflow-hidden">
          <%!-- Left sidebar --%>
          <aside class="hidden w-64 flex-col bg-[#05243A] text-white shadow-xl md:flex">
            <div class="flex flex-col px-7 pt-10 pb-6 border-b border-white/10">
              <div class="mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-slate-300 to-slate-100 text-[#05243A] shadow-md">
                <.icon name="hero-user" class="h-9 w-9" />
              </div>
              <div class="text-base font-semibold leading-tight">
                Nama Pengguna
              </div>
              <div class="mt-1 text-xs uppercase tracking-wide text-gray-300">
                Jawatan
              </div>
            </div>

            <nav class="mt-4 flex-1 text-sm">
              <.link
                navigate={~p"/dashboard"}
                class="flex items-center gap-3 border-l-4 border-yellow-300 bg-[#0C304B] px-7 py-3 font-medium shadow-inner"
              >
                <.icon name="hero-home" class="h-5 w-5 text-yellow-300" />
                <span>Dashboard</span>
              </.link>

              <a
                href="#"
                class="flex items-center gap-3 px-7 py-3 text-gray-200 transition hover:bg-[#0C304B]"
              >
                <.icon name="hero-folder" class="h-5 w-5 text-gray-300" />
                <span>Projek</span>
              </a>
            </nav>
          </aside>

          <%!-- Main dashboard content --%>
          <main class="flex-1 overflow-y-auto px-4 pb-10 pt-6 sm:px-6 lg:px-10">
            <div class="mx-auto flex max-w-6xl flex-col gap-6">
              <%!-- Page title row with subtle menu icon --%>
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-4">
                  <button
                    type="button"
                    class="flex h-10 w-10 items-center justify-center rounded-full border border-gray-300 bg-white text-gray-600 shadow-sm transition hover:bg-gray-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2"
                    aria-label="Menu"
                  >
                    <.icon name="hero-bars-3" class="h-5 w-5" />
                  </button>
                  <div class="flex flex-col">
                    <span class="text-xs font-semibold tracking-[0.2em] text-gray-400">
                      PAPAN PEMUKA
                    </span>
                    <span class="text-2xl font-semibold tracking-wide text-gray-800">
                      Dashboard
                    </span>
                  </div>
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
        </div>
      </div>
    </Layouts.app>
    """
  end
end
