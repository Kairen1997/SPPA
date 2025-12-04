defmodule Sppa.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :no_kp, :string, null: false
      add :hashed_password, :string, null: false
    end

    create unique_index(:users, [:no_kp])
  end
end
