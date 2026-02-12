defmodule Sppa.Repo.Migrations.AddPengurusProjekToApprovedProjects do
  use Ecto.Migration

  def change do
    alter table(:approved_projects) do
      add :pengurus_projek, :string
    end
  end
end
