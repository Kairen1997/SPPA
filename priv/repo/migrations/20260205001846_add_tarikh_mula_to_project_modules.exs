defmodule Sppa.Repo.Migrations.AddTarikhMulaToProjectModules do
  use Ecto.Migration

  def change do
    alter table(:project_modules) do
      add :tarikh_mula, :date
    end
  end
end
