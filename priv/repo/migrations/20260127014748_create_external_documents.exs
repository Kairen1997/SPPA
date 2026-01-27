defmodule Sppa.Repo.Migrations.CreateExternalDocuments do
  use Ecto.Migration

  def change do
    create table(:external_documents) do
      add :"\\", :string
      add :user_id, references(:users, type: :id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:external_documents, [:user_id])
  end
end
