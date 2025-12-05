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
        |> assign(:fr_categories, @fr_categories)
        |> assign(:nfr_categories, @nfr_categories)
        |> assign(:form, to_form(%{}, as: :soal_selidik))

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

end
