defmodule Sppa.Repo.Migrations.CreatePenyerahans do
  use Ecto.Migration

  def change do
    create table(:penyerahans) do
      add :nama_sistem, :string
      add :versi, :string
      add :penerima, :string
      add :pengurus_projek, :string
      add :tarikh_penyerahan, :date
      add :manual_pengguna_bahagian_a, :string
      add :surat_akuan_penerimaan, :string

      add :project_id, references(:projects, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:penyerahans, [:project_id])
  end
end
