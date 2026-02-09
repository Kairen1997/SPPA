defmodule SppaWeb.ModulProjekLive do
  use SppaWeb, :live_view

  alias Sppa.Accounts
  alias Sppa.ProjectModules
  alias Sppa.Projects

  @impl true
  def mount(%{"project_id" => project_id}, _session, socket) do
    # Verify user is pengurus projek
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      project_id = String.to_integer(project_id)

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Modul Projek - Pengurus Projek")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:show_new_task_modal, false)
        |> assign(:show_edit_task_modal, false)
        |> assign(:selected_task, nil)
        |> assign(:form, to_form(%{}, as: :task))
        |> assign(:project_id, project_id)

      # Always load project + tasks immediately so the page shows the
      # correct data and action buttons even before the LV socket connects.
      project =
        try do
          Projects.get_project!(project_id, socket.assigns.current_scope)
        rescue
          Ecto.NoResultsError -> nil
        end

      if project do
        users = Accounts.list_users()
        developers = Enum.filter(users, fn user -> user.role == "pembangun sistem" end)

        tasks =
          ProjectModules.list_modules_for_project(socket.assigns.current_scope, project_id)

        sorted_tasks = sort_tasks_by_phase_and_version(tasks)

        {:ok,
         socket
         |> assign(:project, project)
         |> assign(:tasks, sorted_tasks)
         |> assign(:users, users)
         |> assign(:developers, developers)}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Projek tidak ditemui atau anda tidak mempunyai kebenaran untuk mengakses projek ini."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/senarai-projek-diluluskan")

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
  def handle_event("open_new_task_modal", _params, socket) do
    # Pre-fill project_id in the form
    form_data = %{"project_id" => Integer.to_string(socket.assigns.project_id)}

    {:noreply,
     socket
     |> assign(:show_new_task_modal, true)
     |> assign(:form, to_form(form_data, as: :task))}
  end

  @impl true
  def handle_event("close_new_task_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_task_modal, false)
     |> assign(:form, to_form(%{}, as: :task))}
  end

  @impl true
  def handle_event("open_edit_task_modal", %{"task_id" => task_id}, socket) do
    task_id = String.to_integer(task_id)
    task = Enum.find(socket.assigns.tasks, fn t -> t.id == task_id end)

    if task do
      form_data = %{
        "title" => task.title,
        "description" => task.description || "",
        "developer_id" =>
          if(task.developer_id, do: Integer.to_string(task.developer_id), else: ""),
        "priority" => task.priority || "medium",
        "status" => task.status || "in_progress",
        "fasa" => task.fasa || "",
        "versi" => task.versi || "",
        "tarikh_mula" => if(task.tarikh_mula, do: Date.to_iso8601(task.tarikh_mula), else: ""),
        "due_date" => if(task.due_date, do: Date.to_iso8601(task.due_date), else: ""),
        "project_id" => Integer.to_string(socket.assigns.project_id)
      }

      {:noreply,
       socket
       |> assign(:show_edit_task_modal, true)
       |> assign(:selected_task, task)
       |> assign(:form, to_form(form_data, as: :task))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_edit_task_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_task_modal, false)
     |> assign(:selected_task, nil)
     |> assign(:form, to_form(%{}, as: :task))}
  end

  @impl true
  def handle_event("validate_task", %{"task" => task_params}, socket) do
    form = to_form(task_params, as: :task)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save_task", %{"task" => task_params}, socket) do
    # Parse developer_id if provided
    developer_id =
      if task_params["developer_id"] && task_params["developer_id"] != "" do
        String.to_integer(task_params["developer_id"])
      else
        nil
      end

    # Parse tarikh_mula if provided
    tarikh_mula =
      if task_params["tarikh_mula"] && task_params["tarikh_mula"] != "" do
        case Date.from_iso8601(task_params["tarikh_mula"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    # Parse due_date if provided
    due_date =
      if task_params["due_date"] && task_params["due_date"] != "" do
        case Date.from_iso8601(task_params["due_date"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    project_start = project_start_date(socket.assigns.project)
    project_end = project_end_date(socket.assigns.project)

    # Validate tarikh_mula
    validation_error =
      cond do
        tarikh_mula && project_start && Date.compare(tarikh_mula, project_start) == :lt ->
          "Tarikh mula tidak boleh sebelum tarikh mula projek (#{Date.to_iso8601(project_start)})."

        tarikh_mula && due_date && Date.compare(tarikh_mula, due_date) == :gt ->
          "Tarikh mula tidak boleh selepas tarikh akhir."

        true ->
          nil
      end

    if validation_error do
      {:noreply,
       socket
       |> put_flash(:error, validation_error)}
    else
      attrs = %{
        "title" => task_params["title"] || "",
        "description" => task_params["description"] || "",
        "developer_id" => developer_id,
        "priority" => task_params["priority"] || "medium",
        "status" => task_params["status"] || "in_progress",
        "fasa" => task_params["fasa"] || "",
        "versi" => task_params["versi"] || "",
        "tarikh_mula" => tarikh_mula,
        "due_date" => due_date,
        "project_id" => socket.assigns.project_id
      }

      case ProjectModules.create_module(attrs) do
        {:ok, _module} ->
          tasks =
            ProjectModules.list_modules_for_project(
              socket.assigns.current_scope,
              socket.assigns.project_id
            )

          sorted_tasks = sort_tasks_by_phase_and_version(tasks)

          socket =
            socket
            |> assign(:tasks, sorted_tasks)
            |> assign(:show_new_task_modal, false)
            |> assign(:form, to_form(%{}, as: :task))
            |> put_flash(:info, "Modul baru telah ditambah")

          socket =
            if project_end && due_date && Date.compare(due_date, project_end) == :gt do
              put_flash(
                socket,
                :error,
                "Tarikh tugasan melebihi tarikh jangkaan siap projek. Sila semak semula jadual."
              )
            else
              socket
            end

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal menyimpan modul. Sila cuba lagi.")}
      end
    end
  end

  @impl true
  def handle_event("update_task", %{"task" => task_params}, socket) do
    task_id = socket.assigns.selected_task.id

    # Parse developer_id if provided
    developer_id =
      if task_params["developer_id"] && task_params["developer_id"] != "" do
        String.to_integer(task_params["developer_id"])
      else
        nil
      end

    # Parse tarikh_mula if provided
    tarikh_mula =
      if task_params["tarikh_mula"] && task_params["tarikh_mula"] != "" do
        case Date.from_iso8601(task_params["tarikh_mula"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    # Parse due_date if provided
    due_date =
      if task_params["due_date"] && task_params["due_date"] != "" do
        case Date.from_iso8601(task_params["due_date"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    project_start = project_start_date(socket.assigns.project)
    project_end = project_end_date(socket.assigns.project)

    # Validate tarikh_mula
    validation_error =
      cond do
        tarikh_mula && project_start && Date.compare(tarikh_mula, project_start) == :lt ->
          "Tarikh mula tidak boleh sebelum tarikh mula projek (#{Date.to_iso8601(project_start)})."

        tarikh_mula && due_date && Date.compare(tarikh_mula, due_date) == :gt ->
          "Tarikh mula tidak boleh selepas tarikh akhir."

        true ->
          nil
      end

    if validation_error do
      {:noreply,
       socket
       |> put_flash(:error, validation_error)}
    else
      attrs = %{
        "title" => task_params["title"] || socket.assigns.selected_task.title,
        "description" => task_params["description"] || socket.assigns.selected_task.description,
        "developer_id" => developer_id,
        "priority" => task_params["priority"] || socket.assigns.selected_task.priority,
        "status" => task_params["status"] || socket.assigns.selected_task.status,
        "fasa" => task_params["fasa"] || socket.assigns.selected_task.fasa,
        "versi" => task_params["versi"] || socket.assigns.selected_task.versi,
        "tarikh_mula" => tarikh_mula,
        "due_date" => due_date
      }

      case ProjectModules.get_module!(task_id) |> ProjectModules.update_module(attrs) do
        {:ok, _module} ->
          tasks =
            ProjectModules.list_modules_for_project(
              socket.assigns.current_scope,
              socket.assigns.project_id
            )

          sorted_tasks = sort_tasks_by_phase_and_version(tasks)

          socket =
            socket
            |> assign(:tasks, sorted_tasks)
            |> assign(:show_edit_task_modal, false)
            |> assign(:selected_task, nil)
            |> assign(:form, to_form(%{}, as: :task))
            |> put_flash(:info, "Tugasan telah dikemaskini")

          socket =
            if project_end && due_date && Date.compare(due_date, project_end) == :gt do
              put_flash(
                socket,
                :error,
                "Tarikh tugasan melebihi tarikh jangkaan siap projek. Sila semak semula jadual."
              )
            else
              socket
            end

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal mengemaskini tugasan. Sila cuba lagi.")}
      end
    end
  end

  @impl true
  def handle_event("delete_task", %{"task_id" => task_id}, socket) do
    task_id = String.to_integer(task_id)

    module = ProjectModules.get_module!(task_id)

    case ProjectModules.delete_module(module) do
      {:ok, _} ->
        tasks =
          ProjectModules.list_modules_for_project(
            socket.assigns.current_scope,
            socket.assigns.project_id
          )

        sorted_tasks = sort_tasks_by_phase_and_version(tasks)

        {:noreply,
         socket
         |> assign(:tasks, sorted_tasks)
         |> put_flash(:info, "Tugasan telah dipadam")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Gagal memadam tugasan. Sila cuba lagi.")}
    end
  end

  @impl true
  def handle_event("update_task_status", %{"task_id" => task_id} = params, socket) do
    task_id = String.to_integer(task_id)
    # phx-change sends the select value as "status" when name="status"
    status = Map.get(params, "status", "in_progress")

    case ProjectModules.get_module!(task_id)
         |> ProjectModules.update_module(%{"status" => status}) do
      {:ok, _module} ->
        tasks =
          ProjectModules.list_modules_for_project(
            socket.assigns.current_scope,
            socket.assigns.project_id
          )

        sorted_tasks = sort_tasks_by_phase_and_version(tasks)

        {:noreply,
         socket
         |> assign(:tasks, sorted_tasks)
         |> put_flash(:info, "Status tugasan telah dikemaskini")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Gagal mengemaskini status tugasan. Sila cuba lagi.")}
    end
  end

  # Sort tasks by phase first, then by version within each phase
  # Ensures sequential ordering: Phase 1 (v1, v2, v3...) -> Phase 2 (v1, v2...) -> Phase 3...
  defp sort_tasks_by_phase_and_version(tasks) do
    Enum.sort_by(tasks, fn task ->
      # Handle cases where fasa/versi might not be numeric strings
      phase_num = parse_numeric(task.fasa)
      version_num = parse_numeric(task.versi)
      {phase_num, version_num}
    end)
  end

  # Safely parse numeric string to integer, defaulting to 0 if not numeric
  defp parse_numeric(value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_numeric(value) when is_integer(value), do: value
  defp parse_numeric(_), do: 0

  # Helper function to get tasks by status (public for template access)
  def tasks_by_status(tasks, status) do
    Enum.filter(tasks, fn task -> task.status == status end)
  end

  # Helper function to get priority color (public for template access)
  # Matching image: reddish-orange for "Tinggi", yellow-orange for "Sederhana", pink/magenta for "Rendah"
  def priority_color("high"), do: "bg-orange-100 text-orange-800 border-orange-200"
  def priority_color("medium"), do: "bg-amber-100 text-amber-800 border-amber-200"
  def priority_color("low"), do: "bg-pink-100 text-pink-800 border-pink-200"
  def priority_color(_), do: "bg-gray-100 text-gray-800 border-gray-200"

  # Helper function to get status color (public for template access)
  # Matching image: blue for "Dalam Proses", light green for "Selesai"
  def status_color("in_progress"), do: "bg-blue-100 text-blue-800 border border-blue-200"
  def status_color("done"), do: "bg-green-100 text-green-800 border border-green-200"
  def status_color(_), do: "bg-gray-100 text-gray-800 border border-gray-200"

  # Helper function to get priority label (public for template access)
  def priority_label("high"), do: "Tinggi"
  def priority_label("medium"), do: "Sederhana"
  def priority_label("low"), do: "Rendah"
  def priority_label(_), do: "Sederhana"

  # Helper function to get status label (public for template access)
  # Only "Dalam Proses" and "Selesai" are available
  def status_label("in_progress"), do: "Dalam Proses"
  def status_label("done"), do: "Selesai"
  def status_label(_), do: "Dalam Proses"

  # Derive the project's planned start date, used for validation
  defp project_start_date(project) do
    cond do
      project.tarikh_mula ->
        project.tarikh_mula

      Map.has_key?(project, :approved_project) &&
        project.approved_project &&
        Map.has_key?(project.approved_project, :tarikh_mula) &&
          project.approved_project.tarikh_mula ->
        project.approved_project.tarikh_mula

      true ->
        nil
    end
  end

  # Derive the project's planned end date, used for validation and Gantt warnings
  defp project_end_date(project) do
    cond do
      project.tarikh_siap ->
        project.tarikh_siap

      Map.has_key?(project, :approved_project) &&
        project.approved_project &&
        Map.has_key?(project.approved_project, :tarikh_jangkaan_siap) &&
          project.approved_project.tarikh_jangkaan_siap ->
        project.approved_project.tarikh_jangkaan_siap

      true ->
        nil
    end
  end

  # Helper functions for template access (public)
  def tarikh_mula_min_date(project) do
    project_start = project_start_date(project)
    if project_start, do: Date.to_iso8601(project_start), else: nil
  end

  def tarikh_mula_max_date(due_date) do
    if due_date, do: Date.to_iso8601(due_date), else: nil
  end

  def tarikh_akhir_min_date(tarikh_mula) do
    if tarikh_mula, do: Date.to_iso8601(tarikh_mula), else: nil
  end

  def tarikh_akhir_max_date(project) do
    project_end = project_end_date(project)
    if project_end, do: Date.to_iso8601(project_end), else: nil
  end
end
