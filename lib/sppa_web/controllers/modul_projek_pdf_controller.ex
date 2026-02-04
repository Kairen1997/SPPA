defmodule SppaWeb.ModulProjekPdfController do
  use SppaWeb, :controller

  alias Sppa.Projects
  alias Sppa.ProjectModules

  def show(conn, %{"project_id" => project_id}) do
    project_id = String.to_integer(project_id)
    current_scope = conn.assigns.current_scope

    # Verify user is pengurus projek
    user_role =
      current_scope && current_scope.user && current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      # Get project details
      project =
        try do
          Projects.get_project!(project_id, current_scope)
        rescue
          Ecto.NoResultsError -> nil
        end

      if project do
        # Get tasks (modules) from database
        tasks = ProjectModules.list_modules_for_project(current_scope, project_id)
        sorted_tasks = sort_tasks_by_phase_and_version(tasks)

        conn
        |> put_layout(false)
        |> render(:show,
          project: project,
          tasks: sorted_tasks,
          current_scope: current_scope,
          status_label: &status_label/1,
          priority_label: &priority_label/1
        )
      else
        conn
        |> put_status(:not_found)
        |> put_view(html: SppaWeb.ErrorHTML)
        |> render(:"404")
      end
    else
      conn
      |> put_status(:forbidden)
      |> put_view(html: SppaWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  defp sort_tasks_by_phase_and_version(tasks) do
    Enum.sort_by(tasks, fn task ->
      phase_num = parse_numeric(task.fasa)
      version_num = parse_numeric(task.versi)
      {phase_num, version_num}
    end)
  end

  defp parse_numeric(value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_numeric(value) when is_integer(value), do: value
  defp parse_numeric(_), do: 0

  def status_label("in_progress"), do: "Dalam Proses"
  def status_label("done"), do: "Selesai"
  def status_label(_), do: "Dalam Proses"

  def priority_label("high"), do: "Tinggi"
  def priority_label("medium"), do: "Sederhana"
  def priority_label("low"), do: "Rendah"
  def priority_label(_), do: "Sederhana"
end
