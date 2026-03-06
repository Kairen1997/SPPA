defmodule Sppa.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Sppa.Repo
  alias Sppa.Projects.Project
  alias Sppa.ApprovedProjects.ApprovedProject
  alias Sppa.ActivityLogs

  @doc """
  Returns the list of projects for a user scope.
  """
  def list_projects(current_scope) do
    Project
    |> where([p], p.user_id == ^current_scope.user.id)
    |> preload([:developer, :project_manager, :approved_project])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
  end

  @doc """
  Returns the list of projects for a pengurus projek (project manager).
  Projects where the current user is assigned as project manager.
  """
  def list_projects_for_pengurus_projek(current_scope) do
    user_id = current_scope.user && current_scope.user.id
    if is_nil(user_id), do: [], else: list_projects_for_pengurus_projek_by_id(user_id)
  end

  defp list_projects_for_pengurus_projek_by_id(user_id) do
    Project
    |> where([p], p.project_manager_id == ^user_id and not is_nil(p.approved_project_id))
    |> preload([:developer, :project_manager, :approved_project])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
    |> Enum.map(&format_project_for_display/1)
  end

  @doc """
  Returns the list of all projects (for directors/admins).
  """
  def list_all_projects do
    Project
    |> preload([:developer, :project_manager, :approved_project])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
    |> Enum.map(&format_project_for_display/1)
  end

  @doc """
  Returns only projects assigned to the current user (as project manager or developer).
  Used so that Senarai Sistem shows "sistem yang ditugaskan sahaja" for all roles including ketua penolong pengarah.
  Filters at database level so unassigned systems are never loaded or displayed.
  """
  def list_projects_assigned_to_user(current_scope) do
    if is_nil(current_scope) or is_nil(current_scope.user) do
      []
    else
      user_id = current_scope.user.id
      user_no_kp = current_scope.user.no_kp

      if is_nil(user_id) && (is_nil(user_no_kp) || user_no_kp == "") do
        []
      else
        # Project IDs where user is manager or developer (DB-level, no unassigned loaded)
        ids_manager_or_developer =
          if is_nil(user_id) do
            []
          else
            Project
            |> where([p], p.project_manager_id == ^user_id or p.developer_id == ^user_id)
            |> select([p], p.id)
            |> Repo.all()
          end

        # Project IDs where user is in approved_project.pembangun_sistem
        ids_via_pembangun =
          if is_binary(user_no_kp) and user_no_kp != "" do
            ap_ids_with_user =
              ApprovedProject
              |> Repo.all()
              |> Enum.filter(fn ap ->
                ap.pembangun_sistem && user_no_kp in parse_pembangun_sistem(ap.pembangun_sistem)
              end)
              |> Enum.map(& &1.id)

            if ap_ids_with_user == [] do
              []
            else
              Project
              |> where([p], p.approved_project_id in ^ap_ids_with_user)
              |> select([p], p.id)
              |> Repo.all()
            end
          else
            []
          end

        all_ids = (ids_manager_or_developer ++ ids_via_pembangun) |> Enum.uniq()

        if all_ids == [] do
          []
        else
          # Hanya projek dari admin (ada approved_project_id) dipaparkan
          Project
          |> where([p], p.id in ^all_ids and not is_nil(p.approved_project_id))
          |> preload([:developer, :project_manager, :approved_project])
          |> order_by([p], desc: p.last_updated)
          |> Repo.all()
          |> Enum.map(&format_project_for_display/1)
        end
      end
    end
  end

  @doc """
  Returns the list of projects for a pembangun sistem (developer).
  Returns projects where the developer is assigned, i.e.:
  - project.developer_id is the current user, OR
  - project has an approved_project and the developer's no_kp is in approved_project.pembangun_sistem.
  """
  def list_projects_for_pembangun_sistem(current_scope) do
    user_id = current_scope.user && current_scope.user.id
    user_no_kp = current_scope.user && current_scope.user.no_kp

    if is_nil(user_id) && (is_nil(user_no_kp) || user_no_kp == "") do
      []
    else
      Project
      |> where([p], not is_nil(p.approved_project_id))
      |> preload([:developer, :project_manager, :approved_project])
      |> order_by([p], desc: p.last_updated)
      |> Repo.all()
      |> Enum.filter(fn project ->
        assigned_as_developer = not is_nil(user_id) and project.developer_id == user_id
        assigned_via_pembangun_sistem = has_access_to_project?(project, user_no_kp)
        assigned_as_developer or assigned_via_pembangun_sistem
      end)
      |> Enum.map(&format_project_for_display/1)
    end
  end

  @doc """
  Checks if a developer (by no_kp) has access to a project.
  Access is granted if the developer's no_kp is in the approved_project's pembangun_sistem list.
  """
  def has_access_to_project?(project, developer_no_kp) when is_binary(developer_no_kp) do
    approved_project = project.approved_project

    if approved_project && approved_project.pembangun_sistem do
      # Parse the comma-separated list of no_kp values
      selected_no_kps = parse_pembangun_sistem(approved_project.pembangun_sistem)
      developer_no_kp in selected_no_kps
    else
      # If no approved_project or no pembangun_sistem selected, no access
      false
    end
  end

  def has_access_to_project?(_project, _developer_no_kp), do: false

  # Parse comma-separated pembangun_sistem string into list of no_kp values
  defp parse_pembangun_sistem(nil), do: []
  defp parse_pembangun_sistem(""), do: []

  defp parse_pembangun_sistem(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_pembangun_sistem(_), do: []

  @doc """
  Formats project data for display in senarai projek.
  Data diutamakan dari projek dalaman; jika kosong, guna data dari approved_project (DB approved projects).
  """
  def format_project_for_display(project) do
    ap = project.approved_project

    %{
      id: project.id,
      nama: coalesce(project.nama, ap && ap.nama_projek),
      jabatan: coalesce(project.jabatan, ap && ap.jabatan),
      status: project.status,
      fasa: project.fasa,
      tarikh_mula: project.tarikh_mula || (ap && ap.tarikh_mula),
      tarikh_siap: project.tarikh_siap || (ap && ap.tarikh_jangkaan_siap),
      pengurus_projek:
        get_user_display_name(project.project_manager) || (ap && ap.pengurus_email),
      pembangun_sistem: coalesce_pembangun(project.developer, ap && ap.pembangun_sistem),
      developer_id: project.developer_id,
      project_manager_id: project.project_manager_id,
      dokumen_sokongan:
        cond do
          ap &&
            Map.has_key?(ap, :kertas_kerja_path) &&
            ap.kertas_kerja_path &&
              ap.kertas_kerja_path != "" ->
            1

          true ->
            project.dokumen_sokongan || 0
        end
    }
  end

  defp coalesce(a, _b) when is_binary(a) and a != "", do: a
  defp coalesce(_a, b), do: b

  defp coalesce_pembangun(%{} = developer, _), do: get_user_display_name(developer)

  defp coalesce_pembangun(nil, ap_pembangun) when is_binary(ap_pembangun) and ap_pembangun != "",
    do: ap_pembangun

  defp coalesce_pembangun(nil, _), do: nil

  defp get_user_display_name(nil), do: nil

  defp get_user_display_name(user) do
    # Try to get name from email or no_kp
    cond do
      user.email && user.email != "" -> user.email
      user.no_kp && user.no_kp != "" -> user.no_kp
      true -> "N/A"
    end
  end

  @doc """
  Returns the list of recent activities (latest projects) for the current scope.
  Only includes projects with status "Dalam Pembangunan" or "Selesai".
  Project set is role-based (same as get_dashboard_stats).
  """
  def list_recent_activities(current_scope, limit \\ 10) do
    Project
    |> where([p], p.user_id == ^current_scope.user.id)
    |> where([p], p.status == "Dalam Pembangunan" or p.status == "Selesai")
    |> preload([:developer, :project_manager, :user, :approved_project])
    |> order_by([p], desc: p.last_updated)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Gets dashboard statistics for a user scope.
  Counts reflect projects the user can see based on role:
  - ketua penolong pengarah: all projects
  - pengurus projek: projects where user is project manager
  - pembangun sistem: projects where user is developer or in approved_project.pembangun_sistem
  - fallback: projects where user_id is the current user (owner)
  """
  def get_dashboard_stats(current_scope) do
    role = current_scope.user && current_scope.user.role

    case role do
      "ketua penolong pengarah" ->
        get_dashboard_stats_all_projects()

      "pengurus projek" ->
        get_dashboard_stats_by_project_manager(current_scope)

      "pembangun sistem" ->
        get_dashboard_stats_for_pembangun_sistem(current_scope)

      _ ->
        get_dashboard_stats_by_owner(current_scope)
    end
  end

  defp get_dashboard_stats_all_projects do
    result =
      from(p in Project,
        select: %{
          total_projects: count(p.id),
          in_development: filter(count(p.id), p.status == "Dalam Pembangunan"),
          completed: filter(count(p.id), p.status == "Selesai"),
          on_hold: filter(count(p.id), p.status == "Ditangguhkan"),
          uat: filter(count(p.id), p.status == "UAT"),
          change_management: filter(count(p.id), p.status == "Pengurusan Perubahan")
        }
      )
      |> Repo.one()

    map_result(result)
  end

  @doc """
  Returns the list of project IDs visible to the given `current_scope`,
  based on the user's role. Used by activity logging and dashboards to
  filter to only projects the user is allowed to see.
  """
  def visible_project_ids(current_scope) do
    role = current_scope.user && current_scope.user.role

    ids =
      case role do
        "ketua penolong pengarah" ->
          from(p in Project, select: p.id)
          |> Repo.all()

        "pengurus projek" ->
          from(p in Project,
            where: p.project_manager_id == ^current_scope.user.id,
            select: p.id
          )
          |> Repo.all()

        "pembangun sistem" ->
          projects_for_pembangun_sistem(current_scope)
          |> Enum.map(& &1.id)

        _ ->
          from(p in Project,
            where: p.user_id == ^current_scope.user.id,
            select: p.id
          )
          |> Repo.all()
      end

    ids
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp get_dashboard_stats_by_project_manager(current_scope) do
    result =
      from(p in Project,
        where: p.project_manager_id == ^current_scope.user.id,
        select: %{
          total_projects: count(p.id),
          in_development: filter(count(p.id), p.status == "Dalam Pembangunan"),
          completed: filter(count(p.id), p.status == "Selesai"),
          on_hold: filter(count(p.id), p.status == "Ditangguhkan"),
          uat: filter(count(p.id), p.status == "UAT"),
          change_management: filter(count(p.id), p.status == "Pengurusan Perubahan")
        }
      )
      |> Repo.one()

    map_result(result)
  end

  defp get_dashboard_stats_for_pembangun_sistem(current_scope) do
    projects = projects_for_pembangun_sistem(current_scope)

    %{
      total_projects: length(projects),
      in_development: Enum.count(projects, &(&1.status == "Dalam Pembangunan")),
      completed: Enum.count(projects, &(&1.status == "Selesai")),
      on_hold: Enum.count(projects, &(&1.status == "Ditangguhkan")),
      uat: Enum.count(projects, &(&1.status == "UAT")),
      change_management: Enum.count(projects, &(&1.status == "Pengurusan Perubahan"))
    }
  end

  defp get_dashboard_stats_by_owner(current_scope) do
    result =
      from(p in Project,
        where: p.user_id == ^current_scope.user.id,
        select: %{
          total_projects: count(p.id),
          in_development: filter(count(p.id), p.status == "Dalam Pembangunan"),
          completed: filter(count(p.id), p.status == "Selesai"),
          on_hold: filter(count(p.id), p.status == "Ditangguhkan"),
          uat: filter(count(p.id), p.status == "UAT"),
          change_management: filter(count(p.id), p.status == "Pengurusan Perubahan")
        }
      )
      |> Repo.one()

    map_result(result)
  end

  defp map_result(nil),
    do: %{
      total_projects: 0,
      in_development: 0,
      completed: 0,
      on_hold: 0,
      uat: 0,
      change_management: 0
    }

  defp map_result(result) do
    %{
      total_projects: result.total_projects || 0,
      in_development: result.in_development || 0,
      completed: result.completed || 0,
      on_hold: result.on_hold || 0,
      uat: result.uat || 0,
      change_management: result.change_management || 0
    }
  end

  # Returns project structs for pembangun sistem (developer or in approved_project.pembangun_sistem).
  # Used for dashboard stats and recent activities.
  defp projects_for_pembangun_sistem(current_scope) do
    user_id = current_scope.user.id
    user_no_kp = current_scope.user.no_kp

    Project
    |> preload([:developer, :project_manager, :approved_project])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
    |> Enum.filter(fn project ->
      project.developer_id == user_id or has_access_to_project?(project, user_no_kp)
    end)
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.
  """
  def get_project!(id, current_scope) do
    Project
    |> where([p], p.id == ^id and p.user_id == ^current_scope.user.id)
    |> preload([:developer, :project_manager, :approved_project])
    |> Repo.one!()
  end

  @doc """
  Gets a single project by ID without user scope restriction.
  Used for directors/admins who can view all projects.
  """
  def get_project_by_id(id) do
    Project
    |> where([p], p.id == ^id)
    |> preload([:developer, :project_manager, :approved_project])
    |> preload([:developer, :project_manager, :user])
    |> Repo.one()
  end

  @doc """
  Returns a map of project id to project nama for the given list of project IDs.
  Used to display nama sistem (project name) for penempatan rows.
  """
  def get_project_nama_by_ids(ids) when is_list(ids) do
    ids = Enum.uniq(Enum.reject(ids, &is_nil/1))

    if ids == [] do
      %{}
    else
      from(p in Project, where: p.id in ^ids, select: {p.id, p.nama})
      |> Repo.all()
      |> Map.new()
    end
  end

  @doc """
  Creates a project.
  """
  def create_project(attrs, current_scope) do
    case %Project{}
         |> Project.changeset(attrs)
         |> put_change(:user_id, current_scope.user.id)
         |> Repo.insert() do
      {:ok, project} ->
        # If project is linked to an approved project, broadcast update
        if project.approved_project_id do
          approved_project =
            Sppa.ApprovedProjects.get_approved_project!(project.approved_project_id)

          Phoenix.PubSub.broadcast(Sppa.PubSub, "approved_projects", {:updated, approved_project})
        end

        # Log activity for audit / Aktiviti Terkini
        ActivityLogs.log_activity(%{
          actor_id: current_scope.user.id,
          action: "projek_dicipta",
          resource_type: "project",
          resource_id: project.id,
          resource_name: project.nama || "Projek"
        })

        {:ok, project}

      error ->
        error
    end
  end

  @doc """
  Updates only the fasa (phase) field for a project.
  Used to reflect the phase where the developer is currently working (tab navigation).
  When the user has not started any phase, fasa remains nil and the list shows it blank.
  """
  def update_project_fasa(project_id, fasa) when is_integer(project_id) and is_binary(fasa) do
    case get_project_by_id(project_id) do
      nil -> {:error, :not_found}
      project -> update_project(project, %{fasa: fasa})
    end
  end

  def update_project_fasa(_project_id, _fasa), do: {:error, :invalid}

  @doc """
  Updates a project.
  Optionally pass `current_scope` as third argument to record who made the change in the activity log.
  """
  def update_project(%Project{} = project, attrs, current_scope \\ nil) do
    case project
         |> Project.changeset(attrs)
         |> Repo.update() do
      {:ok, updated_project} ->
        # If project is linked to an approved project, broadcast update
        if updated_project.approved_project_id do
          approved_project =
            Sppa.ApprovedProjects.get_approved_project!(updated_project.approved_project_id)

          Phoenix.PubSub.broadcast(Sppa.PubSub, "approved_projects", {:updated, approved_project})
        end

        # Log activity when actor is known
        if current_scope && current_scope.user do
          details = format_update_details(project, attrs)

          ActivityLogs.log_activity(%{
            actor_id: current_scope.user.id,
            action: "projek_dikemaskini",
            resource_type: "project",
            resource_id: updated_project.id,
            resource_name: updated_project.nama || "Projek",
            details: details
          })
        end

        {:ok, updated_project}

      error ->
        error
    end
  end

  defp format_update_details(project, attrs) do
    parts =
      []
      |> maybe_add_change("Status", project.status, attrs["status"])
      |> maybe_add_change("Nama", project.nama, attrs["nama"])
      |> maybe_add_change("Fasa", project.fasa, attrs["fasa"])

    case parts do
      [] -> nil
      list -> Enum.join(list, "; ")
    end
  end

  defp maybe_add_change(acc, _label, _old, nil), do: acc
  defp maybe_add_change(acc, _label, nil, _new), do: acc
  defp maybe_add_change(acc, _label, same, same), do: acc

  defp maybe_add_change(acc, label, old, new) when is_binary(new) or is_number(new),
    do: acc ++ ["#{label}: #{old} → #{new}"]

  defp maybe_add_change(acc, label, _old, new), do: acc ++ ["#{label}: #{inspect(new)}"]

  @doc """
  Deletes a project.
  """
  def delete_project(%Project{} = project) do
    Repo.delete(project)
  end

  @doc """
  Deletes all "dummy" projects: projects that have no approved_project_id
  (i.e. not created from Senarai Projek Diluluskan / admin).
  Returns `{:ok, count}` with the number of projects deleted, or `{:error, reason}`.
  """
  def delete_dummy_projects do
    dummy =
      Project
      |> where([p], is_nil(p.approved_project_id))
      |> Repo.all()

    count = length(dummy)

    case Repo.transaction(fn ->
           Enum.each(dummy, fn project ->
             Repo.delete!(project)
           end)

           count
         end) do
      {:ok, n} -> {:ok, n}
      {:error, _} = err -> err
    end
  end
end
