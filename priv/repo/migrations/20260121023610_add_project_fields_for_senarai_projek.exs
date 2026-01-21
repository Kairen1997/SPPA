defmodule Sppa.Repo.Migrations.AddProjectFieldsForSenaraiProjek do
  use Ecto.Migration

  def change do
    # Rename name to nama
    rename table(:projects), :name, to: :nama

    # Add new fields for senarai projek
    alter table(:projects) do
      add :jabatan, :string
      add :fasa, :string
      add :tarikh_mula, :date
      add :tarikh_siap, :date
      add :dokumen_sokongan, :integer, default: 0
    end
  end
end
