defmodule Sppa.Repo.Migrations.AddExternalUpdatedAtToApprovedProjects do
  use Ecto.Migration

  def change do
    alter table(:approved_projects) do
      add :external_updated_at, :utc_datetime
    end
  end
end
