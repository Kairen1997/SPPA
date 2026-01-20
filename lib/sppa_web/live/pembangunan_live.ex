defmodule SppaWeb.PembangunanLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Get modules from Analisis dan Rekabentuk
      modules = get_modules_from_analisis_dan_rekabentuk()

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Pengaturcaraan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/pembangunan")
        |> assign(:modules, modules)
        |> assign(:view_mode, "table")
        |> assign(:show_view_modal, false)
        |> assign(:show_edit_modal, false)
        |> assign(:selected_module, nil)
        |> assign(:form, to_form(%{}, as: :module))
        |> assign(:activities, [])
        |> assign(:notifications_count, 0)

      if connected?(socket) do
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
        notifications_count = length(activities)

        {:ok,
         socket
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
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

  # Get modules that were registered in Analisis dan Rekabentuk page
  # This uses the same initial modules structure as AnalisisDanRekabentukLive
  # TODO: In the future, this should be retrieved from a database or context module
  defp get_modules_from_analisis_dan_rekabentuk do
    [
      %{
        id: "module_1",
        number: 1,
        name: "Modul Pengurusan Pengguna",
        priority: "Tinggi",
        version: "1.0.0",
        status: "Sedang Dibangunkan",
        tarikh_mula: ~D[2024-10-01],
        tarikh_jangka_siap: ~D[2024-12-31],
        catatan: "Pembangunan sedang dijalankan mengikut jadual",
        functions: [
          %{id: "func_1_1", name: "Pendaftaran Pengguna", sub_functions: [%{id: "sub_1_1_1", name: "Pengesahan Pendaftaran"}]},
          %{id: "func_1_2", name: "Laman Log Masuk", sub_functions: []},
          %{id: "func_1_3", name: "Penyelenggaraan Profail", sub_functions: [%{id: "sub_1_3_1", name: "Pengemaskinian Profil"}]}
        ]
      },
      %{
        id: "module_2",
        number: 2,
        name: "Penyelenggaraan Kata Laluan",
        priority: "Tinggi",
        version: "1.0.0",
        status: "Belum Mula",
        tarikh_mula: nil,
        tarikh_jangka_siap: ~D[2025-01-15],
        catatan: nil,
        functions: []
      },
      %{
        id: "module_3",
        number: 3,
        name: "Modul Permohonan",
        priority: "Sangat Tinggi",
        version: "2.1.0",
        status: "Dalam Ujian",
        tarikh_mula: ~D[2024-09-15],
        tarikh_jangka_siap: ~D[2024-12-20],
        catatan: "Sedang menjalani ujian QA, menunggu maklumbalas",
        functions: [
          %{id: "func_3_1", name: "Pendaftaran Permohonan", sub_functions: []},
          %{id: "func_3_2", name: "Kemaskini Permohonan", sub_functions: []},
          %{id: "func_3_3", name: "Semakan Status Permohonan", sub_functions: []}
        ]
      },
      %{
        id: "module_4",
        number: 4,
        name: "Modul Pengurusan Permohonan",
        priority: "Sangat Tinggi",
        version: "2.0.0",
        status: "Selesai",
        tarikh_mula: ~D[2024-08-01],
        tarikh_jangka_siap: ~D[2024-11-30],
        catatan: "Modul telah selesai dan diserahkan untuk deployment",
        functions: [
          %{id: "func_4_1", name: "Verifikasi Permohonan", sub_functions: []},
          %{id: "func_4_2", name: "Kelulusan Permohonan", sub_functions: []}
        ]
      },
      %{
        id: "module_5",
        number: 5,
        name: "Modul Laporan",
        priority: "Sederhana",
        version: "1.5.0",
        status: "Sedang Dibangunkan",
        tarikh_mula: ~D[2024-12-01],
        tarikh_jangka_siap: ~D[2025-02-28],
        catatan: "Perlu integrasi dengan sistem sedia ada",
        functions: [
          %{id: "func_5_1", name: "Laporan mengikut tahun", sub_functions: []},
          %{id: "func_5_2", name: "Laporan mengikut lokasi/daerah", sub_functions: []}
        ]
      },
      %{
        id: "module_6",
        number: 6,
        name: "Modul Dashboard",
        priority: "Rendah",
        version: "1.0.0",
        status: "Belum Mula",
        tarikh_mula: nil,
        tarikh_jangka_siap: ~D[2025-03-15],
        catatan: nil,
        functions: []
      }
    ]
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
  def handle_event("open_view_modal", %{"module_id" => module_id}, socket) do
    module = Enum.find(socket.assigns.modules, fn m -> m.id == module_id end)

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
  def handle_event("open_edit_modal", %{"module_id" => module_id}, socket) do
    module = Enum.find(socket.assigns.modules, fn m -> m.id == module_id end)

    if module do
      form_data = %{
        "name" => module.name,
        "version" => module.version,
        "priority" => module.priority,
        "status" => module.status,
        "tarikh_mula" => if(module.tarikh_mula, do: Calendar.strftime(module.tarikh_mula, "%Y-%m-%d"), else: ""),
        "tarikh_jangka_siap" => Calendar.strftime(module.tarikh_jangka_siap, "%Y-%m-%d"),
        "catatan" => module.catatan || ""
      }

      form = to_form(form_data, as: :module)

      {:noreply,
       socket
       |> assign(:show_view_modal, false)
       |> assign(:show_edit_modal, true)
       |> assign(:selected_module, module)
       |> assign(:form, form)}
    else
      {:noreply, socket}
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
    # TODO: In the future, this should update the database
    # For now, we'll update the in-memory list
    module_id = socket.assigns.selected_module.id

    updated_modules =
      Enum.map(socket.assigns.modules, fn module ->
        if module.id == module_id do
          tarikh_mula =
            if module_params["tarikh_mula"] && module_params["tarikh_mula"] != "" do
              case Date.from_iso8601(module_params["tarikh_mula"]) do
                {:ok, date} -> date
                _ -> module.tarikh_mula
              end
            else
              nil
            end

          tarikh_jangka_siap =
            case Date.from_iso8601(module_params["tarikh_jangka_siap"]) do
              {:ok, date} -> date
              _ -> module.tarikh_jangka_siap
            end

          %{
            module
            | name: module_params["name"],
              version: module_params["version"],
              priority: module_params["priority"],
              status: module_params["status"],
              tarikh_mula: tarikh_mula,
              tarikh_jangka_siap: tarikh_jangka_siap,
              catatan: if(module_params["catatan"] == "", do: nil, else: module_params["catatan"])
          }
        else
          module
        end
      end)

    {:noreply,
     socket
     |> assign(:modules, updated_modules)
     |> assign(:show_edit_modal, false)
     |> assign(:selected_module, nil)
     |> assign(:form, to_form(%{}, as: :module))
     |> put_flash(:info, "Modul berjaya dikemaskini")}
  end
end
