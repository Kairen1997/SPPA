defmodule Sppa.AnalisisDanRekabentuk do
  @moduledoc """
  Shared "Analisis dan Rekabentuk" (B2) structures and printable preview data.

  Note: The app renders a printable HTML preview that users can print/save as PDF.
  """

  @doc "Default module/function structure used as a starting point."
  def initial_modules do
    [
      %{
        id: "module_1",
        number: 1,
        name: "Modul Pengurusan Pengguna",
        functions: [
          %{
            id: "func_1_1",
            name: "Pendaftaran Pengguna",
            sub_functions: [%{id: "sub_1_1_1", name: "Pengesahan Pendaftaran"}]
          },
          %{id: "func_1_2", name: "Laman Log Masuk", sub_functions: []},
          %{
            id: "func_1_3",
            name: "Penyelenggaraan Profail",
            sub_functions: [%{id: "sub_1_3_1", name: "Pengemaskinian Profil"}]
          }
        ]
      },
      %{
        id: "module_2",
        number: 2,
        name: "Penyelenggaraan Kata Laluan",
        functions: []
      },
      %{
        id: "module_3",
        number: 3,
        name: "Modul Permohonan",
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
        functions: [
          %{id: "func_4_1", name: "Verifikasi Permohonan", sub_functions: []},
          %{id: "func_4_2", name: "Kelulusan Permohonan", sub_functions: []}
        ]
      },
      %{
        id: "module_5",
        number: 5,
        name: "Modul Laporan",
        functions: [
          %{id: "func_5_1", name: "Laporan mengikut tahun", sub_functions: []},
          %{id: "func_5_2", name: "Laporan mengikut lokasi/daerah", sub_functions: []}
        ]
      },
      %{
        id: "module_6",
        number: 6,
        name: "Modul Dashboard",
        functions: []
      }
    ]
  end

  @doc """
  Returns a structured map used by the printable preview.

  Options:
  - `:document_id` - defaults to "JPKN-BPA-01/B2"
  - `:nama_projek` - defaults to "Sistem Pengurusan Permohonan Aplikasi (SPPA)"
  - `:nama_agensi` - defaults to "Jabatan Pendaftaran Negara Sabah (JPKN)"
  - `:versi` - defaults to "1.0.0"
  - `:tarikh_semakan` - defaults to today's date (DD/MM/YYYY)
  - `:rujukan_perubahan` - default dummy reference string
  - `:modules` - defaults to `initial_modules/0`
  - `:prepared_by_*` / `:approved_by_*`
  """
  def pdf_data(opts \\ []) do
    modules = Keyword.get(opts, :modules, initial_modules())

    today =
      Date.utc_today()
      |> Date.to_string()
      |> String.split("-")
      |> Enum.reverse()
      |> Enum.join("/")

    %{
      document_id: Keyword.get(opts, :document_id, "JPKN-BPA-01/B2"),
      nama_projek:
        Keyword.get(opts, :nama_projek, "Sistem Pengurusan Permohonan Aplikasi (SPPA)"),
      nama_agensi: Keyword.get(opts, :nama_agensi, "Jabatan Pendaftaran Negara Sabah (JPKN)"),
      versi: Keyword.get(opts, :versi, "1.0.0"),
      tarikh_semakan: Keyword.get(opts, :tarikh_semakan, today),
      rujukan_perubahan:
        Keyword.get(
          opts,
          :rujukan_perubahan,
          "Mesyuarat Jawatankuasa Teknologi Maklumat - 15 Disember 2024"
        ),
      modules: modules,
      total_modules: length(modules),
      total_functions:
        modules
        |> Enum.map(fn module -> length(module.functions) end)
        |> Enum.sum(),
      prepared_by_name: Keyword.get(opts, :prepared_by_name, "Ahmad bin Abdullah"),
      prepared_by_position: Keyword.get(opts, :prepared_by_position, "Pengurus Projek"),
      prepared_by_date: Keyword.get(opts, :prepared_by_date, today),
      approved_by_name: Keyword.get(opts, :approved_by_name, "Dr. Siti binti Hassan"),
      approved_by_position: Keyword.get(opts, :approved_by_position, "Ketua Penolong Pengarah"),
      approved_by_date: Keyword.get(opts, :approved_by_date, today)
    }
  end
end
