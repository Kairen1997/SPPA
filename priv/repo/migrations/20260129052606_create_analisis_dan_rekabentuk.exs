defmodule Sppa.Repo.Migrations.CreateAnalisisDanRekabentuk do
  use Ecto.Migration

  def change do
    create table(:analisis_dan_rekabentuk) do
      add :document_id, :string, default: "JPKN-BPA-01/B2"
      add :nama_projek, :string
      add :nama_agensi, :string
      add :versi, :string
      add :tarikh_semakan, :date
      add :rujukan_perubahan, :string
      
      # Prepared by section
      add :prepared_by_name, :string
      add :prepared_by_position, :string
      add :prepared_by_date, :date
      
      # Approved by section
      add :approved_by_name, :string
      add :approved_by_position, :string
      add :approved_by_date, :date
      
      add :project_id, references(:projects, on_delete: :nilify_all)
      add :user_id, references(:users, type: :id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:analisis_dan_rekabentuk, [:user_id])
    create index(:analisis_dan_rekabentuk, [:project_id])
  end
end
