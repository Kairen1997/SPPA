defmodule Sppa.Repo.Migrations.CreateModulPengaturcaraan do
  use Ecto.Migration

  def change do
    create table(:modul_pengaturcaraan) do
      add :keutamaan, :string
      add :status, :string, null: false, default: "Belum Mula"
      add :tarikh_mula, :date
      add :tarikh_jangka_siap, :date
      add :catatan, :text

      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :analisis_dan_rekabentuk_module_id,
          references(:analisis_dan_rekabentuk_modules, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:modul_pengaturcaraan, [:project_id])
    create index(:modul_pengaturcaraan, [:analisis_dan_rekabentuk_module_id])
    create unique_index(:modul_pengaturcaraan, [:project_id, :analisis_dan_rekabentuk_module_id],
             name: :modul_pengaturcaraan_project_module_index
           )
  end
end
