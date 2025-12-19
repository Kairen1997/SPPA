defmodule SppaWeb.Components.Topbar do
  @moduledoc """
  Topbar component for dashboard pages.
  """
  use Phoenix.Component
  import SppaWeb.CoreComponents

  use Phoenix.VerifiedRoutes,
    endpoint: SppaWeb.Endpoint,
    router: SppaWeb.Router,
    statics: SppaWeb.static_paths()

  attr :current_scope, :any, required: true, doc: "The current user scope"

  def topbar(assigns) do
    # Only render for pengurus projek role
    user_role =
      assigns.current_scope && assigns.current_scope.user && assigns.current_scope.user.role

    if user_role == "pengurus projek" do
      ~H"""
      <header class="flex h-24 w-full items-center justify-between bg-[#0057D9] px-8 shadow-md relative">
        <.system_title />
        <div class="flex items-center gap-5">
          <img
            src={~p"/images/channels4_profile-1-48.png"}
            alt="Logo Negeri"
            class="h-24 w-24 object-contain"
          />
          <img
            src={~p"/images/logojpkn-1-1-6.png"}
            alt="Logo JPKN"
            class="h-24 w-auto object-contain"
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
      """
    else
      ~H"""
      <div></div>
      """
    end
  end
end
