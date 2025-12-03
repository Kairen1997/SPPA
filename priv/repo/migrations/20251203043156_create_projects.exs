defmodule Sppa.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :name, :string
      add :status, :string
      add :last_updated, :utc_datetime
      add :developer_id, references(:users, on_delete: :nothing)
      add :project_manager_id, references(:users, on_delete: :nothing)
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:user_id])

    create index(:projects, [:developer_id])
    create index(:projects, [:project_manager_id])
  end
end
