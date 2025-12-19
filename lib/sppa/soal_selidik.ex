defmodule Sppa.SoalSelidik do
  @moduledoc """
  Shared Soal Selidik template structures and "PDF preview" data.

  Note: The app currently renders a printable HTML preview (which the browser can
  print/save as PDF) rather than generating PDF bytes on the server.
  """

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

  def fr_categories, do: @fr_categories
  def nfr_categories, do: @nfr_categories

  @doc """
  Returns a structured map used by the printable Soal Selidik preview.

  Options:
  - `:nama_sistem` - defaults to "Sistem Pengurusan Projek Aplikasi (SPPA)"
  """
  def pdf_data(opts \\ []) do
    nama_sistem = Keyword.get(opts, :nama_sistem, "Sistem Pengurusan Projek Aplikasi (SPPA)")

    %{
      nama_sistem: nama_sistem,
      document_id: "JPKN-BPA-01/B1",
      fr_categories: @fr_categories,
      nfr_categories: @nfr_categories,
      fr_data: %{
        "pendaftaran_login" => %{
          "1" => %{maklumbalas: "Ya", catatan: "Sistem memerlukan pendaftaran pengguna untuk akses terkawal"},
          "2" => %{maklumbalas: ["Kata laluan", "OTP"], catatan: "Menggunakan kata laluan dan OTP untuk keselamatan tambahan"},
          "3" => %{maklumbalas: "Tidak", catatan: "Pendaftaran hanya dilakukan oleh admin"},
          "4" => %{maklumbalas: "30 minit", catatan: "Sesi akan tamat selepas 30 minit tidak aktif"},
          "5" => %{maklumbalas: "Ya", catatan: "Pengguna boleh reset kata laluan melalui email"}
        },
        "pengurusan_data" => %{
          "1" => %{maklumbalas: "Data projek, pengguna, dokumen, dan laporan", catatan: "Sistem perlu mengurus pelbagai jenis data"},
          "2" => %{maklumbalas: "Ya", catatan: "Import data pukal diperlukan untuk migrasi data"},
          "3" => %{maklumbalas: ["Excel", "CSV"], catatan: "Format Excel dan CSV adalah keutamaan"},
          "4" => %{maklumbalas: "Ya", catatan: "Export data diperlukan untuk backup dan laporan"},
          "5" => %{maklumbalas: "7 tahun", catatan: "Mematuhi keperluan penyimpanan rekod kerajaan"},
          "6" => %{maklumbalas: "Ya", catatan: "Backup harian secara automatik"}
        },
        "proses_kerja" => %{
          "1" => %{maklumbalas: "Permohonan projek → Kelulusan → Pembangunan → Ujian → Penempatan", catatan: "Alur kerja utama sistem"},
          "2" => %{maklumbalas: "Ya", catatan: "Workflow approval diperlukan untuk kelulusan projek"},
          "3" => %{maklumbalas: "3 peringkat", catatan: "Pengurus Projek → Ketua Penolong Pengarah → Pengarah"},
          "4" => %{maklumbalas: "Ya", catatan: "Notifikasi diperlukan untuk proses kelulusan"},
          "5" => %{maklumbalas: ["Email", "Dalam Sistem"], catatan: "Notifikasi melalui email dan dalam sistem"}
        },
        "laporan" => %{
          "1" => %{maklumbalas: "Laporan status projek, laporan kemajuan, laporan kewangan, laporan audit", catatan: "Pelbagai jenis laporan diperlukan"},
          "2" => %{maklumbalas: "Ya", catatan: "Semua laporan perlu boleh dieksport"},
          "3" => %{maklumbalas: ["PDF", "Excel"], catatan: "Format PDF dan Excel adalah keutamaan"},
          "4" => %{maklumbalas: "Ya", catatan: "Laporan bulanan perlu dijana secara automatik"},
          "5" => %{maklumbalas: "Bulanan", catatan: "Laporan bulanan untuk pengurusan atasan"}
        },
        "integrasi" => %{
          "1" => %{maklumbalas: "Ya", catatan: "Perlu berintegrasi dengan sistem sedia ada"},
          "2" => %{maklumbalas: "Sistem HR, Sistem Kewangan, Sistem Email", catatan: "Integrasi dengan sistem utama organisasi"},
          "3" => %{maklumbalas: ["REST API", "Database"], catatan: "Menggunakan REST API dan sambungan database"},
          "4" => %{maklumbalas: "Kedua-dua", catatan: "Real-time untuk data kritikal, batch untuk data besar"},
          "5" => %{maklumbalas: "Ya", catatan: "API diperlukan untuk sistem luaran"}
        },
        "role_akses" => %{
          "1" => %{maklumbalas: "Admin, Pengurus Projek, Pembangun Sistem, Ketua Penolong Pengarah, Pengarah", catatan: "Pelbagai peranan dengan akses berbeza"},
          "2" => %{maklumbalas: "Ya", catatan: "RBAC diperlukan untuk kawalan akses yang ketat"},
          "3" => %{maklumbalas: "Ya", catatan: "Permission granular untuk fungsi tertentu"},
          "4" => %{maklumbalas: "Ya", catatan: "Audit log untuk keselamatan dan compliance"},
          "5" => %{maklumbalas: "Admin sistem dan Pengarah", catatan: "Akses admin terhad kepada pengguna tertentu"}
        },
        "peraturan_polisi" => %{
          "1" => %{maklumbalas: "PDPA, Polisi Keselamatan IT, Polisi Pengurusan Data", catatan: "Mematuhi semua peraturan dan polisi organisasi"},
          "2" => %{maklumbalas: "Ya", catatan: "Mematuhi piawaian keselamatan yang ditetapkan"},
          "3" => %{maklumbalas: "Ya", catatan: "Mematuhi PDPA untuk perlindungan data peribadi"},
          "4" => %{maklumbalas: ["ISO 27001", "PDPA"], catatan: "Mematuhi ISO 27001 dan PDPA"},
          "5" => %{maklumbalas: "Ya", catatan: "Compliance reporting diperlukan untuk audit"}
        },
        "lain_lain_ciri" => %{
          "1" => %{maklumbalas: "Dashboard interaktif, kalendar projek, notifikasi real-time, carian lanjutan", catatan: "Ciri tambahan untuk meningkatkan pengalaman pengguna"},
          "2" => %{maklumbalas: "Ya", catatan: "Multi-bahasa diperlukan untuk pengguna pelbagai bahasa"},
          "3" => %{maklumbalas: ["Bahasa Melayu", "English"], catatan: "Bahasa Melayu dan English adalah keutamaan"},
          "4" => %{maklumbalas: "Ya", catatan: "Tema gelap/terang untuk keselesaan pengguna"},
          "5" => %{maklumbalas: "Sokongan untuk pengguna kurang upaya, aksesibiliti penuh", catatan: "Keperluan khas untuk aksesibiliti"}
        }
      },
      nfr_data: %{
        "keselamatan" => %{
          "1" => %{maklumbalas: "Tinggi", catatan: "Data sensitif memerlukan tahap keselamatan tinggi"},
          "2" => %{maklumbalas: "Ya", catatan: "Semua data perlu dienkripsi"},
          "3" => %{maklumbalas: ["At Rest", "In Transit"], catatan: "Enkripsi untuk data at rest dan in transit"},
          "4" => %{maklumbalas: "Ya", catatan: "2FA diperlukan untuk akses admin"},
          "5" => %{maklumbalas: "Ya", catatan: "Audit trail untuk semua aktiviti pengguna"},
          "6" => %{maklumbalas: "7 tahun", catatan: "Mematuhi keperluan penyimpanan rekod"}
        },
        "akses_capaian" => %{
          "1" => %{maklumbalas: "500 pengguna serentak", catatan: "Sistem perlu menyokong sehingga 500 pengguna serentak"},
          "2" => %{maklumbalas: "Ya", catatan: "Akses dari luar pejabat melalui VPN"},
          "3" => %{maklumbalas: ["Desktop", "Laptop", "Mobile"], catatan: "Sokongan untuk desktop, laptop dan mobile"},
          "4" => %{maklumbalas: ["Chrome", "Firefox", "Edge"], catatan: "Sokongan untuk pelayar utama"},
          "5" => %{maklumbalas: "Tidak", catatan: "Akses offline tidak diperlukan"},
          "6" => %{maklumbalas: "5 Mbps", catatan: "Kelajuan minimum 5 Mbps untuk prestasi optimum"}
        },
        "usability" => %{
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
