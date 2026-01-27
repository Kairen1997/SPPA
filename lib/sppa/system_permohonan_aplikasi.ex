defmodule SPPA.SystemPermohonanAplikasiLink do
  def permohonan_aplikasi_url(external_application_id) do
    base_url()
    <> "/requests/"
    <> to_string(external_application_id)
  end

    defp base_url do
    Application.fetch_env!(:sppa, :system_permohonan_aplikasi)[:base_url]
  end
end
