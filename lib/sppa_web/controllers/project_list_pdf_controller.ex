defmodule SppaWeb.ProjectListPdfController do
  use SppaWeb, :controller

  alias Sppa.Repo
  import Ecto.Query

  def index(conn, _params) do
    current_scope = conn.assigns.current_scope

    # Verify user is pengurus projek
    user_role =
      current_scope && current_scope.user && current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      # Get all approved projects (same logic as ProjectListLive)
      projects = list_projects()

      conn
      |> put_layout(false)
      |> render(:index, projects: projects, current_scope: current_scope)
    else
      conn
      |> put_status(:forbidden)
      |> put_view(html: SppaWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  defp list_projects do
    # Base query with join to internal project (if exists)
    base_query =
      from ap in Sppa.ApprovedProjects.ApprovedProject,
        left_join: p in assoc(ap, :project),
        preload: [project: p]

    # Order by external updated_at (newest first)
    base_query
    |> order_by([ap, _p], desc: ap.external_updated_at)
    |> Repo.all()
  end
end
