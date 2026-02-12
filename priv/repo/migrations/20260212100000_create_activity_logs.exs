defmodule Sppa.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add :actor_id, references(:users, on_delete: :nilify_all), null: false
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :integer, null: false
      add :resource_name, :string, null: false
      add :details, :string

      timestamps(type: :utc_datetime)
    end

    create index(:activity_logs, [:actor_id])
    create index(:activity_logs, [:resource_type, :resource_id])
    create index(:activity_logs, [:inserted_at])
  end
end
