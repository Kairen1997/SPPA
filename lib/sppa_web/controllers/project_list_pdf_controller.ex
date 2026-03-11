defmodule SppaWeb.ProjectListPdfController do
  use SppaWeb, :controller

  alias Sppa.Repo
  alias Sppa.Projects
  import Ecto.Query

  def index(conn, _params) do
    current_scope = conn.assigns.current_scope

    user_role =
      current_scope && current_scope.user && current_scope.user.role

    # Only pengurus projek and ketua unit may generate the PDF
    if user_role in ["pengurus projek", "ketua unit"] do
      projects = list_projects_for_pdf(current_scope)

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

  # Ketua unit: whole project list. Pengurus projek: only projects assigned to them (by no_kp in pengurus_projek).
  defp list_projects_for_pdf(current_scope) do
    user_role = current_scope && current_scope.user && current_scope.user.role
    user_no_kp = current_scope && current_scope.user && current_scope.user.no_kp

    base_query =
      from ap in Sppa.ApprovedProjects.ApprovedProject,
        left_join: p in assoc(ap, :project),
        preload: [project: p]

    base_query
    |> order_by([ap, _p], desc: ap.external_updated_at)
    |> Repo.all()
    |> filter_by_role(user_role, user_no_kp)
    |> Enum.map(&ensure_project_loaded/1)
  end

  defp filter_by_role(approved_projects, "ketua unit", _user_no_kp) do
    approved_projects
  end

  defp filter_by_role(approved_projects, "pengurus projek", user_no_kp) do
    Enum.filter(approved_projects, fn ap ->
      has_pm_assignment?(ap, user_no_kp)
    end)
  end

  defp filter_by_role(approved_projects, _role, _user_no_kp), do: approved_projects

  defp has_pm_assignment?(approved_project, user_no_kp) when is_binary(user_no_kp) do
    pengurus = approved_project.pengurus_projek

    if is_binary(pengurus) and pengurus != "" do
      pengurus
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.any?(&(&1 == user_no_kp))
    else
      false
    end
  end

  defp has_pm_assignment?(_approved_project, _), do: false

  defp ensure_project_loaded(%Sppa.ApprovedProjects.ApprovedProject{} = approved_project) do
    project =
      case approved_project.project do
        %Sppa.Projects.Project{} = p ->
          p

        _ ->
          case Projects.ensure_internal_project_for_approved(approved_project) do
            {:ok, p} -> p
            _ -> nil
          end
      end

    Map.put(approved_project, :project, project)
  end
end
