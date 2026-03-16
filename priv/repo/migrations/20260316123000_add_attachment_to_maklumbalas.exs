defmodule Sppa.Repo.Migrations.AddAttachmentToMaklumbalas do
  use Ecto.Migration

  def change do
    alter table(:maklumbalas) do
      add :attachment_path, :string
    end
  end
end

