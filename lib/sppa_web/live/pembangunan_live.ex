defmodule SppaWeb.PembangunanLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.ActivityLogs
  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.ModulPengaturcaraan
  alias Sppa.ProjectModules
  alias Sppa.GanttData

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]
  @page_size 10

  @impl true
  def mount(params, _session, socket) do
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      {assigned_modules, gantt_list, use_assigned_tasks, pengaturcaraan_stats} =
        if user_role in ["pembangun sistem", "pengurus projek"] do
          assigned = ProjectModules.list_modules_assigned_to_user(socket.assigns.current_scope)

          gantt_list =
            assigned
            |> Enum.group_by(fn m -> m.project_id end)
            |> Enum.map(fn {_pid, modules} ->
              project = List.first(modules).project
              if project, do: GanttData.build_project_gantt(project, modules), else: nil
            end)
            |> Enum.reject(&is_nil/1)

          stats = %{
            total: length(assigned),
            done: Enum.count(assigned, &(&1.status == "done")),
            in_progress: Enum.count(assigned, &(&1.status == "in_progress")),
            project_count: assigned |> Enum.map(& &1.project_id) |> Enum.uniq() |> length()
          }

          {assigned, gantt_list, true, stats}
        else
          {[], [], false, %{total: 0, done: 0, in_progress: 0, project_count: 0}}
        end

      {modules, project_id} =
        if use_assigned_tasks do
          # Assigned task list is in assigned_modules; no Analisis modules for main list
          {[], nil}
        else
          case params["project_id"] do
            nil ->
              {AnalisisDanRekabentuk.list_modules_for_pembangunan(socket.assigns.current_scope),
               nil}

            id when is_binary(id) ->
              case Integer.parse(id) do
                {pid, ""} ->
                  {AnalisisDanRekabentuk.list_modules_for_project(
                     pid,
                     socket.assigns.current_scope
                   ), pid}

                _ ->
                  {AnalisisDanRekabentuk.list_modules_for_pembangunan(
                     socket.assigns.current_scope
                   ), nil}
              end
          end
        end

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Pengaturcaraan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/pengaturcaraan")
        |> assign(:project_id, project_id)
        |> assign(:modules, modules)
        |> assign(:assigned_modules, assigned_modules)
        |> assign(:gantt_list, gantt_list)
        |> assign(:use_assigned_tasks, use_assigned_tasks)
        |> assign(:pengaturcaraan_stats, pengaturcaraan_stats)
        |> assign(:show_notes_modal, false)
        |> assign(:notes_task, nil)
        |> assign(:notes_form, to_form(%{"text" => ""}, as: :notes))
        |> assign(:page_size, @page_size)
        |> assign(:page, 1)
        |> put_pagination_assigns()
        |> assign(:view_mode, "table")
        |> assign(:show_view_modal, false)
        |> assign(:show_edit_modal, false)
        |> assign(:selected_module, nil)
        |> assign(:form, to_form(%{}, as: :module))
        |> assign(:activities, [])
        |> assign(:notifications_count, 0)

      if connected?(socket) do
        current_scope = socket.assigns.current_scope
        project_activities = Projects.list_recent_activities(current_scope, 10)

        assignment_activities =
          ActivityLogs.list_recent_assignment_activities_for_pembangun_sistem(
            current_scope,
            10
          )

        notification_activities =
          merge_activities_for_notifications(project_activities, assignment_activities, 10)

        {:ok,
         socket
         |> assign(:activities, notification_activities)
         |> assign(:notifications_count, length(notification_activities))}
      else
        {:ok, socket}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "Anda tidak mempunyai kebenaran untuk mengakses halaman ini."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end

  @impl true
  def handle_event("close_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, false)}
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply,
     socket
     |> update(:notifications_open, &(!&1))
     |> assign(:profile_menu_open, false)}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
  end

  @impl true
  def handle_event("toggle_profile_menu", _params, socket) do
    {:noreply,
     socket
     |> update(:profile_menu_open, &(!&1))
     |> assign(:notifications_open, false)}
  end

  @impl true
  def handle_event("close_profile_menu", _params, socket) do
    {:noreply, assign(socket, :profile_menu_open, false)}
  end

  @impl true
  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  @impl true
  def handle_event("go_to_page", %{"page" => page_str}, socket) do
    page =
      case Integer.parse(page_str) do
        {p, ""} -> p
        _ -> socket.assigns.page
      end

    socket =
      socket
      |> assign(:page, page)
      |> put_pagination_assigns()

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_notes_modal", params, socket) do
    # Params may have "task_id" (from phx-value-task_id)
    task_id = params["task_id"] || params["task-id"]

    task =
      if task_id do
        Enum.find(socket.assigns.assigned_modules || [], fn t ->
          to_string(t.id) == to_string(task_id)
        end)
      else
        nil
      end

    if task do
      notes_value = Map.get(task, :notes) || task.notes || ""

      form =
        to_form(%{"text" => notes_value}, as: :notes)

      {:noreply,
       socket
       |> assign(:show_notes_modal, true)
       |> assign(:notes_task, task)
       |> assign(:notes_form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_notes_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_notes_modal, false)
     |> assign(:notes_task, nil)}
  end

  @impl true
  def handle_event("save_notes", params, socket) do
    task = socket.assigns.notes_task
    notes_text = get_in(params, ["notes", "text"]) || ""

    if is_nil(task) do
      {:noreply, socket}
    else
      attrs = %{
        notes: if(notes_text == "", do: nil, else: notes_text)
      }

      case ProjectModules.update_module(task, attrs) do
        {:ok, _updated} ->
          assigned = ProjectModules.list_modules_assigned_to_user(socket.assigns.current_scope)

          gantt_list =
            assigned
            |> Enum.group_by(fn m -> m.project_id end)
            |> Enum.map(fn {_pid, modules} ->
              project = List.first(modules).project
              if project, do: GanttData.build_project_gantt(project, modules), else: nil
            end)
            |> Enum.reject(&is_nil/1)

          stats = %{
            total: length(assigned),
            done: Enum.count(assigned, &(&1.status == "done")),
            in_progress: Enum.count(assigned, &(&1.status == "in_progress")),
            project_count: assigned |> Enum.map(& &1.project_id) |> Enum.uniq() |> length()
          }

          {:noreply,
           socket
           |> assign(:assigned_modules, assigned)
           |> assign(:gantt_list, gantt_list)
           |> assign(:pengaturcaraan_stats, stats)
           |> assign(:show_notes_modal, false)
           |> assign(:notes_task, nil)
           |> assign(:notes_form, to_form(%{"text" => ""}, as: :notes))
           |> put_flash(:info, "Catatan berjaya disimpan.")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal menyimpan catatan. Sila cuba lagi.")}
      end
    end
  end

  @impl true
  def handle_event("open_view_modal", %{"module_id" => module_id}, socket) do
    # Try to find module in full modules list first, then in paginated_modules as fallback
    # Convert both to string for comparison to handle any type mismatches
    module_id_str = to_string(module_id)

    module =
      Enum.find(socket.assigns.modules, fn m -> to_string(m.id) == module_id_str end) ||
        Enum.find(socket.assigns.paginated_modules || [], fn m ->
          to_string(m.id) == module_id_str
        end)

    if module do
      {:noreply,
       socket
       |> assign(:show_view_modal, true)
       |> assign(:selected_module, module)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_view_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_view_modal, false)
     |> assign(:selected_module, nil)}
  end

  @impl true
  def handle_event("open_edit_modal", params, socket) do
    require Logger
    Logger.info("open_edit_modal called with params: #{inspect(params)}")

    module_id = Map.get(params, "module_id")

    if is_nil(module_id) do
      Logger.error("module_id is nil in params: #{inspect(params)}")
      {:noreply, socket |> put_flash(:error, "Module ID tidak ditemui dalam parameter.")}
    else
      # Try to find module in full modules list first, then in paginated_modules as fallback
      # Convert both to string for comparison to handle any type mismatches
      module_id_str = to_string(module_id)

      Logger.info("Looking for module with ID: #{module_id_str}")
      Logger.info("Total modules: #{length(socket.assigns.modules)}")
      Logger.info("Total paginated modules: #{length(socket.assigns.paginated_modules || [])}")

      module =
        Enum.find(socket.assigns.modules, fn m -> to_string(m.id) == module_id_str end) ||
          Enum.find(socket.assigns.paginated_modules || [], fn m ->
            to_string(m.id) == module_id_str
          end)

      Logger.info("Module found: #{inspect(not is_nil(module))}")

      cond do
        is_nil(module) ->
          Logger.error("Module not found for ID: #{inspect(module_id)}")

          {:noreply,
           socket
           |> put_flash(:error, "Modul tidak ditemui. ID: #{inspect(module_id)}")}

        true ->
          form_data = %{
            "priority" => module.priority || "",
            "status" => module.status || "Belum Mula",
            "tarikh_mula" =>
              if(module.tarikh_mula,
                do: Calendar.strftime(module.tarikh_mula, "%Y-%m-%d"),
                else: ""
              ),
            "tarikh_jangka_siap" =>
              if(module.tarikh_jangka_siap,
                do: Calendar.strftime(module.tarikh_jangka_siap, "%Y-%m-%d"),
                else: ""
              ),
            "catatan" => module.catatan || ""
          }

          form = to_form(form_data, as: :module)

          Logger.info("Opening edit modal for module: #{module.name}")

          {:noreply,
           socket
           |> assign(:show_view_modal, false)
           |> assign(:show_edit_modal, true)
           |> assign(:selected_module, module)
           |> assign(:form, form)}
      end
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:selected_module, nil)
     |> assign(:form, to_form(%{}, as: :module))}
  end

  @impl true
  def handle_event("validate_module", %{"module" => module_params}, socket) do
    form = to_form(module_params, as: :module)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("update_module", %{"module" => module_params}, socket) do
    selected = socket.assigns.selected_module
    module_id_str = selected.id
    project_id = selected.project_id

    analisis_module_id =
      case module_id_str do
        "module_" <> id_str -> String.to_integer(id_str)
        _ -> nil
      end

    if is_nil(project_id) or is_nil(analisis_module_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Projek atau modul tidak sah.")
       |> assign(:show_edit_modal, false)
       |> assign(:selected_module, nil)}
    else
      tarikh_mula =
        if module_params["tarikh_mula"] && module_params["tarikh_mula"] != "" do
          case Date.from_iso8601(module_params["tarikh_mula"]) do
            {:ok, date} -> date
            _ -> nil
          end
        else
          nil
        end

      tarikh_jangka_siap =
        if module_params["tarikh_jangka_siap"] && module_params["tarikh_jangka_siap"] != "" do
          case Date.from_iso8601(module_params["tarikh_jangka_siap"]) do
            {:ok, date} -> date
            _ -> nil
          end
        else
          nil
        end

      attrs = %{
        keutamaan: module_params["priority"] || nil,
        status: module_params["status"] || "Belum Mula",
        tarikh_mula: tarikh_mula,
        tarikh_jangka_siap: tarikh_jangka_siap,
        catatan: if(module_params["catatan"] == "", do: nil, else: module_params["catatan"])
      }

      case ModulPengaturcaraan.upsert(project_id, analisis_module_id, attrs) do
        {:ok, _} ->
          modules =
            if socket.assigns.project_id do
              AnalisisDanRekabentuk.list_modules_for_project(
                socket.assigns.project_id,
                socket.assigns.current_scope
              )
            else
              AnalisisDanRekabentuk.list_modules_for_pembangunan(socket.assigns.current_scope)
            end

          {:noreply,
           socket
           |> assign(:modules, modules)
           |> assign(:page, 1)
           |> put_pagination_assigns()
           |> assign(:show_edit_modal, false)
           |> assign(:selected_module, nil)
           |> assign(:form, to_form(%{}, as: :module))
           |> put_flash(:info, "Modul berjaya dikemaskini")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal mengemaskini modul. Sila cuba lagi.")}
      end
    end
  end

  defp put_pagination_assigns(socket) do
    modules = socket.assigns.modules
    page_size = socket.assigns.page_size
    total = length(modules)
    total_pages = if total == 0, do: 1, else: div(total + page_size - 1, page_size)
    page = min(max(socket.assigns.page || 1, 1), total_pages)
    start = (page - 1) * page_size
    paginated = Enum.slice(modules, start, page_size)
    page_numbers = page_numbers_for_pagination(page, total_pages)

    socket
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:total_modules, total)
    |> assign(:paginated_modules, paginated)
    |> assign(:page_numbers, page_numbers)
  end

  defp page_numbers_for_pagination(_current, total_pages) when total_pages <= 7 do
    1..total_pages |> Enum.to_list()
  end

  defp page_numbers_for_pagination(current, total_pages) do
    cond do
      current <= 3 ->
        [1, 2, 3, 4, :ellipsis, total_pages]

      current >= total_pages - 2 ->
        [1, :ellipsis, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, :ellipsis, current - 1, current, current + 1, :ellipsis, total_pages]
    end
  end

  # Helpers for Gantt / assigned tasks (same as PelanModulLive)
  def status_color("in_progress"), do: "bg-blue-100 text-blue-800 border border-blue-200"
  def status_color("done"), do: "bg-green-100 text-green-800 border border-green-200"
  def status_color(_), do: "bg-gray-100 text-gray-800 border border-gray-200"

  def status_label("in_progress"), do: "Dalam Proses"
  def status_label("done"), do: "Selesai"
  def status_label(_), do: "Dalam Proses"

  def priority_color("high"), do: "bg-orange-100 text-orange-800 border-orange-200"
  def priority_color("medium"), do: "bg-amber-100 text-amber-800 border-amber-200"
  def priority_color("low"), do: "bg-pink-100 text-pink-800 border-pink-200"
  def priority_color(_), do: "bg-gray-100 text-gray-800 border-gray-200"

  def priority_label("high"), do: "Tinggi"
  def priority_label("medium"), do: "Sederhana"
  def priority_label("low"), do: "Rendah"
  def priority_label(_), do: "Sederhana"

  def days_between(start_date, end_date) do
    Date.diff(end_date, start_date) + 1
  end

  # Merge project-based activities and assignment activities (pembangun dilantik)
  # for the notification dropdown, sorted by date descending.
  defp merge_activities_for_notifications(project_activities, assignment_activities, limit) do
    project_items =
      Enum.map(project_activities, fn p ->
        sort_at = p.last_updated || Map.get(p, :updated_at) || DateTime.utc_now()
        %{nama: p.nama, status: p.status, last_updated: p.last_updated, sort_at: sort_at}
      end)

    assignment_items =
      Enum.map(assignment_activities, fn a ->
        sort_at = a.inserted_at || DateTime.utc_now()

        %{
          resource_name: a.resource_name,
          action_label: a.action_label,
          details: a.details,
          inserted_at: a.inserted_at,
          sort_at: sort_at
        }
      end)

    (project_items ++ assignment_items)
    |> Enum.sort_by(& &1.sort_at, {:desc, DateTime})
    |> Enum.take(limit)
    |> Enum.map(&Map.delete(&1, :sort_at))
  end
end
