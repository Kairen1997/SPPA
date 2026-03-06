defmodule Sppa.Repo.Migrations.AddUjianKeselamatanPermohonanFields do
  use Ecto.Migration

  def change do
    alter table(:ujian_keselamatan) do
      add :tarikh_permohonan, :date
      add :tarikh_kelulusan, :date
      add :upload_file, :string
      add :status_kelulusan, :string
    end
  end
end
