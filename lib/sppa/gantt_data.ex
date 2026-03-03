defmodule Sppa.GanttData do
  @moduledoc """
  Shared Gantt chart data builder used by Pelan Modul and Jadual Projek (pembangun sistem).
  Builds module-level Gantt data from a project and its project modules (tugasan).
  """

  @doc """
  Builds Gantt chart data for a single project from its modules (from Modul Projek / Pelan Modul).
  Returns `nil` if modules is empty. Otherwise returns:
  `%{project: project, modules: sorted_enriched_modules, start_date: date, end_date: date}`.
  """
  def build_project_gantt(project, modules) when is_list(modules) do
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

      enriched_modules =
        Enum.map(modules, fn m ->
          start_date = m.tarikh_mula || project_start
          end_date = m.due_date || project_end || project_start

          developer_name =
            cond do
              m.developer && m.developer.email && m.developer.email != "" -> m.developer.email
              m.developer && m.developer.no_kp && m.developer.no_kp != "" -> m.developer.no_kp
              true -> nil
            end

          beyond_end? =
            end_date && project_end && Date.compare(end_date, project_end) == :gt

          Map.merge(m, %{
            start_date: start_date,
            end_date: end_date,
            developer_name: developer_name,
            beyond_end?: beyond_end?
          })
        end)

      sorted_modules = sort_modules_by_phase_and_version(enriched_modules)

      %{
        project: project,
        modules: sorted_modules,
        start_date: project_start,
        end_date: project_end
      }
    end
  end

  def build_project_gantt(_project, _), do: nil

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

  defp get_earliest_date(modules) do
    if Enum.empty?(modules) do
      Date.utc_today()
    else
      dates =
        Enum.flat_map(modules, fn m ->
          [m.tarikh_mula, m.due_date] |> Enum.filter(& &1)
        end)

      if dates == [], do: Date.utc_today(), else: Enum.min(dates)
    end
  end

  defp get_latest_date(modules) do
    if Enum.empty?(modules) do
      Date.utc_today()
    else
      dates = modules |> Enum.map(& &1.due_date) |> Enum.filter(& &1)
      if dates == [], do: Date.utc_today(), else: Enum.max(dates)
    end
  end
end
