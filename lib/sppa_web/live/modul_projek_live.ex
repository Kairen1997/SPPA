defmodule SppaWeb.ModulProjekLive do
  use SppaWeb, :live_view

  alias Sppa.Accounts

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
        |> assign(:show_new_task_modal, false)
        |> assign(:show_edit_task_modal, false)
        |> assign(:selected_task, nil)
        |> assign(:form, to_form(%{}, as: :task))
        |> assign(:project_id, project_id)

      if connected?(socket) do
        # Get project details
        project = get_project_by_id(project_id, socket.assigns.current_scope)

        if project do
          # Get all users for task assignment
          users = Accounts.list_users()
          developers = Enum.filter(users, fn user -> user.role == "pembangun sistem" end)

          # Get mock tasks filtered by project_id
          tasks = list_tasks(socket.assigns.current_scope, project_id)

          {:ok,
           socket
           |> assign(:project, project)
           |> assign(:tasks, tasks)
           |> assign(:users, users)
           |> assign(:developers, developers)}
        else
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              "Projek tidak ditemui atau anda tidak mempunyai kebenaran untuk mengakses projek ini."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/senarai-projek")

          {:ok, socket}
        end
      else
        {:ok,
         socket
         |> assign(:project, nil)
         |> assign(:tasks, [])
         |> assign(:users, [])
         |> assign(:developers, [])}
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
    {:noreply, update(socket, :notifications_open, &(!&1))}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
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
        "developer_id" => if(task.developer_id, do: Integer.to_string(task.developer_id), else: ""),
        "priority" => task.priority || "medium",
        "status" => task.status || "in_progress",
        "fasa" => task.fasa || "",
        "versi" => task.versi || "",
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
    # Generate new task ID
    new_id =
      if Enum.empty?(socket.assigns.tasks) do
        1
      else
        (socket.assigns.tasks |> Enum.map(& &1.id) |> Enum.max()) + 1
      end

    # Parse developer_id if provided
    developer_id =
      if task_params["developer_id"] && task_params["developer_id"] != "" do
        String.to_integer(task_params["developer_id"])
      else
        nil
      end

    # Get developer name if developer_id is set
    developer_name =
      if developer_id do
        developer = Enum.find(socket.assigns.developers, fn d -> d.id == developer_id end)
        if developer, do: developer.email || developer.no_kp, else: nil
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

    # Create new task
    new_task = %{
      id: new_id,
      title: task_params["title"] || "",
      description: task_params["description"] || "",
      developer_id: developer_id,
      developer_name: developer_name,
      priority: task_params["priority"] || "medium",
      status: task_params["status"] || "in_progress",
      fasa: task_params["fasa"] || "",
      versi: task_params["versi"] || "",
      due_date: due_date,
      created_at: Date.utc_today(),
      project_id: socket.assigns.project_id,
      project_name: socket.assigns.project.nama
    }

    # Add new task to the tasks list
    updated_tasks = [new_task | socket.assigns.tasks]

    {:noreply,
     socket
     |> assign(:tasks, updated_tasks)
     |> assign(:show_new_task_modal, false)
     |> assign(:form, to_form(%{}, as: :task))
     |> put_flash(:info, "Modul baru telah ditambah")}
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

    # Get developer name if developer_id is set
    developer_name =
      if developer_id do
        developer = Enum.find(socket.assigns.developers, fn d -> d.id == developer_id end)
        if developer, do: developer.email || developer.no_kp, else: nil
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

    # Update the task in the list
    updated_tasks =
      Enum.map(socket.assigns.tasks, fn task ->
        if task.id == task_id do
          %{
            task
            | title: task_params["title"] || task.title,
              description: task_params["description"] || task.description,
              developer_id: developer_id,
              developer_name: developer_name,
              priority: task_params["priority"] || task.priority,
              status: task_params["status"] || task.status,
              fasa: task_params["fasa"] || task.fasa,
              versi: task_params["versi"] || task.versi,
              due_date: due_date
          }
        else
          task
        end
      end)

    {:noreply,
     socket
     |> assign(:tasks, updated_tasks)
     |> assign(:show_edit_task_modal, false)
     |> assign(:selected_task, nil)
     |> assign(:form, to_form(%{}, as: :task))
     |> put_flash(:info, "Tugasan telah dikemaskini")}
  end

  @impl true
  def handle_event("delete_task", %{"task_id" => task_id}, socket) do
    task_id = String.to_integer(task_id)
    updated_tasks = Enum.reject(socket.assigns.tasks, fn t -> t.id == task_id end)

    {:noreply,
     socket
     |> assign(:tasks, updated_tasks)
     |> put_flash(:info, "Tugasan telah dipadam")}
  end

  @impl true
  def handle_event("update_task_status", %{"task_id" => task_id} = params, socket) do
    task_id = String.to_integer(task_id)
    # phx-change sends the select value as "status" when name="status"
    status = Map.get(params, "status", "in_progress")

    updated_tasks =
      Enum.map(socket.assigns.tasks, fn task ->
        if task.id == task_id do
          Map.put(task, :status, status)
        else
          task
        end
      end)

    {:noreply,
     socket
     |> assign(:tasks, updated_tasks)
     |> put_flash(:info, "Status tugasan telah dikemaskini")}
  end

  # Get project by ID - will be replaced with database query later
  defp get_project_by_id(project_id, _current_scope) do
    all_projects = [
      %{
        id: 1,
        nama: "Sistem Pengurusan Projek A",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah"
      },
      %{
        id: 2,
        nama: "Sistem Analisis Data B",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah"
      },
      %{
        id: 3,
        nama: "Portal E-Services C",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah"
      },
      %{
        id: 4,
        nama: "Sistem Pengurusan Dokumen D",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah"
      },
      %{
        id: 5,
        nama: "Aplikasi Mobile E",
        jabatan: "Jabatan Perkhidmatan Awam Negeri Sabah"
      }
    ]

    Enum.find(all_projects, fn p -> p.id == project_id end)
  end

  # Mock data function - will be replaced with database queries later
  # Filters tasks by project_id to ensure each project has its own modules
  defp list_tasks(_current_scope, project_id) do
    all_tasks = [
      %{
        id: 1,
        title: "Pengesahan Pengguna",
        description: "Membina sistem log masuk dan pendaftaran pengguna dengan integrasi SM2",
        developer_id: 1,
        developer_name: "Ali bin Hassan",
        priority: "high",
        status: "in_progress",
        fasa: "1",
        versi: "1",
        due_date: ~D[2024-07-15],
        created_at: ~D[2024-06-01],
        project_id: 1,
        project_name: "Sistem Pengurusan Projek A"
      },
      %{
        id: 2,
        title: "Mereka bentuk pangkalan data",
        description: "Mencipta skema pangkalan data untuk modul projek dan tugasan",
        developer_id: 2,
        developer_name: "Ahmad bin Ismail",
        priority: "medium",
        status: "done",
        fasa: "2",
        versi: "1",
        due_date: ~D[2024-07-20],
        created_at: ~D[2024-06-05],
        project_id: 1,
        project_name: "Sistem Pengurusan Projek A"
      },
      %{
        id: 3,
        title: "Membangunkan API untuk senarai projek",
        description: "Mencipta endpoint API untuk mendapatkan dan mengurus senarai projek",
        developer_id: 1,
        developer_name: "Ali bin Hassan",
        priority: "low",
        status: "in_progress",
        fasa: "3",
        versi: "1",
        due_date: ~D[2024-07-25],
        created_at: ~D[2024-06-10],
        project_id: 1,
        project_name: "Sistem Pengurusan Projek A"
      },
      %{
        id: 7,
        title: "Peningkatan Pengesahan Pengguna",
        description: "Menambah peningkatan pada sistem pengesahan pengguna termasuk 2FA dan pengesahan email",
        developer_id: 1,
        developer_name: "Ali bin Hassan",
        priority: "high",
        status: "in_progress",
        fasa: "1",
        versi: "2",
        due_date: ~D[2024-08-15],
        created_at: ~D[2024-07-16],
        project_id: 1,
        project_name: "Sistem Pengurusan Projek A"
      },
      %{
        id: 8,
        title: "Penambahan Fitur Keselamatan",
        description: "Menambah lapisan keselamatan tambahan termasuk rate limiting dan audit logging",
        developer_id: 2,
        developer_name: "Ahmad bin Ismail",
        priority: "high",
        status: "in_progress",
        fasa: "1",
        versi: "3",
        due_date: ~D[2024-09-10],
        created_at: ~D[2024-08-16],
        project_id: 1,
        project_name: "Sistem Pengurusan Projek A"
      }
    ]

    # Filter tasks by project_id - each project has its own modules
    Enum.filter(all_tasks, fn task -> task.project_id == project_id end)
  end

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
end
