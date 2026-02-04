defmodule SppaWeb.ProjekTabNavigationLive do
  use SppaWeb, :live_view

  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.Projects
  alias Sppa.SoalSelidiks
  alias Sppa.UjianKeselamatan
  alias Sppa.UjianPenerimaanPengguna

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @tab_slug_to_label %{
    "soal-selidik" => "Soal Selidik",
    "analisis-dan-rekabentuk" => "Analisis dan Rekabentuk",
    "jadual-projek" => "Jadual Projek",
    "pengaturcaraan" => "Pengaturcaraan",
    "pengurus-perubahan" => "Pengurus Perubahan",
    "uat" => "UAT",
    "ujian-keselamatan" => "Ujian Keselamatan",
    "penempatan" => "Penempatan",
    "penyerahan" => "Penyerahan",
    "maklumbalas-pelanggan" => "Maklumbalas Pelanggan"
  }

  @impl true
  def mount(params_or_uri, session, socket) do
    params = ensure_params_map(params_or_uri)
    do_mount(params, session, socket)
  end

  defp ensure_params_map(%{} = params), do: params

  defp ensure_params_map(uri_string) when is_binary(uri_string) do
    # Some code paths pass the request URL as the first argument; extract id from path
    case Regex.run(~r{/projek/(\d+)(?:/|$)}, uri_string) do
      [_, id] -> %{"id" => id}
      _ -> %{}
    end
  end

  defp do_mount(%{"id" => id}, _session, socket) when is_binary(id) do
    project_id = String.to_integer(id)

    # Verify user has required role
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Load project
      project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)

      if project do
        # Load soal selidik data for this project
        # Untuk paparan di tab projek, kita mahu tunjukkan apa sahaja
        # soal selidik yang telah diisi untuk projek ini (tidak kira siapa
        # yang mengisi), selagi pengguna yang melihat mempunyai peranan yang
        # dibenarkan untuk projek tersebut.
        #
        # Fungsi context akan cuba:
        # 1. Cari berdasarkan project_id
        # 2. Jika tiada, padankan berdasarkan nama sistem (nama projek) – ini
        #    meliputi rekod lama yang belum mempunyai project_id.
        soal_selidik =
          SoalSelidiks.get_soal_selidik_for_project_or_by_name(
            project,
            socket.assigns.current_scope
          )

        # Debug logging
        require Logger
        Logger.info("=== PROJEK TAB NAVIGATION DEBUG ===")
        Logger.info("Project ID: #{project.id}")
        Logger.info("Project Nama: #{project.nama}")

        soal_selidik_status =
          if soal_selidik do
            "YES - ID: #{soal_selidik.id}"
          else
            "NO"
          end

        Logger.info("Soal Selidik found: #{soal_selidik_status}")

        soal_selidik_pdf_data =
          if soal_selidik do
            data = SoalSelidiks.to_liveview_format(soal_selidik)
            Logger.info("PDF Data prepared: nama_sistem=#{data.nama_sistem}")
            Logger.info("fr_categories count: #{length(data.fr_categories)}")
            Logger.info("nfr_categories count: #{length(data.nfr_categories)}")
            data
          else
            Logger.info("No soal selidik found for project")
            nil
          end

        Logger.info("================================")

        activities =
          if connected?(socket) do
            Projects.list_recent_activities(socket.assigns.current_scope, 10)
          else
            []
          end

        notifications_count = length(activities)

        analisis_pdf_data =
          AnalisisDanRekabentuk.analisis_for_tab_display(project_id, socket.assigns.current_scope)

        modules =
          AnalisisDanRekabentuk.list_modules_for_project(project_id, socket.assigns.current_scope)

        perubahan = get_perubahan()
        penempatan = get_penempatan()
        ujian = UjianPenerimaanPengguna.list_ujian()
        ujian_keselamatan = UjianKeselamatan.list_ujian()

        {:ok,
         socket
         |> assign(:hide_root_header, true)
         |> assign(:page_title, "Butiran Projek")
         |> assign(:sidebar_open, false)
         |> assign(:notifications_open, false)
         |> assign(:profile_menu_open, false)
         |> assign(:project, project)
         |> assign(:soal_selidik_pdf_data, soal_selidik_pdf_data)
         |> assign(:analisis_pdf_data, analisis_pdf_data)
         |> assign(:modules, modules)
         |> assign(:perubahan, perubahan)
         |> assign(:penempatan, penempatan)
         |> assign(:ujian, ujian)
         |> assign(:ujian_keselamatan, ujian_keselamatan)
         |> assign(:show_view_modal, false)
         |> assign(:show_edit_modal, false)
         |> assign(:show_create_modal, false)
         |> assign(:selected_perubahan, nil)
         |> assign(:form, to_form(%{}, as: :perubahan))
         |> assign(:current_tab, "Soal Selidik")
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Projek tidak ditemui atau anda tidak mempunyai kebenaran untuk melihat projek ini."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/projek")

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

  defp do_mount(_params, _session, socket) do
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:error, "Projek tidak ditemui.")
      |> Phoenix.LiveView.redirect(to: ~p"/projek")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    # Phoenix may pass uri as a string; ensure we have (params_map, uri_string)
    {params_map, uri_string} = normalize_params_uri(params, uri)
    current_tab = tab_from_params(params_map, uri_string)

    {:noreply,
     socket
     |> assign(:current_tab, current_tab)
     |> assign(:page_title, "Butiran Projek - #{current_tab}")}
  end

  defp normalize_params_uri(params, uri) when is_map(params) do
    {params, to_string(uri)}
  end

  defp normalize_params_uri(uri, params) when is_binary(uri) and is_map(params) do
    # Some code paths pass (uri, params) instead of (params, uri)
    {params, uri}
  end

  defp tab_from_params(params, uri_string) do
    slug =
      params["tab"] ||
        extract_tab_from_uri(uri_string)

    cond do
      slug && slug != "" ->
        Map.get(@tab_slug_to_label, slug, "Soal Selidik")

      String.ends_with?(uri_string, "/soal-selidik") ->
        "Soal Selidik"

      true ->
        "Soal Selidik"
    end
  end

  defp extract_tab_from_uri(uri_string) when is_binary(uri_string) do
    case URI.parse(uri_string) do
      %{query: nil} -> nil
      %{query: query} -> URI.decode_query(query)["tab"]
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

  # Perubahan (change management) modals and forms
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
      justifikasi:
        if(perubahan_params["justifikasi"] == "", do: nil, else: perubahan_params["justifikasi"]),
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
                if(perubahan_params["justifikasi"] == "",
                  do: nil,
                  else: perubahan_params["justifikasi"]
                ),
              kesan:
                if(perubahan_params["kesan"] == "", do: nil, else: perubahan_params["kesan"]),
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

  # Perubahan (change management) - same data as PengurusanPerubahanLive for tab display
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
        kesan:
          "Akan meningkatkan kepuasan pengguna tetapi memerlukan masa pembangunan yang panjang",
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

  # Penempatan (deployment) - same data as PenempatanLive for tab display
  defp get_penempatan do
    [
      %{
        id: "penempatan_1",
        number: 1,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.0.0",
        lokasi: "Server Produksi - JPKN",
        tarikh_penempatan: ~D[2024-12-15],
        tarikh_dijangka: ~D[2024-12-10],
        status: "Selesai",
        jenis: "Produksi",
        persekitaran: "Produksi",
        url: "https://sppa.jpkn.gov.my",
        catatan: "Penempatan pertama untuk sistem pengurusan permohonan",
        dibina_oleh: "Ahmad bin Abdullah"
      },
      %{
        id: "penempatan_2",
        number: 2,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.1.0",
        lokasi: "Server Staging - JPKN",
        tarikh_penempatan: ~D[2024-12-20],
        tarikh_dijangka: ~D[2024-12-18],
        status: "Dalam Proses",
        jenis: "Staging",
        persekitaran: "Staging",
        url: "https://staging-sppa.jpkn.gov.my",
        catatan: "Penempatan untuk ujian staging sebelum produksi",
        dibina_oleh: "Ahmad bin Abdullah"
      },
      %{
        id: "penempatan_3",
        number: 3,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.2.0",
        lokasi: "Server Development - JPKN",
        tarikh_penempatan: ~D[2024-12-25],
        tarikh_dijangka: ~D[2024-12-22],
        status: "Menunggu",
        jenis: "Development",
        persekitaran: "Development",
        url: "https://dev-sppa.jpkn.gov.my",
        catatan: "Penempatan untuk persekitaran pembangunan",
        dibina_oleh: nil
      }
    ]
  end

  # Get a single project by ID from database
  defp get_project_by_id(project_id, current_scope, user_role) do
    current_user_id = current_scope.user.id

    # Fetch project from database based on user role
    project =
      case user_role do
        "ketua penolong pengarah" ->
          # Directors/Admins can view any project
          Projects.get_project_by_id(project_id)

        "pembangun sistem" ->
          # Developers can only view projects where they are assigned as developer
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.developer_id == current_user_id, do: p, else: nil
          end

        "pengurus projek" ->
          # Project managers can only view projects where they are assigned as project manager
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.project_manager_id == current_user_id, do: p, else: nil
          end

        _ ->
          nil
      end

    # Format project for display if found
    if project do
      project
      |> Projects.format_project_for_display()
    else
      nil
    end
  end
end
