defmodule Sppa.UjianPenerimaanPengguna do
  @moduledoc false

  @doc """
  Returns the list of UAT records (placeholder seed data for now).
  """
  def list_ujian do
    [
      %{
        id: "ujian_1",
        number: 1,
        tajuk: "Ujian Modul Pendaftaran",
        modul: "Modul Pendaftaran",
        tarikh_ujian: ~D[2024-12-01],
        tarikh_dijangka_siap: ~D[2024-12-15],
        status: "Dalam Proses",
        penguji: "Ahmad bin Abdullah",
        hasil: "Belum Selesai",
        catatan: "Ujian pendaftaran pengguna",
        senarai_kes_ujian: [
          %{
            id: "REG-001",
            senario: "Semak paparan halaman pendaftaran",
            langkah: "1. Layari laman utama Sistem\n2. Klik butang 'Daftar'",
            keputusan_dijangka: "Halaman pendaftaran dipaparkan dengan betul",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "REG-002",
            senario: "Pendaftaran berjaya dengan data yang sah",
            langkah: "Isikan semua maklumat dengan betul",
            keputusan_dijangka:
              "Akaun berjaya dicipta dan mesej 'Pendaftaran Pengguna berjaya didaftarkan' dipaparkan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "REG-003",
            senario: "Pendaftaran gagal - kata laluan tidak sepadan",
            langkah: "Isikan kata laluan dan pengesahan kata laluan yang berbeza",
            keputusan_dijangka: "Mesej ralat 'Kata laluan tidak sepadan' dipaparkan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "REG-004",
            senario: "Pendaftaran gagal - emel telah digunakan",
            langkah: "Isikan emel yang telah wujud dalam sistem",
            keputusan_dijangka: "Mesej ralat 'Emel telah digunakan' dipaparkan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "REG-005",
            senario: "Pendaftaran gagal - medan wajib kosong",
            langkah: "Biarkan medan wajib kosong dan cuba hantar borang",
            keputusan_dijangka: "Mesej ralat 'Sila isi semua medan wajib' dipaparkan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "REG-006",
            senario: "Pendaftaran gagal - format emel tidak sah",
            langkah: "Isikan format emel yang tidak sah (cth: emel@)",
            keputusan_dijangka: "Mesej ralat 'Format emel tidak sah' dipaparkan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "REG-007",
            senario: "Pendaftaran gagal - kata laluan terlalu pendek",
            langkah: "Isikan kata laluan yang kurang daripada 8 aksara",
            keputusan_dijangka:
              "Mesej ralat 'Kata laluan mesti sekurang-kurangnya 8 aksara' dipaparkan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "REG-008",
            senario: "Pendaftaran gagal - kata laluan tidak mengandungi nombor",
            langkah: "Isikan kata laluan tanpa nombor",
            keputusan_dijangka:
              "Mesej ralat 'Kata laluan mesti mengandungi sekurang-kurangnya satu nombor' dipaparkan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          }
        ]
      },
      %{
        id: "ujian_2",
        number: 2,
        tajuk: "Ujian Modul Pengurusan Pengguna",
        modul: "Modul Pengurusan Pengguna",
        tarikh_ujian: ~D[2024-12-01],
        tarikh_dijangka_siap: ~D[2024-12-15],
        status: "Dalam Proses",
        penguji: "Ahmad bin Abdullah",
        hasil: "Lulus",
        catatan: "Semua fungsi asas berfungsi dengan baik",
        senarai_ujian: [
          %{
            id: "test_1_1",
            nama: "Ujian Pendaftaran Pengguna",
            status: "Lulus",
            catatan: "Berfungsi dengan baik"
          },
          %{id: "test_1_2", nama: "Ujian Log Masuk", status: "Lulus", catatan: "Tiada masalah"},
          %{
            id: "test_1_3",
            nama: "Ujian Kemaskini Profil",
            status: "Gagal",
            catatan: "Perlu pembaikan pada validasi"
          }
        ]
      },
      %{
        id: "ujian_2",
        number: 2,
        tajuk: "Ujian Modul Permohonan",
        modul: "Modul Permohonan",
        tarikh_ujian: ~D[2024-12-05],
        tarikh_dijangka_siap: ~D[2024-12-20],
        status: "Selesai",
        penguji: "Siti binti Hassan",
        hasil: "Lulus",
        catatan: "Semua ujian berjaya diluluskan",
        senarai_ujian: [
          %{
            id: "test_2_1",
            nama: "Ujian Pendaftaran Permohonan",
            status: "Lulus",
            catatan: "Berfungsi dengan baik"
          },
          %{
            id: "test_2_2",
            nama: "Ujian Kemaskini Permohonan",
            status: "Lulus",
            catatan: "Tiada masalah"
          },
          %{
            id: "test_2_3",
            nama: "Ujian Semakan Status",
            status: "Lulus",
            catatan: "Berfungsi dengan baik"
          }
        ],
        senarai_kes_ujian: []
      },
      %{
        id: "ujian_3",
        number: 3,
        tajuk: "Ujian Modul Pengurusan Permohonan",
        modul: "Modul Pengurusan Permohonan",
        tarikh_ujian: ~D[2024-12-10],
        tarikh_dijangka_siap: ~D[2024-12-25],
        status: "Menunggu",
        penguji: "Mohd bin Ismail",
        hasil: "Belum Selesai",
        catatan: "Menunggu untuk memulakan ujian",
        senarai_ujian: [],
        senarai_kes_ujian: []
      }
    ]
  end

  @doc """
  Finds a UAT entry by id.
  """
  def get_ujian(id) do
    Enum.find(list_ujian(), fn ujian -> ujian.id == id end)
  end
end
