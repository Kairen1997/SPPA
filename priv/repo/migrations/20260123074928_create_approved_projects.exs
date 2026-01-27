defmodule Sppa.Repo.Migrations.CreateApprovedProjects do
  use Ecto.Migration

  def change do
      create table(:approved_projects) do
        add :external_application_id, :integer, null: false
        add :nama_projek, :string, null: false
        add :jabatan, :string
        add :pengurus_email, :string

        add :tarikh_mula, :date
        add :tarikh_jangkaan_siap, :date

        add :pembangun_sistem, :string

        add :latar_belakang, :text
        add :objektif, :text
        add :skop, :text
        add :kumpulan_pengguna, :text
        add :implikasi, :text

        add :kertas_kerja_path, :string

        timestamps(type: :utc_datetime)
      end

      create unique_index(:approved_projects, [:external_application_id])
  end
end
