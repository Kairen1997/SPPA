defmodule SppaWeb.PengurusanPerubahanLive do
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
      # Get change requests (perubahan)
      perubahan = get_perubahan()

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Pengurusan Perubahan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/pengurusan-perubahan")
        |> assign(:perubahan, perubahan)
        |> assign(:show_view_modal, false)
        |> assign(:show_edit_modal, false)
        |> assign(:show_create_modal, false)
        |> assign(:selected_perubahan, nil)
        |> assign(:form, to_form(%{}, as: :perubahan))

      if connected?(socket) do
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
        notifications_count = length(activities)

        {:ok,
         socket
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        {:ok,
         socket
         |> assign(:activities, [])
         |> assign(:notifications_count, 0)}
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

  # Get change requests (perubahan)
  # TODO: In the future, this should be retrieved from a database or context module
  defp get_perubahan do
    [
      %{
        id: "perubahan_1",
        number: 1,
        tajuk: "Perubahan Modul Pengurusan Pengguna",
        jenis: "Perubahan Fungsian",
        modul_terlibat: "Modul Pengurusan Pengguna",
        tarikh_dibuat: ~D[2024-11-15],
        tarikh_dijangka_siap: ~D[2024-12-15],
        status: "Dalam Semakan",
        keutamaan: "Tinggi",
        justifikasi: "Perlu menambah fungsi pengesahan dua faktor untuk meningkatkan keselamatan",
        kesan: "Akan meningkatkan keselamatan sistem tetapi memerlukan latihan pengguna",
        catatan: "Menunggu kelulusan dari ketua bahagian"
      },
      %{
        id: "perubahan_2",
        number: 2,
        tajuk: "Pembaikan Bug dalam Modul Permohonan",
        jenis: "Pembaikan Bug",
        modul_terlibat: "Modul Permohonan",
        tarikh_dibuat: ~D[2024-11-20],
        tarikh_dijangka_siap: ~D[2024-11-30],
        status: "Diluluskan",
        keutamaan: "Sangat Tinggi",
        justifikasi: "Bug menyebabkan data permohonan tidak disimpan dengan betul",
        kesan: "Akan membetulkan masalah kritikal yang menghalang pengguna menyimpan permohonan",
        catatan: "Perlu diselesaikan segera"
      },
      %{
        id: "perubahan_3",
        number: 3,
        tajuk: "Penambahbaikan Antara Muka Pengguna",
        jenis: "Penambahbaikan",
        modul_terlibat: "Modul Dashboard",
        tarikh_dibuat: ~D[2024-11-25],
        tarikh_dijangka_siap: ~D[2025-01-15],
        status: "Ditolak",
        keutamaan: "Rendah",
        justifikasi: "Meningkatkan pengalaman pengguna dengan reka bentuk yang lebih moden",
        kesan: "Akan meningkatkan kepuasan pengguna tetapi memerlukan masa pembangunan yang panjang",
        catatan: "Ditangguhkan ke fasa seterusnya"
      },
      %{
        id: "perubahan_4",
        number: 4,
        tajuk: "Integrasi dengan Sistem Luar",
        jenis: "Perubahan Fungsian",
        modul_terlibat: "Modul Laporan",
        tarikh_dibuat: ~D[2024-12-01],
        tarikh_dijangka_siap: ~D[2025-02-28],
        status: "Dalam Semakan",
        keutamaan: "Sederhana",
        justifikasi: "Perlu integrasi dengan sistem e-Sabah untuk pertukaran data",
        kesan: "Akan memudahkan pertukaran data tetapi memerlukan koordinasi dengan pihak lain",
        catatan: "Menunggu maklumbalas dari pihak e-Sabah"
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
  def handle_event("open_view_modal", %{"perubahan_id" => perubahan_id}, socket) do
    perubahan = Enum.find(socket.assigns.perubahan, fn p -> p.id == perubahan_id end)

    if perubahan do
      {:noreply,
       socket
       |> assign(:show_view_modal, true)
       |> assign(:selected_perubahan, perubahan)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_view_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_view_modal, false)
     |> assign(:selected_perubahan, nil)}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    form = to_form(%{}, as: :perubahan)

    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:form, to_form(%{}, as: :perubahan))}
  end

  @impl true
  def handle_event("open_edit_modal", %{"perubahan_id" => perubahan_id}, socket) do
    perubahan = Enum.find(socket.assigns.perubahan, fn p -> p.id == perubahan_id end)

    if perubahan do
      form_data = %{
        "tajuk" => perubahan.tajuk,
        "jenis" => perubahan.jenis,
        "modul_terlibat" => perubahan.modul_terlibat,
        "tarikh_dibuat" => Calendar.strftime(perubahan.tarikh_dibuat, "%Y-%m-%d"),
        "tarikh_dijangka_siap" => Calendar.strftime(perubahan.tarikh_dijangka_siap, "%Y-%m-%d"),
        "status" => perubahan.status,
        "keutamaan" => perubahan.keutamaan,
        "justifikasi" => perubahan.justifikasi || "",
        "kesan" => perubahan.kesan || "",
        "catatan" => perubahan.catatan || ""
      }

      form = to_form(form_data, as: :perubahan)

      {:noreply,
       socket
       |> assign(:show_view_modal, false)
       |> assign(:show_edit_modal, true)
       |> assign(:selected_perubahan, perubahan)
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
     |> assign(:selected_perubahan, nil)
     |> assign(:form, to_form(%{}, as: :perubahan))}
  end

  @impl true
  def handle_event("validate_perubahan", %{"perubahan" => perubahan_params}, socket) do
    form = to_form(perubahan_params, as: :perubahan)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("create_perubahan", %{"perubahan" => perubahan_params}, socket) do
    # TODO: In the future, this should save to the database
    new_id = "perubahan_#{length(socket.assigns.perubahan) + 1}"
    new_number = length(socket.assigns.perubahan) + 1

    tarikh_dibuat =
      if perubahan_params["tarikh_dibuat"] && perubahan_params["tarikh_dibuat"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dibuat"]) do
          {:ok, date} -> date
          _ -> Date.utc_today()
        end
      else
        Date.utc_today()
      end

    tarikh_dijangka_siap =
      case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
        {:ok, date} -> date
        _ -> Date.utc_today()
      end

    new_perubahan = %{
      id: new_id,
      number: new_number,
      tajuk: perubahan_params["tajuk"],
      jenis: perubahan_params["jenis"],
      modul_terlibat: perubahan_params["modul_terlibat"],
      tarikh_dibuat: tarikh_dibuat,
      tarikh_dijangka_siap: tarikh_dijangka_siap,
      status: perubahan_params["status"] || "Dalam Semakan",
      keutamaan: perubahan_params["keutamaan"],
      justifikasi: if(perubahan_params["justifikasi"] == "", do: nil, else: perubahan_params["justifikasi"]),
      kesan: if(perubahan_params["kesan"] == "", do: nil, else: perubahan_params["kesan"]),
      catatan: if(perubahan_params["catatan"] == "", do: nil, else: perubahan_params["catatan"])
    }

    updated_perubahan = [new_perubahan | socket.assigns.perubahan]

    {:noreply,
     socket
     |> assign(:perubahan, updated_perubahan)
     |> assign(:show_create_modal, false)
     |> assign(:form, to_form(%{}, as: :perubahan))
     |> put_flash(:info, "Permohonan perubahan berjaya didaftarkan")}
  end

  @impl true
  def handle_event("update_perubahan", %{"perubahan" => perubahan_params}, socket) do
    # TODO: In the future, this should update the database
    perubahan_id = socket.assigns.selected_perubahan.id

    updated_perubahan =
      Enum.map(socket.assigns.perubahan, fn perubahan ->
        if perubahan.id == perubahan_id do
          tarikh_dibuat =
            if perubahan_params["tarikh_dibuat"] && perubahan_params["tarikh_dibuat"] != "" do
              case Date.from_iso8601(perubahan_params["tarikh_dibuat"]) do
                {:ok, date} -> date
                _ -> perubahan.tarikh_dibuat
              end
            else
              perubahan.tarikh_dibuat
            end

          tarikh_dijangka_siap =
            case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
              {:ok, date} -> date
              _ -> perubahan.tarikh_dijangka_siap
            end

          %{
            perubahan
            | tajuk: perubahan_params["tajuk"],
              jenis: perubahan_params["jenis"],
              modul_terlibat: perubahan_params["modul_terlibat"],
              tarikh_dibuat: tarikh_dibuat,
              tarikh_dijangka_siap: tarikh_dijangka_siap,
              status: perubahan_params["status"],
              keutamaan: perubahan_params["keutamaan"],
              justifikasi:
                if(perubahan_params["justifikasi"] == "", do: nil, else: perubahan_params["justifikasi"]),
              kesan: if(perubahan_params["kesan"] == "", do: nil, else: perubahan_params["kesan"]),
              catatan:
                if(perubahan_params["catatan"] == "", do: nil, else: perubahan_params["catatan"])
          }
        else
          perubahan
        end
      end)

    {:noreply,
     socket
     |> assign(:perubahan, updated_perubahan)
     |> assign(:show_edit_modal, false)
     |> assign(:selected_perubahan, nil)
     |> assign(:form, to_form(%{}, as: :perubahan))
     |> put_flash(:info, "Perubahan berjaya dikemaskini")}
  end
end
