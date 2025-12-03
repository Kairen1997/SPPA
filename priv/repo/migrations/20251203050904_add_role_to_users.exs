defmodule Sppa.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :role, :string
    end

    create index(:users, [:role])
  end
end
