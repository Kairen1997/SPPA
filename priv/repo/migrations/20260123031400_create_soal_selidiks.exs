defmodule Sppa.Repo.Migrations.CreateSoalSelidiks do
  use Ecto.Migration

  def up do
    # Only create if table doesn't exist
    create_if_not_exists table(:soal_selidiks) do
      add :nama_sistem, :string
      add :document_id, :string, default: "JPKN-BPA-01/B1"
      add :project_id, references(:projects, on_delete: :nilify_all)
      add :user_id, references(:users, type: :id, on_delete: :delete_all), null: false

      # Store categories and questions as JSON
      add :fr_categories, :map, default: %{}
      add :nfr_categories, :map, default: %{}

      # Store responses as JSON
      add :fr_data, :map, default: %{}
      add :nfr_data, :map, default: %{}

      # Store disediakan_oleh info as JSON
      add :disediakan_oleh, :map, default: %{}

      # Store custom tabs and tabs configuration as JSON
      add :custom_tabs, :map, default: %{}
      add :tabs, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists index(:soal_selidiks, [:user_id])
    create_if_not_exists index(:soal_selidiks, [:project_id])
  end

  def down do
    drop_if_exists index(:soal_selidiks, [:project_id])
    drop_if_exists index(:soal_selidiks, [:user_id])
    drop_if_exists table(:soal_selidiks)
  end
end
