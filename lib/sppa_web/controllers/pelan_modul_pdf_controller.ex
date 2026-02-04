defmodule SppaWeb.PelanModulPdfController do
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
        # Get modules for this specific project
        modules = ProjectModules.list_modules_for_project(current_scope, project_id)
        gantt_data = build_gantt_data_for_project(project, modules)

        if gantt_data do
          conn
          |> put_layout(false)
          |> render(:show,
            project: project,
            modules: modules,
            gantt_data: gantt_data,
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

  # Build Gantt chart data for a specific project (matches PelanModulLive logic)
  defp build_gantt_data_for_project(project, modules) do
    if Enum.empty?(modules) do
      nil
    else
      project_start =
        project.tarikh_mula ||
          (project.approved_project && project.approved_project.tarikh_mula) ||
          get_earliest_date(modules)

      project_end =
        project.tarikh_siap ||
          (project.approved_project && project.approved_project.tarikh_jangkaan_siap) ||
          get_latest_date(modules)

      # Normalise modules with derived start/end dates
      enriched_modules =
        Enum.map(modules, fn m ->
          start_date = project_start
          end_date = m.due_date || project_end || project_start

          Map.merge(
            m,
            %{
              start_date: start_date,
              end_date: end_date
            }
          )
        end)

      # Sort modules by phase and version
      sorted_modules = sort_modules_by_phase_and_version(enriched_modules)

      %{
        project: project,
        modules: sorted_modules,
        start_date: project_start,
        end_date: project_end
      }
    end
  end

  defp get_earliest_date(modules) do
    if Enum.empty?(modules) do
      Date.utc_today()
    else
      modules
      |> Enum.map(& &1.due_date)
      |> Enum.filter(& &1)
      |> case do
        [] -> Date.utc_today()
        dates -> Enum.min(dates)
      end
    end
  end

  defp get_latest_date(modules) do
    if Enum.empty?(modules) do
      Date.utc_today()
    else
      modules
      |> Enum.map(& &1.due_date)
      |> Enum.filter(& &1)
      |> case do
        [] -> Date.utc_today()
        dates -> Enum.max(dates)
      end
    end
  end

  defp sort_modules_by_phase_and_version(modules) do
    Enum.sort_by(modules, fn module ->
      phase_num = parse_numeric(module.fasa)
      version_num = parse_numeric(module.versi)
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
