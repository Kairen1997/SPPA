defmodule Sppa.Repo.Migrations.CreatePermohonanPerubahan do
  use Ecto.Migration

  def change do
    create table(:permohonan_perubahan) do
      add :tajuk, :string, null: false
      add :jenis, :string, null: false
      add :modul_terlibat, :string, null: false
      add :status, :string, null: false, default: "Dalam Semakan"
      add :keutamaan, :string
      add :tarikh_dibuat, :date, null: false
      add :tarikh_dijangka_siap, :date
      add :justifikasi, :text
      add :kesan, :text
      add :catatan, :text

      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:permohonan_perubahan, [:project_id])
    create index(:permohonan_perubahan, [:status])
  end
end
