defmodule Sppa.Repo.Migrations.CreateAnalisisDanRekabentukModules do
  use Ecto.Migration

  def change do
    create table(:analisis_dan_rekabentuk_modules) do
      add :number, :integer, null: false
      add :name, :string, null: false

      add :analisis_dan_rekabentuk_id,
          references(:analisis_dan_rekabentuk, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:analisis_dan_rekabentuk_modules, [:analisis_dan_rekabentuk_id])
  end
end
