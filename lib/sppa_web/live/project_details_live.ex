defmodule SppaWeb.ProjectDetailsLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem"]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user_role =
      socket.assigns.current_scope &&
        socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      case Integer.parse(id) do
        {project_id, _rest} ->
          project = fetch_project(project_id, socket)

          if project do
            # User asked to show the full tabbed view immediately (no extra click).
            {:ok, Phoenix.LiveView.redirect(socket, to: ~p"/projek/#{project_id}")}
          else
            {:ok,
             socket
             |> put_flash(:error, "Projek tidak ditemui.")
             |> Phoenix.LiveView.redirect(to: ~p"/projek")}
          end

        :error ->
          {:ok,
           socket
           |> put_flash(:error, "ID projek tidak sah.")
           |> Phoenix.LiveView.redirect(to: ~p"/projek")}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "Anda tidak mempunyai kebenaran untuk mengakses halaman ini.")
       |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")}
    end
  end

  defp fetch_project(project_id, socket) do
    current_scope = socket.assigns.current_scope
    user_no_kp = current_scope.user.no_kp

    # For pembangun sistem, check access via approved_project.pembangun_sistem
    db_project =
      case Projects.get_project_by_id(project_id) do
        nil -> nil
        project ->
          if Projects.has_access_to_project?(project, user_no_kp) do
            project
          else
            nil
          end
      end

    db_project || get_mock_project_by_id(project_id)
  end

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")

  defp format_datetime(nil), do: "-"
  defp format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d/%m/%Y %H:%M")

  # Mock dataset – keep in sync with `SppaWeb.ProjekLive` for now.
  defp get_mock_project_by_id(project_id) do
    projects = [
      %{
        id: 1,
        nama: "Sistem Pengurusan Projek A",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-01-15],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Ahmad bin Abdullah",
        isu: "Tiada",
        tindakan: "Teruskan pembangunan",
        keterangan:
          "Sistem pengurusan projek yang komprehensif untuk menguruskan semua aspek projek IT di JPKN."
      },
      %{
        id: 2,
        nama: "Sistem Analisis Data B",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2023-11-01],
        tarikh_siap: ~D[2024-05-15],
        pengurus_projek: "Siti Nurhaliza",
        isu: "Perlu pembetulan pada modul laporan",
        tindakan: "Selesaikan isu sebelum penyerahan",
        keterangan: "Sistem untuk menganalisis data dan menjana laporan automatik."
      },
      %{
        id: 3,
        nama: "Portal E-Services C",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-06-01],
        tarikh_siap: ~D[2024-01-31],
        pengurus_projek: "Mohd Faizal",
        isu: "Tiada",
        tindakan: "Projek telah diserahkan",
        keterangan:
          "Portal e-services untuk kemudahan awam mengakses perkhidmatan JPKN secara dalam talian."
      },
      %{
        id: 4,
        nama: "Sistem Pengurusan Dokumen D",
        status: "Ditangguhkan",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: ~D[2024-02-01],
        tarikh_siap: ~D[2024-08-31],
        pengurus_projek: "Nurul Aina",
        isu: "Menunggu kelulusan bajet tambahan",
        tindakan: "Sambung semula selepas kelulusan",
        keterangan: "Sistem untuk menguruskan dokumen digital dengan sistem pengesanan dan versi."
      },
      %{
        id: 5,
        nama: "Aplikasi Mobile E",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-03-01],
        tarikh_siap: ~D[2024-09-30],
        pengurus_projek: "Lim Wei Ming",
        isu: "Masalah integrasi dengan API",
        tindakan: "Selesaikan integrasi API",
        keterangan:
          "Aplikasi mobile untuk akses mudah kepada perkhidmatan JPKN melalui telefon pintar."
      },
      %{
        id: 6,
        nama: "Sistem Pengurusan Inventori F",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-04-15],
        tarikh_siap: ~D[2024-10-31],
        pengurus_projek: "Ahmad bin Abdullah",
        isu: "Tiada",
        tindakan: "Teruskan pembangunan modul inventori",
        keterangan:
          "Sistem untuk menguruskan inventori peralatan dan aset JPKN dengan kemas kini masa nyata."
      },
      %{
        id: 7,
        nama: "Portal Pelanggan G",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2023-12-01],
        tarikh_siap: ~D[2024-07-15],
        pengurus_projek: "Siti Nurhaliza",
        isu: "Isu keselamatan data perlu disemak",
        tindakan: "Lengkapkan audit keselamatan",
        keterangan:
          "Portal untuk pelanggan mengakses maklumat dan perkhidmatan JPKN dengan mudah."
      },
      %{
        id: 8,
        nama: "Sistem Laporan Automatik H",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-08-01],
        tarikh_siap: ~D[2024-02-28],
        pengurus_projek: "Mohd Faizal",
        isu: "Tiada",
        tindakan: "Projek telah diserahkan dan beroperasi",
        keterangan: "Sistem untuk menjana laporan automatik berdasarkan data yang dikumpulkan."
      },
      %{
        id: 9,
        nama: "Aplikasi Web Responsif I",
        status: "Dalam Pembangunan",
        fasa: "Pembangunan",
        tarikh_mula: ~D[2024-05-01],
        tarikh_siap: ~D[2024-11-30],
        pengurus_projek: "Nurul Aina",
        isu: "Perlu penambahbaikan pada reka bentuk UI",
        tindakan: "Kemaskini reka bentuk mengikut spesifikasi",
        keterangan: "Aplikasi web yang responsif untuk akses melalui pelbagai peranti."
      },
      %{
        id: 10,
        nama: "Sistem Integrasi API J",
        status: "Ujian Penerimaan Pengguna",
        fasa: "UAT",
        tarikh_mula: ~D[2024-01-10],
        tarikh_siap: ~D[2024-06-30],
        pengurus_projek: "Lim Wei Ming",
        isu: "Masalah dengan endpoint tertentu",
        tindakan: "Betulkan endpoint yang bermasalah",
        keterangan: "Sistem untuk mengintegrasikan pelbagai sistem melalui API yang standard."
      },
      %{
        id: 11,
        nama: "Sistem Backup dan Pemulihan K",
        status: "Selesai",
        fasa: "Penyerahan",
        tarikh_mula: ~D[2023-09-15],
        tarikh_siap: ~D[2024-03-31],
        pengurus_projek: "Ahmad bin Abdullah",
        isu: "Tiada",
        tindakan: "Sistem telah diserahkan dan beroperasi",
        keterangan: "Sistem untuk backup dan pemulihan data secara automatik dan berkala."
      },
      %{
        id: 12,
        nama: "Portal Pentadbiran L",
        status: "Ditangguhkan",
        fasa: "Analisis dan Rekabentuk",
        tarikh_mula: ~D[2024-06-01],
        tarikh_siap: ~D[2024-12-31],
        pengurus_projek: "Siti Nurhaliza",
        isu: "Menunggu kelulusan dari pihak pengurusan",
        tindakan: "Sambung semula selepas kelulusan",
        keterangan:
          "Portal untuk pentadbiran dalaman dengan akses terhad kepada kakitangan yang berkenaan."
      }
    ]

    Enum.find(projects, fn p -> p.id == project_id end)
  end
end
