defmodule Sppa.Repo.Migrations.CreateProjectModules do
  use Ecto.Migration

  def change do
    create table(:project_modules) do
      add :title, :string, null: false
      add :description, :text
      add :priority, :string
      add :status, :string, null: false, default: "in_progress"
      add :fasa, :string
      add :versi, :string
      add :due_date, :date

      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :developer_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:project_modules, [:project_id])
    create index(:project_modules, [:developer_id])
  end
end
