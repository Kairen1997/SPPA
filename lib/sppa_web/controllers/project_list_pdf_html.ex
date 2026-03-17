defmodule SppaWeb.ProjectListPdfHTML do
  use SppaWeb, :html

  embed_templates "project_list_pdf_html/*"

  # Status lajur: "Pembangun belum di lantik" jika tiada pembangun; "Dalam Pembangunan" jika pembangun sudah dilantik; "Selesai" jika projek selesai.
  def status_display(approved_project) do
    internal_status = approved_project.project && approved_project.project.status

    has_pembangun =
      approved_project.pembangun_sistem && String.trim(approved_project.pembangun_sistem) != ""

    cond do
      internal_status == "Selesai" -> "Selesai"
      has_pembangun -> "Dalam Pembangunan"
      true -> "Pembangun belum di lantik"
    end
  end
end
