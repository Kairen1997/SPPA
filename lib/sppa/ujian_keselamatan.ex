defmodule Sppa.UjianKeselamatan do
  @moduledoc """
  Context for security tests (ujian keselamatan).
  Returns placeholder data for now; can be replaced with DB-backed queries later.
  """

  @doc """
  Returns the list of ujian keselamatan (security test) records.
  """
  def list_ujian do
    [
      %{
        id: "ujian_keselamatan_1",
        number: 1,
        tajuk: "Ujian Keselamatan Autentikasi",
        modul: "Modul Autentikasi",
        tarikh_ujian: ~D[2024-12-01],
        tarikh_dijangka_siap: ~D[2024-12-15],
        status: "Dalam Proses",
        penguji: "Ahmad bin Abdullah",
        hasil: "Belum Selesai",
        catatan: "Ujian keselamatan untuk autentikasi pengguna",
        senarai_kes_ujian: [
          %{
            id: "SEC-001",
            senario: "Ujian kekuatan kata laluan",
            langkah: "1. Layari halaman pendaftaran\n2. Cuba daftar dengan kata laluan lemah",
            keputusan_dijangka: "Sistem menolak kata laluan lemah dan memaparkan mesej ralat",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-002",
            senario: "Ujian perlindungan terhadap serangan brute force",
            langkah:
              "1. Cuba log masuk dengan kata laluan salah berkali-kali\n2. Perhatikan tindakan sistem",
            keputusan_dijangka: "Sistem mengunci akaun selepas beberapa percubaan gagal",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-003",
            senario: "Ujian perlindungan terhadap SQL injection",
            langkah: "1. Cuba masukkan kod SQL dalam medan input\n2. Perhatikan respons sistem",
            keputusan_dijangka: "Sistem menapis input dan tidak membenarkan kod SQL dilaksanakan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-004",
            senario: "Ujian perlindungan terhadap XSS (Cross-Site Scripting)",
            langkah:
              "1. Cuba masukkan skrip JavaScript dalam medan input\n2. Perhatikan respons sistem",
            keputusan_dijangka: "Sistem menapis atau melarikan skrip JavaScript",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-005",
            senario: "Ujian pengurusan sesi",
            langkah:
              "1. Log masuk ke sistem\n2. Tutup pelayar tanpa log keluar\n3. Buka semula dan cuba akses",
            keputusan_dijangka: "Sesi tamat tempoh dan pengguna perlu log masuk semula",
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
        id: "ujian_keselamatan_2",
        number: 2,
        tajuk: "Ujian Keselamatan Data",
        modul: "Modul Pengurusan Data",
        tarikh_ujian: ~D[2024-12-05],
        tarikh_dijangka_siap: ~D[2024-12-20],
        status: "Selesai",
        penguji: "Siti binti Hassan",
        hasil: "Lulus",
        catatan: "Semua ujian keselamatan data berjaya diluluskan",
        senarai_ujian: [],
        senarai_kes_ujian: []
      },
      %{
        id: "ujian_keselamatan_3",
        number: 3,
        tajuk: "Ujian Keselamatan Rangkaian",
        modul: "Modul Rangkaian",
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
end
