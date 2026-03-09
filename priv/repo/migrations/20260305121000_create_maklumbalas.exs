defmodule Sppa.Repo.Migrations.CreateMaklumbalas do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:maklumbalas) do
      add :tarikh_maklumbalas, :date
      add :jabatan, :string
      add :responden, :string
      add :butiran, :string

      add :project_id, references(:projects, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:maklumbalas, [:project_id])
  end
end
