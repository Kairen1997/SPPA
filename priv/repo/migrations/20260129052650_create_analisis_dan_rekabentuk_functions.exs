defmodule Sppa.Repo.Migrations.CreateAnalisisDanRekabentukFunctions do
  use Ecto.Migration

  def change do
    create table(:analisis_dan_rekabentuk_functions) do
      add :name, :string, null: false

      add :analisis_dan_rekabentuk_module_id,
          references(:analisis_dan_rekabentuk_modules, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:analisis_dan_rekabentuk_functions, [:analisis_dan_rekabentuk_module_id])
  end
end
