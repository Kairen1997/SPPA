defmodule SppaWeb.Router do
  use SppaWeb, :router

  import SppaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SppaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  # scope "/api", SppaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:sppa, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SppaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", SppaWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_dashboard_role,
      on_mount: [{SppaWeb.UserAuth, :require_dashboard_role}] do
      live "/dashboard-pp", DashboardPPLive, :index
      live "/dashboard", DashboardLive, :index
      live "/projek", ProjekLive, :index
      live "/projek/:id", ProjekLive, :show
      live "/projek/:id/details", ProjectDetailsLive, :show
      live "/soal-selidik", SoalSelidikLive, :index
      live "/senarai-projek", PengurusProjekLive, :index
      live "/projek/:project_id/modul", ModulProjekLive, :index
      live "/projek/:project_id/pelan-modul", PelanModulLive, :index
      live "/analisis-dan-rekabentuk", AnalisisDanRekabentukLive, :index
    end

    live_session :require_authenticated_user,
      on_mount: [{SppaWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", SppaWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{SppaWeb.UserAuth, :mount_current_scope}] do
      live "/", UserLive.Login, :new
      live "/login", UserLive.Login, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
