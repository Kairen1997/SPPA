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
        |> assign(:profile_menu_open, false)
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
        "developer_id" => if(task.developer_id, do: Integer.to_string(task.developer_id), else: ""),
        "priority" => task.priority || "medium",
        "status" => task.status || "todo",
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
  def handle_event("save_task", %{"task" => _task_params}, socket) do
    # For now, just close the modal since we're not saving to database
    # In the future, task_params will include project_id from the form
    {:noreply,
     socket
     |> assign(:show_new_task_modal, false)
     |> assign(:form, to_form(%{}, as: :task))
     |> put_flash(:info, "Tugasan akan disimpan selepas penambahan medan pangkalan data")}
  end

  @impl true
  def handle_event("update_task", %{"task" => _task_params}, socket) do
    # For now, just close the modal since we're not saving to database
    {:noreply,
     socket
     |> assign(:show_edit_task_modal, false)
     |> assign(:selected_task, nil)
     |> assign(:form, to_form(%{}, as: :task))
     |> put_flash(:info, "Tugasan akan dikemaskini selepas penambahan medan pangkalan data")}
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
    status = Map.get(params, "status", "todo")

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
        title: "Membangunkan modul autentikasi pengguna",
        description: "Membina sistem log masuk dan pendaftaran pengguna dengan integrasi SM2",
        developer_id: 1,
        developer_name: "Ali bin Hassan",
        priority: "high",
        status: "in_progress",
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
        priority: "high",
        status: "todo",
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
        priority: "medium",
        status: "in_progress",
        due_date: ~D[2024-07-25],
        created_at: ~D[2024-06-10],
        project_id: 2,
        project_name: "Sistem Analisis Data B"
      },
      %{
        id: 4,
        title: "Mengintegrasikan sistem notifikasi",
        description: "Menambah sistem notifikasi masa nyata untuk kemaskini projek",
        developer_id: 3,
        developer_name: "Siti Fatimah",
        priority: "low",
        status: "done",
        due_date: ~D[2024-07-10],
        created_at: ~D[2024-06-01],
        project_id: 2,
        project_name: "Sistem Analisis Data B"
      },
      %{
        id: 5,
        title: "Mengoptimumkan prestasi carian",
        description: "Meningkatkan kelajuan carian projek dengan indeks pangkalan data",
        developer_id: 2,
        developer_name: "Ahmad bin Ismail",
        priority: "medium",
        status: "todo",
        due_date: ~D[2024-08-01],
        created_at: ~D[2024-06-15],
        project_id: 3,
        project_name: "Portal E-Services C"
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
  def priority_color("high"), do: "bg-red-100 text-red-800 border-red-200"
  def priority_color("medium"), do: "bg-yellow-100 text-yellow-800 border-yellow-200"
  def priority_color("low"), do: "bg-green-100 text-green-800 border-green-200"
  def priority_color(_), do: "bg-gray-100 text-gray-800 border-gray-200"

  # Helper function to get status color (public for template access)
  def status_color("todo"), do: "bg-gray-100 text-gray-800"
  def status_color("in_progress"), do: "bg-blue-100 text-blue-800"
  def status_color("review"), do: "bg-purple-100 text-purple-800"
  def status_color("done"), do: "bg-green-100 text-green-800"
  def status_color(_), do: "bg-gray-100 text-gray-800"

  # Helper function to get priority label (public for template access)
  def priority_label("high"), do: "Tinggi"
  def priority_label("medium"), do: "Sederhana"
  def priority_label("low"), do: "Rendah"
  def priority_label(_), do: "Sederhana"

  # Helper function to get status label (public for template access)
  def status_label("todo"), do: "Belum Bermula"
  def status_label("in_progress"), do: "Sedang Dijalankan"
  def status_label("review"), do: "Semakan"
  def status_label("done"), do: "Selesai"
  def status_label(_), do: "Belum Bermula"
end
