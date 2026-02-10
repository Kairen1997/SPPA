defmodule Sppa.Repo.Migrations.CreateUjianPenerimaanPengguna do
  use Ecto.Migration

  def change do
    create table(:ujian_penerimaan_pengguna) do
      add :tajuk, :string, null: false
      add :modul, :string, null: false
      add :tarikh_ujian, :date, null: false
      add :tarikh_dijangka_siap, :date, null: false
      add :status, :string, null: false, default: "Menunggu"
      add :penguji, :string
      add :hasil, :string, default: "Belum Selesai"
      add :catatan, :text

      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ujian_penerimaan_pengguna, [:project_id])
    create index(:ujian_penerimaan_pengguna, [:status])

    create table(:kes_ujian_penerimaan_pengguna) do
      add :kod, :string, null: false
      add :senario, :string, null: false
      add :langkah, :text
      add :keputusan_dijangka, :text
      add :keputusan_sebenar, :text
      add :hasil, :string
      add :penguji, :string
      add :tarikh_ujian, :date
      add :disahkan_oleh, :string
      add :tarikh_pengesahan, :date

      add :ujian_penerimaan_pengguna_id,
          references(:ujian_penerimaan_pengguna, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:kes_ujian_penerimaan_pengguna, [:ujian_penerimaan_pengguna_id])
  end
end
