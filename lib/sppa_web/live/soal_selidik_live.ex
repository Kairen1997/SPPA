defmodule SppaWeb.SoalSelidikLive do
  use SppaWeb, :live_view

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  # Functional Requirements Categories
  @fr_categories [
    %{
      key: "pendaftaran_login",
      title: "Pendaftaran & Login",
      questions: [
        %{no: 1, soalan: "Adakah sistem memerlukan pendaftaran pengguna?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 2, soalan: "Apakah kaedah autentikasi yang diperlukan?", type: :checkbox, options: ["Kata laluan", "OTP", "Biometrik", "SSO"]},
        %{no: 3, soalan: "Adakah sistem perlu menyokong pendaftaran sendiri (self-registration)?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 4, soalan: "Berapa lama tempoh sesi pengguna sebelum logout automatik?", type: :text},
        %{no: 5, soalan: "Adakah sistem perlu menyokong reset kata laluan?", type: :select, options: ["Ya", "Tidak"]}
      ]
    },
    %{
      key: "pengurusan_data",
      title: "Pengurusan Data",
      questions: [
        %{no: 1, soalan: "Apakah jenis data utama yang perlu diuruskan?", type: :textarea},
        %{no: 2, soalan: "Adakah sistem perlu menyokong import data pukal?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Apakah format fail yang perlu disokong untuk import?", type: :checkbox, options: ["Excel", "CSV", "JSON", "XML"]},
        %{no: 4, soalan: "Adakah sistem perlu menyokong export data?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 5, soalan: "Berapa lama data perlu disimpan dalam sistem?", type: :text},
        %{no: 6, soalan: "Adakah sistem perlu menyokong backup data automatik?", type: :select, options: ["Ya", "Tidak"]}
      ]
    },
    %{
      key: "proses_kerja",
      title: "Proses Kerja",
      questions: [
        %{no: 1, soalan: "Apakah alur kerja utama yang perlu dilaksanakan?", type: :textarea},
        %{no: 2, soalan: "Adakah sistem perlu menyokong workflow approval?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Berapa peringkat approval yang diperlukan?", type: :text},
        %{no: 4, soalan: "Adakah sistem perlu menyokong notifikasi untuk proses kerja?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 5, soalan: "Apakah kaedah notifikasi yang diperlukan?", type: :checkbox, options: ["Email", "SMS", "Push Notification", "Dalam Sistem"]}
      ]
    },
    %{
      key: "laporan",
      title: "Laporan",
      questions: [
        %{no: 1, soalan: "Apakah jenis laporan yang diperlukan?", type: :textarea},
        %{no: 2, soalan: "Adakah laporan perlu boleh dieksport?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Apakah format eksport yang diperlukan?", type: :checkbox, options: ["PDF", "Excel", "CSV", "Word"]},
        %{no: 4, soalan: "Adakah laporan perlu dijadualkan secara automatik?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 5, soalan: "Berapa kerap laporan perlu dijana?", type: :text}
      ]
    },
    %{
      key: "integrasi",
      title: "Integrasi",
      questions: [
        %{no: 1, soalan: "Adakah sistem perlu berintegrasi dengan sistem lain?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 2, soalan: "Sistem manakah yang perlu diintegrasikan?", type: :textarea},
        %{no: 3, soalan: "Apakah protokol komunikasi yang diperlukan?", type: :checkbox, options: ["REST API", "SOAP", "FTP", "Database"]},
        %{no: 4, soalan: "Adakah integrasi perlu real-time atau batch?", type: :select, options: ["Real-time", "Batch", "Kedua-dua"]},
        %{no: 5, soalan: "Adakah sistem perlu menyokong API untuk sistem luaran?", type: :select, options: ["Ya", "Tidak"]}
      ]
    },
    %{
      key: "role_akses",
      title: "Role & Akses",
      questions: [
        %{no: 1, soalan: "Apakah peranan pengguna yang perlu disokong?", type: :textarea},
        %{no: 2, soalan: "Adakah sistem perlu menyokong role-based access control (RBAC)?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Adakah sistem perlu menyokong permission granular?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 4, soalan: "Adakah sistem perlu menyokong audit log untuk akses?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 5, soalan: "Siapa yang perlu mempunyai akses admin?", type: :text}
      ]
    },
    %{
      key: "peraturan_polisi",
      title: "Peraturan / Polisi",
      questions: [
        %{no: 1, soalan: "Apakah peraturan atau polisi yang perlu dipatuhi?", type: :textarea},
        %{no: 2, soalan: "Adakah sistem perlu mematuhi piawaian keselamatan tertentu?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Adakah sistem perlu mematuhi peraturan privasi data?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 4, soalan: "Apakah piawaian keselamatan yang perlu dipatuhi?", type: :checkbox, options: ["ISO 27001", "PDPA", "ISO 9001", "Lain-lain"]},
        %{no: 5, soalan: "Adakah sistem perlu menyokong compliance reporting?", type: :select, options: ["Ya", "Tidak"]}
      ]
    },
    %{
      key: "lain_lain_ciri",
      title: "Lain-lain Ciri Fungsian",
      questions: [
        %{no: 1, soalan: "Adakah terdapat ciri fungsian tambahan yang diperlukan?", type: :textarea},
        %{no: 2, soalan: "Adakah sistem perlu menyokong multi-bahasa?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Apakah bahasa yang perlu disokong?", type: :checkbox, options: ["Bahasa Melayu", "English", "Bahasa Cina", "Bahasa Tamil"]},
        %{no: 4, soalan: "Adakah sistem perlu menyokong tema gelap/terang?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 5, soalan: "Adakah terdapat keperluan khas lain?", type: :textarea}
      ]
    }
  ]

  # Non-Functional Requirements Categories
  @nfr_categories [
    %{
      key: "keselamatan",
      title: "Keselamatan",
      questions: [
        %{no: 1, soalan: "Apakah tahap keselamatan data yang diperlukan?", type: :select, options: ["Rendah", "Sederhana", "Tinggi", "Sangat Tinggi"]},
        %{no: 2, soalan: "Adakah data perlu dienkripsi?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Apakah jenis enkripsi yang diperlukan?", type: :checkbox, options: ["At Rest", "In Transit", "Kedua-dua"]},
        %{no: 4, soalan: "Adakah sistem perlu menyokong two-factor authentication (2FA)?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 5, soalan: "Adakah sistem perlu menyokong audit trail?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 6, soalan: "Berapa lama audit trail perlu disimpan?", type: :text}
      ]
    },
    %{
      key: "akses_capaian",
      title: "Akses / Capaian",
      questions: [
        %{no: 1, soalan: "Berapa ramai pengguna serentak yang perlu disokong?", type: :text},
        %{no: 2, soalan: "Adakah sistem perlu boleh diakses dari luar pejabat?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Apakah peranti yang perlu disokong?", type: :checkbox, options: ["Desktop", "Laptop", "Tablet", "Mobile"]},
        %{no: 4, soalan: "Apakah pelayar web yang perlu disokong?", type: :checkbox, options: ["Chrome", "Firefox", "Safari", "Edge"]},
        %{no: 5, soalan: "Adakah sistem perlu menyokong akses offline?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 6, soalan: "Apakah kelajuan sambungan internet minimum yang diperlukan?", type: :text}
      ]
    },
    %{
      key: "usability",
      title: "Usability",
      questions: [
        %{no: 1, soalan: "Apakah tahap kemudahan penggunaan yang diperlukan?", type: :select, options: ["Asas", "Sederhana", "Tinggi"]},
        %{no: 2, soalan: "Adakah sistem perlu menyokong panduan pengguna dalam talian?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 3, soalan: "Adakah sistem perlu menyokong tooltip dan bantuan kontekstual?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 4, soalan: "Berapa lama masa latihan yang diperlukan untuk pengguna baru?", type: :text},
        %{no: 5, soalan: "Adakah sistem perlu mematuhi piawaian aksesibiliti?", type: :select, options: ["Ya", "Tidak"]},
        %{no: 6, soalan: "Apakah piawaian aksesibiliti yang perlu dipatuhi?", type: :checkbox, options: ["WCAG 2.1", "Section 508", "Lain-lain"]}
      ]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Initialize default tabs
      default_tabs = [
        %{id: "fr", label: "Functional Requirement", type: :default, removable: false},
        %{id: "nfr", label: "Non-Functional Requirement", type: :default, removable: false},
        %{id: "disediakan_oleh", label: "Disediakan Oleh", type: :default, removable: false}
      ]

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Soal Selidik")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:current_path, "/soal-selidik")
        |> assign(:document_id, "JPKN-BPA-01/B1")
        |> assign(:system_name, "")
        |> assign(:active_tab, "fr")
        |> assign(:tabs, default_tabs)
        |> assign(:fr_categories, @fr_categories)
        |> assign(:nfr_categories, @nfr_categories)
        |> assign(:form, to_form(%{}, as: :soal_selidik))
        |> assign(:show_pdf_modal, false)
        |> assign(:pdf_data, nil)
        |> assign(:show_add_tab_modal, false)
        |> assign(:new_tab_form, to_form(%{}, as: :new_tab))

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
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("show_add_tab_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_tab_modal, true)}
  end

  @impl true
  def handle_event("close_add_tab_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_tab_modal, false)
     |> assign(:new_tab_form, to_form(%{}, as: :new_tab))}
  end

  @impl true
  def handle_event("add_tab", %{"new_tab" => new_tab_params}, socket) do
    label = Map.get(new_tab_params, "label", "") |> String.trim()
    id = Map.get(new_tab_params, "id", "") |> String.trim()

    # Generate ID from label if not provided
    tab_id = if id == "", do: generate_tab_id(label), else: id

    # Validate that label is not empty
    if label == "" do
      form = to_form(new_tab_params, as: :new_tab)
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Label tab tidak boleh kosong.")
       |> assign(:show_add_tab_modal, true)
       |> assign(:new_tab_form, form)}
    else
      # Validate that ID is unique
      existing_ids = Enum.map(socket.assigns.tabs, & &1.id)

      if tab_id in existing_ids do
        form = to_form(new_tab_params, as: :new_tab)
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:error, "ID tab sudah wujud. Sila gunakan ID lain.")
         |> assign(:show_add_tab_modal, true)
         |> assign(:new_tab_form, form)}
      else
        new_tab = %{
          id: tab_id,
          label: label,
          type: :custom,
          removable: true
        }

        updated_tabs = socket.assigns.tabs ++ [new_tab]

        {:noreply,
         socket
         |> assign(:tabs, updated_tabs)
         |> assign(:active_tab, tab_id)
         |> assign(:show_add_tab_modal, false)
         |> assign(:new_tab_form, to_form(%{}, as: :new_tab))
         |> Phoenix.LiveView.put_flash(:info, "Tab baru telah ditambah.")}
      end
    end
  end

  @impl true
  def handle_event("remove_tab", %{"tab_id" => tab_id}, socket) do
    # Prevent removing default tabs
    tab = Enum.find(socket.assigns.tabs, &(&1.id == tab_id))

    if tab && tab.removable do
      updated_tabs = Enum.reject(socket.assigns.tabs, &(&1.id == tab_id))

      # If we removed the active tab, switch to the first tab
      new_active_tab =
        if socket.assigns.active_tab == tab_id do
          case List.first(updated_tabs) do
            nil -> "fr"
            first_tab -> first_tab.id
          end
        else
          socket.assigns.active_tab
        end

      {:noreply,
       socket
       |> assign(:tabs, updated_tabs)
       |> assign(:active_tab, new_active_tab)
       |> Phoenix.LiveView.put_flash(:info, "Tab telah dibuang.")}
    else
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Tab ini tidak boleh dibuang.")}
    end
  end

  @impl true
  def handle_event("validate_new_tab", %{"new_tab" => new_tab_params}, socket) do
    form = to_form(new_tab_params, as: :new_tab)
    {:noreply, assign(socket, :new_tab_form, form)}
  end

  @impl true
  def handle_event("validate", %{"soal_selidik" => params}, socket) do
    form = to_form(params, as: :soal_selidik)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"soal_selidik" => params}, socket) do
    # For now, just show a success message
    # Later, this will save to the database
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:info, "Soal selidik telah disimpan dengan jayanya.")
      |> assign(:form, to_form(params, as: :soal_selidik))

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_pdf", _params, socket) do
    dummy_data = generate_dummy_data_for_pdf()

    {:noreply,
      socket
     |> assign(:show_pdf_modal, true)
     |> assign(:pdf_data, dummy_data)}
  end

  @impl true
  def handle_event("close_pdf_modal", _params, socket) do
    {:noreply,
      socket
     |> assign(:show_pdf_modal, false)
     |> assign(:pdf_data, nil)}
  end

  defp generate_tab_id(label) do
    label
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> then(fn id ->
      # Ensure it's not empty and add prefix if needed
      if id == "", do: "custom_tab_#{System.unique_integer([:positive])}", else: id
    end)
  end

  defp generate_dummy_data_for_pdf do
    %{
      nama_sistem: "Sistem Pengurusan Projek Aplikasi (SPPA)",
      document_id: "JPKN-BPA-01/B1",
      fr_categories: @fr_categories,
      nfr_categories: @nfr_categories,
      fr_data: %{
        pendaftaran_login: %{
          "1" => %{maklumbalas: "Ya", catatan: "Sistem memerlukan pendaftaran pengguna untuk akses terkawal"},
          "2" => %{maklumbalas: ["Kata laluan", "OTP"], catatan: "Menggunakan kata laluan dan OTP untuk keselamatan tambahan"},
          "3" => %{maklumbalas: "Tidak", catatan: "Pendaftaran hanya dilakukan oleh admin"},
          "4" => %{maklumbalas: "30 minit", catatan: "Sesi akan tamat selepas 30 minit tidak aktif"},
          "5" => %{maklumbalas: "Ya", catatan: "Pengguna boleh reset kata laluan melalui email"}
        },
        pengurusan_data: %{
          "1" => %{maklumbalas: "Data projek, pengguna, dokumen, dan laporan", catatan: "Sistem perlu mengurus pelbagai jenis data"},
          "2" => %{maklumbalas: "Ya", catatan: "Import data pukal diperlukan untuk migrasi data"},
          "3" => %{maklumbalas: ["Excel", "CSV"], catatan: "Format Excel dan CSV adalah keutamaan"},
          "4" => %{maklumbalas: "Ya", catatan: "Export data diperlukan untuk backup dan laporan"},
          "5" => %{maklumbalas: "7 tahun", catatan: "Mematuhi keperluan penyimpanan rekod kerajaan"},
          "6" => %{maklumbalas: "Ya", catatan: "Backup harian secara automatik"}
        },
        proses_kerja: %{
          "1" => %{maklumbalas: "Permohonan projek → Kelulusan → Pembangunan → Ujian → Penempatan", catatan: "Alur kerja utama sistem"},
          "2" => %{maklumbalas: "Ya", catatan: "Workflow approval diperlukan untuk kelulusan projek"},
          "3" => %{maklumbalas: "3 peringkat", catatan: "Pengurus Projek → Ketua Penolong Pengarah → Pengarah"},
          "4" => %{maklumbalas: "Ya", catatan: "Notifikasi diperlukan untuk proses kelulusan"},
          "5" => %{maklumbalas: ["Email", "Dalam Sistem"], catatan: "Notifikasi melalui email dan dalam sistem"}
        },
        laporan: %{
          "1" => %{maklumbalas: "Laporan status projek, laporan kemajuan, laporan kewangan, laporan audit", catatan: "Pelbagai jenis laporan diperlukan"},
          "2" => %{maklumbalas: "Ya", catatan: "Semua laporan perlu boleh dieksport"},
          "3" => %{maklumbalas: ["PDF", "Excel"], catatan: "Format PDF dan Excel adalah keutamaan"},
          "4" => %{maklumbalas: "Ya", catatan: "Laporan bulanan perlu dijana secara automatik"},
          "5" => %{maklumbalas: "Bulanan", catatan: "Laporan bulanan untuk pengurusan atasan"}
        },
        integrasi: %{
          "1" => %{maklumbalas: "Ya", catatan: "Perlu berintegrasi dengan sistem sedia ada"},
          "2" => %{maklumbalas: "Sistem HR, Sistem Kewangan, Sistem Email", catatan: "Integrasi dengan sistem utama organisasi"},
          "3" => %{maklumbalas: ["REST API", "Database"], catatan: "Menggunakan REST API dan sambungan database"},
          "4" => %{maklumbalas: "Kedua-dua", catatan: "Real-time untuk data kritikal, batch untuk data besar"},
          "5" => %{maklumbalas: "Ya", catatan: "API diperlukan untuk sistem luaran"}
        },
        role_akses: %{
          "1" => %{maklumbalas: "Admin, Pengurus Projek, Pembangun Sistem, Ketua Penolong Pengarah, Pengarah", catatan: "Pelbagai peranan dengan akses berbeza"},
          "2" => %{maklumbalas: "Ya", catatan: "RBAC diperlukan untuk kawalan akses yang ketat"},
          "3" => %{maklumbalas: "Ya", catatan: "Permission granular untuk fungsi tertentu"},
          "4" => %{maklumbalas: "Ya", catatan: "Audit log untuk keselamatan dan compliance"},
          "5" => %{maklumbalas: "Admin sistem dan Pengarah", catatan: "Akses admin terhad kepada pengguna tertentu"}
        },
        peraturan_polisi: %{
          "1" => %{maklumbalas: "PDPA, Polisi Keselamatan IT, Polisi Pengurusan Data", catatan: "Mematuhi semua peraturan dan polisi organisasi"},
          "2" => %{maklumbalas: "Ya", catatan: "Mematuhi piawaian keselamatan yang ditetapkan"},
          "3" => %{maklumbalas: "Ya", catatan: "Mematuhi PDPA untuk perlindungan data peribadi"},
          "4" => %{maklumbalas: ["ISO 27001", "PDPA"], catatan: "Mematuhi ISO 27001 dan PDPA"},
          "5" => %{maklumbalas: "Ya", catatan: "Compliance reporting diperlukan untuk audit"}
        },
        lain_lain_ciri: %{
          "1" => %{maklumbalas: "Dashboard interaktif, kalendar projek, notifikasi real-time, carian lanjutan", catatan: "Ciri tambahan untuk meningkatkan pengalaman pengguna"},
          "2" => %{maklumbalas: "Ya", catatan: "Multi-bahasa diperlukan untuk pengguna pelbagai bahasa"},
          "3" => %{maklumbalas: ["Bahasa Melayu", "English"], catatan: "Bahasa Melayu dan English adalah keutamaan"},
          "4" => %{maklumbalas: "Ya", catatan: "Tema gelap/terang untuk keselesaan pengguna"},
          "5" => %{maklumbalas: "Sokongan untuk pengguna kurang upaya, aksesibiliti penuh", catatan: "Keperluan khas untuk aksesibiliti"}
        }
      },
      nfr_data: %{
        keselamatan: %{
          "1" => %{maklumbalas: "Tinggi", catatan: "Data sensitif memerlukan tahap keselamatan tinggi"},
          "2" => %{maklumbalas: "Ya", catatan: "Semua data perlu dienkripsi"},
          "3" => %{maklumbalas: ["At Rest", "In Transit"], catatan: "Enkripsi untuk data at rest dan in transit"},
          "4" => %{maklumbalas: "Ya", catatan: "2FA diperlukan untuk akses admin"},
          "5" => %{maklumbalas: "Ya", catatan: "Audit trail untuk semua aktiviti pengguna"},
          "6" => %{maklumbalas: "7 tahun", catatan: "Mematuhi keperluan penyimpanan rekod"}
        },
        akses_capaian: %{
          "1" => %{maklumbalas: "500 pengguna serentak", catatan: "Sistem perlu menyokong sehingga 500 pengguna serentak"},
          "2" => %{maklumbalas: "Ya", catatan: "Akses dari luar pejabat melalui VPN"},
          "3" => %{maklumbalas: ["Desktop", "Laptop", "Mobile"], catatan: "Sokongan untuk desktop, laptop dan mobile"},
          "4" => %{maklumbalas: ["Chrome", "Firefox", "Edge"], catatan: "Sokongan untuk pelayar utama"},
          "5" => %{maklumbalas: "Tidak", catatan: "Akses offline tidak diperlukan"},
          "6" => %{maklumbalas: "5 Mbps", catatan: "Kelajuan minimum 5 Mbps untuk prestasi optimum"}
        },
        usability: %{
          "1" => %{maklumbalas: "Tinggi", catatan: "Sistem perlu mudah digunakan oleh semua peringkat pengguna"},
          "2" => %{maklumbalas: "Ya", catatan: "Panduan pengguna dalam talian diperlukan"},
          "3" => %{maklumbalas: "Ya", catatan: "Tooltip dan bantuan kontekstual untuk memudahkan pengguna"},
          "4" => %{maklumbalas: "2 jam", catatan: "Latihan 2 jam untuk pengguna baru"},
          "5" => %{maklumbalas: "Ya", catatan: "Mematuhi piawaian aksesibiliti"},
          "6" => %{maklumbalas: ["WCAG 2.1"], catatan: "Mematuhi WCAG 2.1 Level AA"}
        }
      },
      disediakan_oleh: %{
        nama: "Ahmad bin Abdullah",
        jawatan: "Pengurus Projek",
        tarikh: Date.utc_today() |> Date.to_string()
      }
    }
  end

end
