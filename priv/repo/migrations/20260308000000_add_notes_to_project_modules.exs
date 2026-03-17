defmodule Sppa.Repo.Migrations.AddNotesToProjectModules do
  use Ecto.Migration

  def change do
    alter table(:project_modules) do
      add :notes, :text
    end
  end
end
