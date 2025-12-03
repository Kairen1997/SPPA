defmodule Sppa.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :no_kp, :string, null: false
      add :hashed_password, :string, null: false
      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :updated_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create unique_index(:users, [:no_kp])
  end
end
