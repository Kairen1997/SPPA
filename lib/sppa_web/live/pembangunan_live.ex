defmodule SppaWeb.PembangunanLive do
  use SppaWeb, :live_view

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
        |> assign(:page_title, "Pembangunan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:current_path, "/pembangunan")
        |> assign(:modules, modules)

      {:ok, socket}
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
        functions: []
      },
      %{
        id: "module_3",
        number: 3,
        name: "Modul Permohonan",
        priority: "Sangat Tinggi",
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
        functions: []
      }
    ]
  end

  # Helper function to get priority badge classes
  defp get_priority_badge_class(priority) do
    case priority do
      "Sangat Tinggi" -> "bg-red-100 text-red-800 border border-red-200"
      "Tinggi" -> "bg-orange-100 text-orange-800 border border-orange-200"
      "Sederhana" -> "bg-yellow-100 text-yellow-800 border border-yellow-200"
      "Rendah" -> "bg-blue-100 text-blue-800 border border-blue-200"
      _ -> "bg-gray-100 text-gray-800 border border-gray-200"
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
end
