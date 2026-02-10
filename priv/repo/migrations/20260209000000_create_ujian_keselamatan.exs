defmodule Sppa.Repo.Migrations.CreateUjianKeselamatan do
  use Ecto.Migration

  def change do
    create table(:ujian_keselamatan) do
      add :tajuk, :string, null: false
      add :modul, :string, null: false
      add :tarikh_ujian, :date
      add :tarikh_dijangka_siap, :date
      add :status, :string, null: false, default: "Menunggu"
      add :penguji, :string
      add :hasil, :string, default: "Belum Selesai"
      add :disahkan_oleh, :string
      add :catatan, :text

      add :project_id, references(:projects, on_delete: :delete_all), null: false

      add :analisis_dan_rekabentuk_module_id,
          references(:analisis_dan_rekabentuk_modules, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:ujian_keselamatan, [:project_id])
    create index(:ujian_keselamatan, [:status])
    create index(:ujian_keselamatan, [:analisis_dan_rekabentuk_module_id])

    create table(:kes_ujian_keselamatan) do
      add :kod, :string, null: false
      add :senario, :string, null: false
      add :langkah, :text
      add :keputusan_dijangka, :text
      add :keputusan_sebenar, :text
      add :hasil, :string
      add :penguji, :string
      add :tarikh_ujian, :date
      add :disahkan, :boolean, default: false, null: false
      add :disahkan_oleh, :string
      add :tarikh_pengesahan, :date

      add :ujian_keselamatan_id,
          references(:ujian_keselamatan, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:kes_ujian_keselamatan, [:ujian_keselamatan_id])
  end
end
