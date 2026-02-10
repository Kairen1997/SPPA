defmodule SppaWeb.ProjekTabNavigationLive do
  use SppaWeb, :live_view

  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.PermohonanPerubahan
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

        {jadual_gantt_data, jadual_month_labels} = prepare_jadual_data_for_project(project)

        perubahan = PermohonanPerubahan.list_by_project(project_id)
        penempatan = get_penempatan()
        penyerahan = get_penyerahan()
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
         |> assign(:jadual_gantt_data, jadual_gantt_data)
         |> assign(:jadual_month_labels, jadual_month_labels)
         |> assign(:jadual_get_status_color, &jadual_status_color/1)
         |> assign(:jadual_get_status_badge_class, &jadual_status_badge_class/1)
         |> assign(:perubahan, perubahan)
         |> assign(:penempatan, penempatan)
         |> assign(:penyerahan, penyerahan)
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
    id = parse_perubahan_id(perubahan_id)
    perubahan = id && Enum.find(socket.assigns.perubahan, fn p -> p.id == id end)

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
    id = parse_perubahan_id(perubahan_id)
    perubahan = id && Enum.find(socket.assigns.perubahan, fn p -> p.id == id end)

    if perubahan do
      tarikh_dijangka_siap_str =
        if perubahan.tarikh_dijangka_siap do
          Calendar.strftime(perubahan.tarikh_dijangka_siap, "%Y-%m-%d")
        else
          ""
        end

      form_data = %{
        "tajuk" => perubahan.tajuk,
        "jenis" => perubahan.jenis,
        "modul_terlibat" => perubahan.modul_terlibat,
        "tarikh_dibuat" => Calendar.strftime(perubahan.tarikh_dibuat, "%Y-%m-%d"),
        "tarikh_dijangka_siap" => tarikh_dijangka_siap_str,
        "status" => perubahan.status,
        "keutamaan" => perubahan.keutamaan || "",
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
    project_id = socket.assigns.project.id

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
      if perubahan_params["tarikh_dijangka_siap"] && perubahan_params["tarikh_dijangka_siap"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    attrs = %{
      project_id: project_id,
      tajuk: perubahan_params["tajuk"],
      jenis: perubahan_params["jenis"],
      modul_terlibat: perubahan_params["modul_terlibat"],
      tarikh_dibuat: tarikh_dibuat,
      tarikh_dijangka_siap: tarikh_dijangka_siap,
      status: perubahan_params["status"] || "Dalam Semakan",
      keutamaan: empty_to_nil(perubahan_params["keutamaan"]),
      justifikasi: empty_to_nil(perubahan_params["justifikasi"]),
      kesan: empty_to_nil(perubahan_params["kesan"]),
      catatan: empty_to_nil(perubahan_params["catatan"])
    }

    case PermohonanPerubahan.create_permohonan_perubahan(attrs) do
      {:ok, _perubahan} ->
        perubahan = PermohonanPerubahan.list_by_project(project_id)
        {:noreply,
         socket
         |> assign(:perubahan, perubahan)
         |> assign(:show_create_modal, false)
         |> assign(:form, to_form(%{}, as: :perubahan))
         |> put_flash(:info, "Permohonan perubahan berjaya didaftarkan")}

      {:error, changeset} ->
        form = to_form(changeset, as: :perubahan)
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Gagal mendaftar. Sila semak maklumat.")}
    end
  end

  @impl true
  def handle_event("update_perubahan", %{"perubahan" => perubahan_params}, socket) do
    selected = socket.assigns.selected_perubahan
    project_id = socket.assigns.project.id

    tarikh_dibuat =
      if perubahan_params["tarikh_dibuat"] && perubahan_params["tarikh_dibuat"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dibuat"]) do
          {:ok, date} -> date
          _ -> selected.tarikh_dibuat
        end
      else
        selected.tarikh_dibuat
      end

    tarikh_dijangka_siap =
      if perubahan_params["tarikh_dijangka_siap"] && perubahan_params["tarikh_dijangka_siap"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
          {:ok, date} -> date
          _ -> selected.tarikh_dijangka_siap
        end
      else
        nil
      end

    attrs = %{
      tajuk: perubahan_params["tajuk"],
      jenis: perubahan_params["jenis"],
      modul_terlibat: perubahan_params["modul_terlibat"],
      tarikh_dibuat: tarikh_dibuat,
      tarikh_dijangka_siap: tarikh_dijangka_siap,
      status: perubahan_params["status"],
      keutamaan: empty_to_nil(perubahan_params["keutamaan"]),
      justifikasi: empty_to_nil(perubahan_params["justifikasi"]),
      kesan: empty_to_nil(perubahan_params["kesan"]),
      catatan: empty_to_nil(perubahan_params["catatan"])
    }

    case PermohonanPerubahan.update_permohonan_perubahan(selected, attrs) do
      {:ok, _updated} ->
        perubahan = PermohonanPerubahan.list_by_project(project_id)
        {:noreply,
         socket
         |> assign(:perubahan, perubahan)
         |> assign(:show_edit_modal, false)
         |> assign(:selected_perubahan, nil)
         |> assign(:form, to_form(%{}, as: :perubahan))
         |> put_flash(:info, "Perubahan berjaya dikemaskini")}

      {:error, changeset} ->
        form = to_form(changeset, as: :perubahan)
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Gagal mengemaskini. Sila semak maklumat.")}
    end
  end

  defp parse_perubahan_id(perubahan_id) when is_binary(perubahan_id) do
    case Integer.parse(perubahan_id) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp parse_perubahan_id(perubahan_id) when is_integer(perubahan_id), do: perubahan_id
  defp parse_perubahan_id(_), do: nil

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(s) when is_binary(s), do: s
  defp empty_to_nil(other), do: other

  # Penyerahan (delivery) - same data as PenyerahanLive for tab display
  defp get_penyerahan do
    [
      %{
        id: "penyerahan_1",
        number: 1,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.0.0",
        tarikh_penyerahan: ~D[2024-12-20],
        tarikh_dijangka: ~D[2024-12-18],
        status: "Selesai",
        penerima: "Jabatan Teknologi Maklumat",
        pembangun_team: "Team Alpha",
        pengurus_projek: "Siti binti Hassan",
        lokasi: "Pejabat Utama JPKN",
        catatan: "Penyerahan pertama untuk sistem pengurusan permohonan",
        manual_pengguna_bahagian_a: "manual_pengguna_bahagian_a_v1.0.0.pdf",
        surat_akuan_penerimaan: "surat_akuan_penerimaan_v1.0.0.pdf",
        diserahkan_oleh: "Ahmad bin Abdullah",
        diterima_oleh: "Siti binti Hassan",
        tarikh_diserahkan: ~D[2024-12-20],
        tarikh_diterima: ~D[2024-12-20]
      },
      %{
        id: "penyerahan_2",
        number: 2,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.1.0",
        tarikh_penyerahan: ~D[2024-12-25],
        tarikh_dijangka: ~D[2024-12-22],
        status: "Dalam Proses",
        penerima: "Jabatan Teknologi Maklumat",
        pembangun_team: "Team Beta",
        pengurus_projek: "Ahmad bin Abdullah",
        lokasi: "Pejabat Utama JPKN",
        catatan: "Penyerahan untuk versi 1.1.0",
        manual_pengguna_bahagian_a: nil,
        surat_akuan_penerimaan: nil,
        diserahkan_oleh: "Ahmad bin Abdullah",
        diterima_oleh: nil,
        tarikh_diserahkan: ~D[2024-12-25],
        tarikh_diterima: nil
      },
      %{
        id: "penyerahan_3",
        number: 3,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.2.0",
        tarikh_penyerahan: nil,
        tarikh_dijangka: ~D[2024-12-28],
        status: "Menunggu",
        penerima: "Jabatan Teknologi Maklumat",
        pembangun_team: nil,
        pengurus_projek: nil,
        lokasi: "Pejabat Utama JPKN",
        catatan: "Penyerahan untuk versi 1.2.0",
        manual_pengguna_bahagian_a: nil,
        surat_akuan_penerimaan: nil,
        diserahkan_oleh: nil,
        diterima_oleh: nil,
        tarikh_diserahkan: nil,
        tarikh_diterima: nil
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

  # Prepare jadual (Gantt) data for a single project
  defp prepare_jadual_data_for_project(project) do
    today = Date.utc_today()
    tarikh_mula = project.tarikh_mula || today
    tarikh_siap = project.tarikh_siap || today

    projects =
      if project.tarikh_mula && project.tarikh_siap do
        min_date = Date.add(tarikh_mula, -30)
        max_date = Date.add(tarikh_siap, 30)
        total_days = Date.diff(max_date, min_date)

        start_offset = Date.diff(tarikh_mula, min_date)
        duration = Date.diff(tarikh_siap, tarikh_mula)

        progress =
          if project.status == "Selesai" do
            100
          else
            cond do
              duration <= 0 -> 0
              Date.diff(today, tarikh_mula) < 0 -> 0
              Date.diff(today, tarikh_mula) >= duration -> 95
              true -> div(Date.diff(today, tarikh_mula) * 100, duration)
            end
          end

        project_with_positions =
          Map.merge(project, %{
            start_offset: start_offset,
            duration: duration,
            progress: progress,
            start_percent: if(total_days > 0, do: start_offset / total_days * 100, else: 0),
            width_percent: if(total_days > 0, do: duration / total_days * 100, else: 0),
            isu: Map.get(project, :isu, "Tiada"),
            tindakan: Map.get(project, :tindakan, "-")
          })

        gantt_data = %{
          projects: [project_with_positions],
          min_date: min_date,
          max_date: max_date,
          total_days: total_days,
          today_offset: Date.diff(today, min_date),
          today_percent:
            if(total_days > 0, do: Date.diff(today, min_date) / total_days * 100, else: 0)
        }

        month_labels = generate_jadual_month_labels(min_date, max_date)
        {gantt_data, month_labels}
      else
        {%{projects: [], min_date: today, max_date: today, total_days: 0, today_percent: 0}, []}
      end

    projects
  end

  defp generate_jadual_month_labels(min_date, max_date) do
    current = %Date{year: min_date.year, month: min_date.month, day: 1}
    end_date = %Date{year: max_date.year, month: max_date.month, day: 1}
    total_days = Date.diff(max_date, min_date)
    generate_jadual_month_labels_recursive(current, end_date, total_days, [])
  end

  defp generate_jadual_month_labels_recursive(current, end_date, total_days, acc) do
    if Date.compare(current, end_date) != :gt do
      month_name =
        case current.month do
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

      days_in_month = Date.days_in_month(current)
      width_percent = if total_days > 0, do: days_in_month / total_days * 100, else: 0

      month_data = %{month: month_name, year: current.year, width_percent: width_percent}

      next_month =
        if current.month == 12 do
          %Date{year: current.year + 1, month: 1, day: 1}
        else
          %Date{year: current.year, month: current.month + 1, day: 1}
        end

      generate_jadual_month_labels_recursive(
        next_month,
        end_date,
        total_days,
        acc ++ [month_data]
      )
    else
      acc
    end
  end

  defp jadual_status_color(status) do
    case status do
      "Selesai" -> "#10b981"
      "Dalam Pembangunan" -> "#3b82f6"
      "Ujian Penerimaan Pengguna" -> "#8b5cf6"
      "Ditangguhkan" -> "#f59e0b"
      "Pengurusan Perubahan" -> "#ec4899"
      _ -> "#6b7280"
    end
  end

  defp jadual_status_badge_class(status) do
    case status do
      "Selesai" -> "bg-green-100 text-green-800"
      "Dalam Pembangunan" -> "bg-blue-100 text-blue-800"
      "Ujian Penerimaan Pengguna" -> "bg-purple-100 text-purple-800"
      "Ditangguhkan" -> "bg-amber-100 text-amber-800"
      "Pengurusan Perubahan" -> "bg-pink-100 text-pink-800"
      _ -> "bg-gray-100 text-gray-800"
    end
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
          # Developers can only view projects where their no_kp is in the approved_project's pembangun_sistem
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p ->
              user_no_kp = current_scope.user.no_kp
              if Projects.has_access_to_project?(p, user_no_kp), do: p, else: nil
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
