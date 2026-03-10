defmodule Sppa.Projects do
  @moduledoc """
  The Projects context.
  """

  import Ecto.Query, warn: false
  import Ecto.Changeset
  alias Sppa.Repo
  alias Sppa.Accounts
  alias Sppa.Projects.Project
  alias Sppa.ApprovedProjects.ApprovedProject
  alias Sppa.ActivityLogs
  alias Sppa.ApprovedProjects

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

  For pengurus projek:
  - If the project is linked to an approved project and at least one pengurus_projek
    has been set by ketua unit, visibility is based on that assignment list.
  - If the project is not linked to an approved project, falls back to
    project_manager_id (existing behaviour).

  For ketua unit, all projects are visible in lists that use this function.
  """
  def list_projects_for_pengurus_projek(current_scope) do
    role = current_scope.user.role
    user_id = current_scope.user.id
    user_no_kp = current_scope.user.no_kp

    Project
    |> where([p], not is_nil(p.approved_project_id))
    |> preload([:developer, :project_manager, :approved_project])
    |> order_by([p], desc: p.last_updated)
    |> Repo.all()
    |> Enum.filter(fn project ->
      case role do
        "ketua unit" ->
          true

        "pengurus projek" ->
          has_pm_access_to_project?(project, user_id, user_no_kp)

        _other ->
          project.project_manager_id == user_id
      end
    end)
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

  Shows projects from both:
  1. Projects table (internal projects) where user has access
  2. Approved_projects table where user's no_kp is in pembangun_sistem list
     (even if no corresponding project exists in projects table)

  For projects linked to an approved project where pembangun_sistem has been assigned
  (by ketua unit or pengurus projek), visibility is based on that assignment list.

  For projects without an approved project, falls back to developer_id
  (developer's own internal projects).
  """
  def list_projects_for_pembangun_sistem(current_scope) do
    user_id = current_scope.user && current_scope.user.id
    user_no_kp = current_scope.user && current_scope.user.no_kp

    if is_nil(user_id) && (is_nil(user_no_kp) || user_no_kp == "") do
      []
    else
      # 1. Get ALL approved_projects where user's no_kp is in pembangun_sistem
      #    This is the PRIMARY source - shows all assigned approved_projects
      #    (both from projects table and approved_projects table)
      approved_projects_with_access =
        ApprovedProjects.list_approved_projects()
        |> Enum.filter(fn approved_project ->
          # Check if pembangun_sistem is set and contains user's no_kp
          if approved_project.pembangun_sistem && approved_project.pembangun_sistem != "" do
            selected_no_kps = parse_pembangun_sistem(approved_project.pembangun_sistem)
            user_no_kp in selected_no_kps
          else
            false
          end
        end)
        |> Enum.map(fn approved_project ->
          # Ensure a project exists for this approved_project (create if needed)
          case ensure_internal_project_for_approved(approved_project) do
            {:ok, project} ->
              # Update project with data from approved_project if project fields are empty
              # This ensures projects created earlier get populated with approved_project data
              update_attrs = %{}

              update_attrs =
                if project.nama == "" or is_nil(project.nama),
                  do: Map.put(update_attrs, :nama, approved_project.nama_projek || ""),
                  else: update_attrs

              update_attrs =
                if project.jabatan == "" or is_nil(project.jabatan),
                  do: Map.put(update_attrs, :jabatan, approved_project.jabatan || ""),
                  else: update_attrs

              update_attrs =
                if is_nil(project.status),
                  do: Map.put(update_attrs, :status, "Dalam Pembangunan"),
                  else: update_attrs

              update_attrs =
                if is_nil(project.fasa),
                  do: Map.put(update_attrs, :fasa, "Analisis dan Rekabentuk"),
                  else: update_attrs

              update_attrs =
                if is_nil(project.tarikh_mula),
                  do: Map.put(update_attrs, :tarikh_mula, approved_project.tarikh_mula),
                  else: update_attrs

              updated_project =
                if map_size(update_attrs) > 0 do
                  case update_project(project, update_attrs) do
                    {:ok, p} -> p
                    _ -> project
                  end
                else
                  project
                end

              # Reload with approved_project preloaded to ensure fresh data
              Repo.preload(updated_project, :approved_project)

            {:error, _} ->
              # If creation fails, create a virtual project struct for display
              %Project{
                id: nil,
                nama: approved_project.nama_projek || "",
                jabatan: approved_project.jabatan || "",
                status: "Dalam Pembangunan",
                fasa: "Analisis dan Rekabentuk",
                tarikh_mula: approved_project.tarikh_mula,
                tarikh_siap: approved_project.tarikh_jangkaan_siap,
                approved_project_id: approved_project.id,
                approved_project: approved_project,
                developer_id: nil,
                project_manager_id: nil,
                user_id: nil,
                last_updated: approved_project.updated_at || approved_project.inserted_at
              }
          end
        end)

      # 2. Get projects from projects table that don't have approved_project
      #    (fallback for projects without approved_project - user's own internal projects)
      projects_without_approved =
        Project
        |> where([p], is_nil(p.approved_project_id))
        |> where([p], p.developer_id == ^user_id)
        |> preload([:developer, :project_manager, :approved_project])
        |> order_by([p], desc: p.last_updated)
        |> Repo.all()

      # 3. Combine both lists - approved_projects (primary) + projects without approved_project (fallback)
      all_accessible_projects = approved_projects_with_access ++ projects_without_approved

      # Remove duplicates by approved_project.id (if exists) or project.id
      unique_projects =
        all_accessible_projects
        |> Enum.uniq_by(fn project ->
          if project.approved_project do
            project.approved_project.id
          else
            project.id
          end
        end)

      Enum.map(unique_projects, &format_project_for_display/1)
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
      # Format is "no_kp1, no_kp2" (comma space), parse splits by comma and trims
      selected_no_kps = parse_pembangun_sistem(approved_project.pembangun_sistem)
      developer_no_kp in selected_no_kps
    else
      # If no approved_project or no pembangun_sistem selected, no access
      false
    end
  end

  def has_access_to_project?(_project, _developer_no_kp), do: false

  @doc """
  Checks if a pengurus projek has access to a project.

  For projects with an approved_project and a non-empty pengurus_projek list,
  access is granted only when the user's no_kp is in that list.

  For projects without an approved_project, falls back to project_manager_id.
  """
  def has_pm_access_to_project?(project, user_id, user_no_kp)
      when is_integer(user_id) and is_binary(user_no_kp) do
    ap = project.approved_project

    cond do
      ap && ap.pengurus_projek && ap.pengurus_projek != "" ->
        selected_no_kps = parse_pengurus_projek(ap.pengurus_projek)
        user_no_kp in selected_no_kps

      ap == nil ->
        project.project_manager_id == user_id

      true ->
        false
    end
  end

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

  # Parse comma-separated pengurus_projek string into list of no_kp values
  defp parse_pengurus_projek(nil), do: []
  defp parse_pengurus_projek(""), do: []

  defp parse_pengurus_projek(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_pengurus_projek(_), do: []

  @doc """
  Formats project data for display in senarai projek.
  Data diutamakan dari projek dalaman; jika kosong, guna data dari approved_project (DB approved projects).
  Bilangan dokumen diambil daripada database penugasan (approved_projects) sahaja: 1 jika ada kertas_kerja_path, 0 jika tidak.
  """
  def format_project_for_display(project) do
    ap = project.approved_project

    %{
      id: project.id,
      nama: coalesce(project.nama, ap && ap.nama_projek) || "",
      jabatan: coalesce(project.jabatan, ap && ap.jabatan) || "",
      status: project.status || (ap && "Dalam Pembangunan") || "Dalam Pembangunan",
      fasa: project.fasa || (ap && "Analisis dan Rekabentuk") || "Analisis dan Rekabentuk",
      tarikh_mula: project.tarikh_mula || (ap && ap.tarikh_mula),
      tarikh_siap: project.tarikh_siap || (ap && ap.tarikh_jangkaan_siap),
      pengurus_projek:
        get_user_display_name(project.project_manager) || (ap && ap.pengurus_email),
      pembangun_sistem: coalesce_pembangun(project.developer, ap && ap.pembangun_sistem),
      developer_id: project.developer_id,
      project_manager_id: project.project_manager_id,
      # Data dokumen daripada penugasan (approved_projects) sahaja
      dokumen_sokongan: dokumen_count_from_penugasan(ap)
    }
  end

  # Bilangan dokumen dari database penugasan (approved_projects): 1 jika ada kertas_kerja, 0 jika tidak.
  defp dokumen_count_from_penugasan(nil), do: 0

  defp dokumen_count_from_penugasan(ap) do
    if ap.kertas_kerja_path && ap.kertas_kerja_path != "" do
      1
    else
      0
    end
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
  Project set is role-based (same as get_dashboard_stats) via visible_project_ids/1.
  """
  def list_recent_activities(current_scope, limit \\ 10) do
    visible_ids = visible_project_ids(current_scope)

    if visible_ids == [] do
      []
    else
      Project
      |> where([p], p.id in ^visible_ids)
      |> where([p], p.status == "Dalam Pembangunan" or p.status == "Selesai")
      |> preload([:developer, :project_manager, :user, :approved_project])
      |> order_by([p], desc: p.last_updated)
      |> limit(^limit)
      |> Repo.all()
    end
  end

  @doc """
  Returns recently registered projects (linked from external / approved_project),
  latest first, visible to the current scope. Used for dashboard "Aktiviti Terkini".
  For pembangun sistem: includes projects where user is in approved_project.pembangun_sistem or project.developer_id.
  """
  def list_recently_registered_projects(current_scope, limit \\ 20) do
    visible_ids = visible_project_ids(current_scope)
    if visible_ids == [] do
      []
    else
      Project
      |> where([p], p.id in ^visible_ids and not is_nil(p.approved_project_id))
      |> order_by([p], desc: p.inserted_at)
      |> limit(^limit)
      |> preload([:developer, :project_manager, :approved_project])
      |> Repo.all()
    end
  end

  @doc """
  Returns the display string of pengurus projek for an approved project when there is no
  linked internal project. Resolves approved_project.pengurus_projek (no_kp list) to names.
  Used e.g. on Penyerahan page to show lantikan by ketua unit.
  """
  def approved_project_pengurus_display(nil), do: ""
  def approved_project_pengurus_display(%ApprovedProject{} = ap) do
    if ap.pengurus_projek && ap.pengurus_projek != "" do
      no_kps = parse_pengurus_projek(ap.pengurus_projek)
      names =
        Enum.map(no_kps, fn no_kp ->
          case Accounts.get_user_by_no_kp(no_kp) do
            nil -> nil
            user -> user.name || user.email || user.no_kp
          end
        end)
        |> Enum.reject(&is_nil/1)
      if names == [], do: "", else: Enum.join(names, ", ")
    else
      ""
    end
  end

  @doc """
  Returns the display string of pengurus projek for a project (for dashboard Aktiviti Terkini).
  Uses approved_project.pengurus_projek (no_kp list) resolved to names; falls back to project_manager if set.
  """
  def project_pengurus_projek_display(project) do
    ap = project.approved_project
    if ap && ap.pengurus_projek && ap.pengurus_projek != "" do
      no_kps = parse_pengurus_projek(ap.pengurus_projek)
      names =
        Enum.map(no_kps, fn no_kp ->
          case Accounts.get_user_by_no_kp(no_kp) do
            nil -> nil
            user -> user.name || user.email || user.no_kp
          end
        end)
        |> Enum.reject(&is_nil/1)
      if names == [], do: "-", else: Enum.join(names, ", ")
    else
      if project.project_manager do
        project.project_manager.name || project.project_manager.email || project.project_manager.no_kp || "-"
      else
        "-"
      end
    end
  end

  @doc """
  Gets dashboard statistics for a user scope.
  Counts reflect projects the user can see based on role:
  - ketua penolong pengarah: all projects
  - pengurus projek / ketua unit: projects where user is project manager
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

      "ketua unit" ->
        get_dashboard_stats_for_ketua_unit(current_scope)

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
          list_approved_projects_for_pengurus_projek(current_scope)
          |> Enum.flat_map(fn ap ->
            if ap.project && ap.project.id, do: [ap.project.id], else: []
          end)

        "ketua unit" ->
          from(p in Project,
            where: not is_nil(p.approved_project_id),
            select: p.id
          )
          |> Repo.all()

        role when role in ["ketua penolong pengarah (lama)"] ->
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

  @doc """
  Returns project IDs accessible for the Pengaturcaraan page (modul assigned to user).
  - Pengurus projek: projects where they are assigned via approved_project.pengurus_projek.
  - Pembangun sistem: projects where they are developer or in approved_project.pembangun_sistem.
  - Other roles: [] (page is for pengurus projek and pembangun sistem only).
  """
  def list_accessible_project_ids_for_pengaturcaraan(current_scope) do
    role = current_scope.user && current_scope.user.role

    ids =
      case role do
        "pengurus projek" ->
          list_approved_projects_for_pengurus_projek(current_scope)
          |> Enum.flat_map(fn ap ->
            if ap.project && ap.project.id, do: [ap.project.id], else: []
          end)

        "pembangun sistem" ->
          visible_project_ids(current_scope)

        _ ->
          []
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

  defp get_dashboard_stats_for_ketua_unit(_current_scope) do
    # Ketua unit: Jumlah Projek = bilangan projek yang telah diluluskan (ada approved_project_id).
    result =
      from(p in Project,
        where: not is_nil(p.approved_project_id),
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

    base = map_result(result)

    # Dalam Pembangunan: hanya kira projek yang status "Dalam Pembangunan" DAN pengurus telah
    # dilantik (project_manager_id ada ATAU approved_project.pengurus_projek tidak kosong).
    in_dev_count =
      from(p in Project,
        join: ap in assoc(p, :approved_project),
        where: not is_nil(p.approved_project_id),
        where: p.status == "Dalam Pembangunan",
        where: not is_nil(p.project_manager_id) or (not is_nil(ap.pengurus_projek) and ap.pengurus_projek != ""),
        select: count(p.id)
      )
      |> Repo.one()

    Map.put(base, :in_development, in_dev_count || 0)
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
  Gets a single project with access control based on the current scope.

  Raises `Ecto.NoResultsError` if the project does not exist or the user
  does not have access to it.
  """
  def get_project!(id, current_scope) do
    project =
      Project
      |> where([p], p.id == ^id)
      |> preload([:developer, :project_manager, :approved_project, :user])
      |> Repo.one!()

    user = current_scope.user
    role = user.role

    allowed? =
      case role do
        # Directors / senior roles can see all projects
        "ketua penolong pengarah" ->
          true

        # Ketua unit can see all projects (they control assignments)
        "ketua unit" ->
          true

        # Pengurus projek: must be assigned via approved_project.pengurus_projek
        "pengurus projek" ->
          has_pm_access_to_project?(project, user.id, user.no_kp)

        # Pembangun sistem: must be assigned as developer or via pembangun_sistem list
        "pembangun sistem" ->
          project.developer_id == user.id or has_access_to_project?(project, user.no_kp)

        # Fallback: owner-based access
        _ ->
          project.user_id == user.id
      end

    if allowed? do
      project
    else
      raise Ecto.NoResultsError, queryable: Project
    end
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
  Ensures there is an internal project for the given approved project.

  - If a project with `approved_project_id` already exists, returns `{:ok, project}`.
  - Otherwise, creates a new project using data from the approved project.

  This is used by the external sync so every external system automatically
  has a corresponding internal project for Modul/Pelan Modul usage.
  """
  def ensure_internal_project_for_approved(
        %Sppa.ApprovedProjects.ApprovedProject{} = approved_project
      ) do
    existing =
      Project
      |> where([p], p.approved_project_id == ^approved_project.id)
      |> preload([:approved_project, :developer, :project_manager])
      |> Repo.one()

    if existing do
      # Update existing project with data from approved_project if fields are null/empty
      update_attrs = %{}

      update_attrs =
        if existing.nama == "" or is_nil(existing.nama),
          do: Map.put(update_attrs, :nama, approved_project.nama_projek || ""),
          else: update_attrs

      update_attrs =
        if existing.jabatan == "" or is_nil(existing.jabatan),
          do: Map.put(update_attrs, :jabatan, approved_project.jabatan || ""),
          else: update_attrs

      update_attrs =
        if is_nil(existing.status),
          do: Map.put(update_attrs, :status, "Dalam Pembangunan"),
          else: update_attrs

      update_attrs =
        if is_nil(existing.fasa),
          do: Map.put(update_attrs, :fasa, "Analisis dan Rekabentuk"),
          else: update_attrs

      update_attrs =
        if is_nil(existing.tarikh_mula),
          do: Map.put(update_attrs, :tarikh_mula, approved_project.tarikh_mula),
          else: update_attrs

      updated_project =
        if map_size(update_attrs) > 0 do
          case update_project(existing, update_attrs) do
            {:ok, p} -> p
            _ -> existing
          end
        else
          existing
        end

      # Reload to ensure approved_project association is fresh
      {:ok, Repo.preload(updated_project, :approved_project)}
    else
      attrs = %{
        nama: approved_project.nama_projek || "",
        jabatan: approved_project.jabatan || "",
        status: "Dalam Pembangunan",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: approved_project.tarikh_mula,
        approved_project_id: approved_project.id
      }

      case %Project{}
           |> Project.changeset(attrs)
           |> Repo.insert() do
        {:ok, project} ->
          # Reload with approved_project preloaded to ensure association is available
          {:ok, Repo.preload(project, :approved_project)}

        error ->
          error
      end
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
  Returns the list of approved_projects where a pengurus projek is assigned.
  This is the EXACT same logic used by the pengurus projek project list page.
  Returns approved_projects with their associated internal projects loaded.
  """
  def list_approved_projects_for_pengurus_projek(current_scope) do
    user_role = current_scope.user.role
    user_no_kp = current_scope.user.no_kp

    unless user_role == "pengurus projek" do
      []
    else
      base_query =
        from ap in ApprovedProjects.ApprovedProject,
          left_join: p in assoc(ap, :project),
          preload: [project: p]

      approved_projects =
        base_query
        |> order_by([ap, _p], desc: ap.external_updated_at)
        |> Repo.all()

      approved_projects
      |> Enum.filter(fn approved_project ->
        has_pm_assignment_for_approved?(approved_project, user_no_kp)
      end)
      |> Enum.map(fn approved_project ->
        # Ensure internal project exists (same as ensure_project_loaded in project_list_live.ex)
        project =
          case approved_project.project do
            %Project{} = p ->
              p

            _ ->
              case ensure_internal_project_for_approved(approved_project) do
                {:ok, p} -> p
                _ -> nil
              end
          end

        # Return approved_project with project association
        Map.put(approved_project, :project, project)
      end)
    end
  end

  # Helper function to check if a pengurus projek is assigned to an approved project
  defp has_pm_assignment_for_approved?(approved_project, user_no_kp) when is_binary(user_no_kp) do
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

  defp has_pm_assignment_for_approved?(_approved_project, _user_no_kp), do: false

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
