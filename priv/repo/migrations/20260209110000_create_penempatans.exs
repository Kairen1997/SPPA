defmodule Sppa.Repo.Migrations.CreatePenempatans do
  use Ecto.Migration

  def change do
    create table(:penempatans) do
      add :nama_sistem, :string, null: false
      add :versi, :string, null: false, default: "1.0.0"
      add :lokasi, :string, null: false
      add :jenis, :string, null: false
      add :status, :string, null: false, default: "Menunggu"
      add :persekitaran, :string
      add :tarikh_penempatan, :date, null: false
      add :tarikh_dijangka, :date
      add :url, :string
      add :catatan, :text
      add :dibina_oleh, :string
      add :disemak_oleh, :string
      add :diluluskan_oleh, :string
      add :tarikh_dibina, :date
      add :tarikh_disemak, :date
      add :tarikh_diluluskan, :date

      add :project_id, references(:projects, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:penempatans, [:project_id])
    create index(:penempatans, [:status])
    create index(:penempatans, [:tarikh_penempatan])
  end
end
