defmodule SppaWeb.Components.Sidebar do
  @moduledoc """
  Sidebar component with burger icon toggle functionality.
  """
  use Phoenix.Component
  import SppaWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: SppaWeb.Endpoint,
    router: SppaWeb.Router,
    statics: SppaWeb.static_paths()

  attr :current_scope, :any, required: true, doc: "The current user scope"

  attr :desktop_sidebar_visible, :boolean,
    default: true,
    doc: "Whether the sidebar is visible on desktop"

  attr :current_path, :string,
    default: "/dashboard",
    doc: "Current path for active link highlighting"

  slot :inner_block, required: true, doc: "The main content area"

  def sidebar(assigns) do
    # Only render for pengurus projek role
    user_role =
      assigns.current_scope && assigns.current_scope.user && assigns.current_scope.user.role

    if user_role == "pengurus projek" do
      ~H"""
      <div class="relative flex flex-1 overflow-hidden">
        <%!-- Burger icon positioned beside sidebar --%>
        <button
          type="button"
          phx-click="toggle_desktop_sidebar"
          class={[
            "absolute top-6 z-10 hidden h-10 w-10 items-center justify-center rounded-full border border-gray-300 bg-white text-gray-600 shadow-sm transition-all hover:bg-gray-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2 md:flex",
            if(@desktop_sidebar_visible, do: "left-[calc(16rem+0.5rem)]", else: "left-[0.5rem]")
          ]}
          aria-label="Menu"
        >
          <.icon name="hero-bars-3" class="h-5 w-5" />
        </button>
         <%!-- Left sidebar --%>
        <aside class={[
          "w-64 flex-col bg-[#05243A] text-white shadow-xl transition-transform duration-300",
          if(@desktop_sidebar_visible, do: "hidden md:flex", else: "hidden")
        ]}>
          <div class="flex flex-col px-7 pt-10 pb-6 border-b border-white/10">
            <div class="mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-slate-300 to-slate-100 text-[#05243A] shadow-md">
              <.icon name="hero-user" class="h-9 w-9" />
            </div>

            <div class="text-base font-semibold leading-tight">
              {(@current_scope && @current_scope.user && @current_scope.user.no_kp) ||
                "Nama Pengguna"}
            </div>

            <div class="mt-1 text-xs uppercase tracking-wide text-gray-300">
              {(@current_scope && @current_scope.user && @current_scope.user.role) ||
                "Jawatan"}
            </div>
          </div>

          <nav class="mt-4 flex-1 text-sm">
            <.link
              navigate={~p"/dashboard-pp"}
              class={[
                "flex items-center gap-3 px-7 py-3 font-medium transition",
                if(@current_path == "/dashboard-pp",
                  do: "border-l-4 border-yellow-300 bg-[#0C304B] shadow-inner",
                  else: "text-gray-200 hover:bg-[#0C304B]"
                )
              ]}
            >
              <.icon
                name="hero-home"
                class={
                  if(@current_path == "/dashboard-pp",
                    do: "h-5 w-5 text-yellow-300",
                    else: "h-5 w-5 text-gray-300"
                  )
                }
              /> <span>Dashboard</span>
            </.link>
            <.link
              navigate={~p"/projek"}
              class={[
                "flex items-center gap-3 px-7 py-3 font-medium transition",
                if(@current_path == "/projek",
                  do: "border-l-4 border-yellow-300 bg-[#0C304B] shadow-inner",
                  else: "text-gray-200 hover:bg-[#0C304B]"
                )
              ]}
            >
              <.icon
                name="hero-folder"
                class={
                  if(@current_path == "/projek",
                    do: "h-5 w-5 text-yellow-300",
                    else: "h-5 w-5 text-gray-300"
                  )
                }
              /> <span>Projek</span>
            </.link>
            <.link
              navigate={~p"/soal-selidik"}
              class={[
                "flex items-center gap-3 px-7 py-3 font-medium transition",
                if(@current_path == "/soal-selidik",
                  do: "border-l-4 border-yellow-300 bg-[#0C304B] shadow-inner",
                  else: "text-gray-200 hover:bg-[#0C304B]"
                )
              ]}
            >
              <.icon
                name="hero-clipboard-document-list"
                class={
                  if(@current_path == "/soal-selidik",
                    do: "h-5 w-5 text-yellow-300",
                    else: "h-5 w-5 text-gray-300"
                  )
                }
              /> <span>Soal Selidik</span>
            </.link>
          </nav>
        </aside>
        {render_slot(@inner_block)}
      </div>
      """
    else
      # If not pengurus projek, just render the content without sidebar
      ~H"""
      <div class="flex flex-1 overflow-hidden">{render_slot(@inner_block)}</div>
      """
    end
  end
end
