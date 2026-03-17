defmodule Sppa.Repo.Migrations.AddAttachmentOriginalNameToMaklumbalas do
  use Ecto.Migration

  def change do
    alter table(:maklumbalas) do
      add :attachment_original_name, :string
    end
  end
end

