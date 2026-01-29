defmodule Sppa.Repo.Migrations.CreateAnalisisDanRekabentukSubFunctions do
  use Ecto.Migration

  def change do
    create table(:analisis_dan_rekabentuk_sub_functions) do
      add :name, :string, null: false
      add :analisis_dan_rekabentuk_function_id, references(:analisis_dan_rekabentuk_functions, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:analisis_dan_rekabentuk_sub_functions, [:analisis_dan_rekabentuk_function_id])
  end
end
