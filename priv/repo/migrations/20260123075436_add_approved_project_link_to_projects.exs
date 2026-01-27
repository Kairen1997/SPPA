defmodule Sppa.Repo.Migrations.AddApprovedProjectLinkToProjects do
  use Ecto.Migration

  def change do
      alter table(:projects) do
        add :approved_project_id, references(:approved_projects, on_delete: :restrict)
      end

      create index(:projects, [:approved_project_id])
  end
end
