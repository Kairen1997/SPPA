defmodule SppaWeb.JadualProjekLive do
  use SppaWeb, :live_view

  @allowed_roles ["pengurus projek", "pembangun sistem", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Jadual Projek")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:current_path, "/jadual-projek")

      if connected?(socket) do
        projects = list_projects(socket.assigns.current_scope, user_role)
        gantt_data = prepare_gantt_data(projects)

        month_labels =
          if length(gantt_data.projects) > 0 do
            generate_month_labels(gantt_data.min_date, gantt_data.max_date)
          else
            []
          end

        is_developer = user_role == "pembangun sistem"

        {:ok,
         socket
         |> assign(:projects, projects)
         |> assign(:gantt_data, gantt_data)
         |> assign(:month_labels, month_labels)
         |> assign(:get_status_color, &get_status_color_value/1)
         |> assign(:get_status_badge_class, &get_status_badge_class_value/1)
         |> assign(:is_developer, is_developer)
         |> assign(:show_new_project_modal, false)
         |> assign(:show_edit_project_modal, false)
         |> assign(:selected_project, nil)
         |> assign(:form, to_form(%{}, as: :project))}
      else
        {:ok,
         socket
         |> assign(:projects, [])
         |> assign(:gantt_data, %{projects: []})
         |> assign(:month_labels, [])
         |> assign(:get_status_color, &get_status_color_value/1)
         |> assign(:get_status_badge_class, &get_status_badge_class_value/1)
         |> assign(:is_developer, false)
         |> assign(:show_new_project_modal, false)
         |> assign(:show_edit_project_modal, false)
         |> assign(:selected_project, nil)
         |> assign(:form, to_form(%{}, as: :project))}
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

  # Get projects list - using same mock data structure as ProjekLive
  defp list_projects(current_scope, user_role) do
    _current_user_id = current_scope.user.id

    all_projects = [
      %{
        id: 1,
        nama: "Sistem Pengurusan Projek A",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-01-15],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Ahmad bin Abdullah",
        developer_id: 1,
        project_manager_id: 2,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan"
      },
      %{
        id: 2,
        nama: "Sistem Analisis Data B",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2023-11-01],
        tarikh_siap: ~D[2024-05-15],
        pengurus_projek: "Siti Nurhaliza",
        developer_id: 1,
        project_manager_id: 3,
        isu: "Perlu pembetulan pada modul laporan",
        tindakan: "Selesaikan isu sebelum penyerahan"
      },
      %{
        id: 3,
        nama: "Portal E-Services C",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-06-01],
        tarikh_siap: ~D[2024-01-31],
        pengurus_projek: "Mohd Faizal",
        developer_id: 2,
        project_manager_id: 4,
        isu: "Tiada",
        tindakan: "Projek telah diserahkan"
      },
      %{
        id: 4,
        nama: "Sistem Pengurusan Dokumen D",
        status: "Ditangguhkan",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: ~D[2024-02-01],
        tarikh_siap: ~D[2024-08-31],
        pengurus_projek: "Nurul Aina",
        developer_id: 3,
        project_manager_id: 5,
        isu: "Menunggu kelulusan bajet tambahan",
        tindakan: "Sambung semula selepas kelulusan"
      },
      %{
        id: 5,
        nama: "Aplikasi Mobile E",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-03-01],
        tarikh_siap: ~D[2024-09-30],
        pengurus_projek: "Lim Wei Ming",
        developer_id: 1,
        project_manager_id: 2,
        isu: "Masalah integrasi dengan API",
        tindakan: "Selesaikan integrasi API"
      },
      %{
        id: 6,
        nama: "Sistem Pengurusan Inventori F",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-04-15],
        tarikh_siap: ~D[2024-10-31],
        pengurus_projek: "Ahmad bin Abdullah",
        developer_id: 2,
        project_manager_id: 2,
        isu: "Tiada",
        tindakan: "Teruskan pembangunan modul inventori"
      },
      %{
        id: 7,
        nama: "Portal Pelanggan G",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2023-12-01],
        tarikh_siap: ~D[2024-07-15],
        pengurus_projek: "Siti Nurhaliza",
        developer_id: 2,
        project_manager_id: 3,
        isu: "Isu keselamatan data perlu disemak",
        tindakan: "Lengkapkan audit keselamatan"
      }
    ]

    # Filter based on user role
    case user_role do
      "pembangun sistem" ->
        Enum.filter(all_projects, fn p -> p.developer_id == current_scope.user.id end)
      "pengurus projek" ->
        Enum.filter(all_projects, fn p -> p.project_manager_id == current_scope.user.id end)
      _ ->
        all_projects
    end
  end

  # Prepare data for Gantt chart
  defp prepare_gantt_data(projects) when is_list(projects) and length(projects) == 0 do
    %{projects: [], min_date: Date.utc_today(), max_date: Date.utc_today(), total_days: 0, today_offset: 0, today_percent: 0}
  end

  defp prepare_gantt_data(projects) do
    today = Date.utc_today()

    # Find min and max dates
    dates =
      projects
      |> Enum.flat_map(fn p -> [p.tarikh_mula, p.tarikh_siap] end)
      |> Enum.filter(&(&1 != nil))

    min_date = if Enum.empty?(dates), do: today, else: Enum.min(dates)
    max_date = if Enum.empty?(dates), do: today, else: Enum.max(dates)

    # Expand date range to show more context
    min_date = Date.add(min_date, -30)
    max_date = Date.add(max_date, 30)

    total_days = Date.diff(max_date, min_date)

    projects_with_positions =
      projects
      |> Enum.map(fn project ->
        start_offset = Date.diff(project.tarikh_mula, min_date)
        duration = Date.diff(project.tarikh_siap, project.tarikh_mula)
        progress = calculate_progress(project.tarikh_mula, project.tarikh_siap, project.fasa, project.status, today)

        Map.merge(project, %{
          start_offset: start_offset,
          duration: duration,
          progress: progress,
          start_percent: if(total_days > 0, do: (start_offset / total_days) * 100, else: 0),
          width_percent: if(total_days > 0, do: (duration / total_days) * 100, else: 0)
        })
      end)

    %{
      projects: projects_with_positions,
      min_date: min_date,
      max_date: max_date,
      total_days: total_days,
      today_offset: Date.diff(today, min_date),
      today_percent: if(total_days > 0, do: (Date.diff(today, min_date) / total_days) * 100, else: 0)
    }
  end

  # Calculate progress percentage
  defp calculate_progress(tarikh_mula, tarikh_siap, _fasa, status, today) do
    if status == "Selesai" do
      100
    else
      total_days = Date.diff(tarikh_siap, tarikh_mula)
      elapsed_days = Date.diff(today, tarikh_mula)

      cond do
        total_days <= 0 -> 0
        elapsed_days < 0 -> 0
        elapsed_days >= total_days -> 95
        true -> div(elapsed_days * 100, total_days)
      end
    end
  end


  # Generate month labels for timeline
  defp generate_month_labels(min_date, max_date) do
    current = %Date{year: min_date.year, month: min_date.month, day: 1}
    end_date = %Date{year: max_date.year, month: max_date.month, day: 1}
    total_days = Date.diff(max_date, min_date)

    months = generate_month_labels_recursive(current, end_date, min_date, max_date, total_days, [])
    months
  end

  defp generate_month_labels_recursive(current, end_date, min_date, max_date, total_days, acc) do
    if Date.compare(current, end_date) != :gt do
      month_name = get_month_name(current.month)

      # Calculate days in this month
      days_in_month = Date.days_in_month(current)

      # Calculate width percentage
      width_percent = if total_days > 0, do: (days_in_month / total_days) * 100, else: 0

      month_data = %{
        month: month_name,
        year: current.year,
        width_percent: width_percent
      }

      next_month =
        if current.month == 12 do
          %Date{year: current.year + 1, month: 1, day: 1}
        else
          %Date{year: current.year, month: current.month + 1, day: 1}
        end

      generate_month_labels_recursive(next_month, end_date, min_date, max_date, total_days, acc ++ [month_data])
    else
      acc
    end
  end

  defp get_month_name(month) do
    case month do
      1 -> "Jan"
      2 -> "Feb"
      3 -> "Mac"
      4 -> "Apr"
      5 -> "Mei"
      6 -> "Jun"
      7 -> "Jul"
      8 -> "Ogs"
      9 -> "Sep"
      10 -> "Okt"
      11 -> "Nov"
      12 -> "Dis"
      _ -> "?"
    end
  end

  # Helper functions for template - these need to be public or assigned
  def get_status_color_value(status) do
    case status do
      "Selesai" -> "#10b981"
      "Dalam Pembangunan" -> "#3b82f6"
      "Ujian Penerimaan Pengguna" -> "#8b5cf6"
      "Ditangguhkan" -> "#f59e0b"
      "Pengurusan Perubahan" -> "#ec4899"
      _ -> "#6b7280"
    end
  end

  def get_status_badge_class_value(status) do
    case status do
      "Selesai" -> "bg-green-100 text-green-800"
      "Dalam Pembangunan" -> "bg-blue-100 text-blue-800"
      "Ujian Penerimaan Pengguna" -> "bg-purple-100 text-purple-800"
      "Ditangguhkan" -> "bg-amber-100 text-amber-800"
      "Pengurusan Perubahan" -> "bg-pink-100 text-pink-800"
      _ -> "bg-gray-100 text-gray-800"
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

  # Project CRUD Events
  @impl true
  def handle_event("open_new_project_modal", _params, socket) do
    if socket.assigns.is_developer do
      form = to_form(%{}, as: :project)
      {:noreply, assign(socket, :show_new_project_modal, true) |> assign(:form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_new_project_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_project_modal, false)
     |> assign(:form, to_form(%{}, as: :project))}
  end

  @impl true
  def handle_event("open_edit_project_modal", %{"project_id" => project_id}, socket) do
    if socket.assigns.is_developer do
      project_id = String.to_integer(project_id)
      project = Enum.find(socket.assigns.projects, fn p -> p.id == project_id end)

      if project do
        form_data = %{
          "nama" => project.nama,
          "tarikh_mula" => Calendar.strftime(project.tarikh_mula, "%Y-%m-%d"),
          "tarikh_siap" => Calendar.strftime(project.tarikh_siap, "%Y-%m-%d"),
          "status" => project.status,
          "fasa" => project.fasa,
          "pengurus_projek" => project.pengurus_projek,
          "isu" => project.isu || "",
          "tindakan" => project.tindakan || ""
        }

        form = to_form(form_data, as: :project)

        {:noreply,
         socket
         |> assign(:show_edit_project_modal, true)
         |> assign(:selected_project, project)
         |> assign(:form, form)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_edit_project_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_project_modal, false)
     |> assign(:selected_project, nil)
     |> assign(:form, to_form(%{}, as: :project))}
  end

  @impl true
  def handle_event("validate_project", %{"project" => project_params}, socket) do
    form = to_form(project_params, as: :project)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("save_project", %{"project" => project_params}, socket) do
    if socket.assigns.is_developer do
      # Generate new project ID
      new_id =
        (socket.assigns.projects
         |> Enum.map(fn p -> p.id end)
         |> Enum.max(fn -> 0 end)) + 1

      # Parse dates
      tarikh_mula = parse_date(project_params["tarikh_mula"])
      tarikh_siap = parse_date(project_params["tarikh_siap"])

      new_project = %{
        id: new_id,
        nama: project_params["nama"] || "",
        status: project_params["status"] || "Dalam Pembangunan",
        fasa: project_params["fasa"] || "Soal Selidik",
        tarikh_mula: tarikh_mula,
        tarikh_siap: tarikh_siap,
        pengurus_projek: project_params["pengurus_projek"] || "",
        developer_id: socket.assigns.current_scope.user.id,
        project_manager_id: socket.assigns.current_scope.user.id,
        isu: project_params["isu"] || "Tiada",
        tindakan: project_params["tindakan"] || ""
      }

      updated_projects = socket.assigns.projects ++ [new_project]
      gantt_data = prepare_gantt_data(updated_projects)

      month_labels =
        if length(gantt_data.projects) > 0 do
          generate_month_labels(gantt_data.min_date, gantt_data.max_date)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:projects, updated_projects)
       |> assign(:gantt_data, gantt_data)
       |> assign(:month_labels, month_labels)
       |> assign(:show_new_project_modal, false)
       |> assign(:form, to_form(%{}, as: :project))
       |> put_flash(:info, "Projek berjaya ditambah.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_project", %{"project" => project_params}, socket) do
    if socket.assigns.is_developer && socket.assigns.selected_project do
      project_id = socket.assigns.selected_project.id

      # Parse dates
      tarikh_mula = parse_date(project_params["tarikh_mula"])
      tarikh_siap = parse_date(project_params["tarikh_siap"])

      updated_projects =
        Enum.map(socket.assigns.projects, fn project ->
          if project.id == project_id do
            %{
              project
              | nama: project_params["nama"] || project.nama,
                status: project_params["status"] || project.status,
                fasa: project_params["fasa"] || project.fasa,
                tarikh_mula: tarikh_mula,
                tarikh_siap: tarikh_siap,
                pengurus_projek: project_params["pengurus_projek"] || project.pengurus_projek,
                isu: project_params["isu"] || project.isu,
                tindakan: project_params["tindakan"] || project.tindakan
            }
          else
            project
          end
        end)

      gantt_data = prepare_gantt_data(updated_projects)

      month_labels =
        if length(gantt_data.projects) > 0 do
          generate_month_labels(gantt_data.min_date, gantt_data.max_date)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:projects, updated_projects)
       |> assign(:gantt_data, gantt_data)
       |> assign(:month_labels, month_labels)
       |> assign(:show_edit_project_modal, false)
       |> assign(:selected_project, nil)
       |> assign(:form, to_form(%{}, as: :project))
       |> put_flash(:info, "Projek berjaya dikemaskini.")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_project", %{"project_id" => project_id}, socket) do
    if socket.assigns.is_developer do
      project_id = String.to_integer(project_id)
      updated_projects = Enum.reject(socket.assigns.projects, fn p -> p.id == project_id end)

      gantt_data = prepare_gantt_data(updated_projects)

      month_labels =
        if length(gantt_data.projects) > 0 do
          generate_month_labels(gantt_data.min_date, gantt_data.max_date)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:projects, updated_projects)
       |> assign(:gantt_data, gantt_data)
       |> assign(:month_labels, month_labels)
       |> put_flash(:info, "Projek berjaya dipadam.")}
    else
      {:noreply, socket}
    end
  end

  # Helper function to parse date
  defp parse_date(nil), do: Date.utc_today()
  defp parse_date(""), do: Date.utc_today()

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp parse_date(%Date{} = date), do: date
  defp parse_date(_), do: Date.utc_today()
end
