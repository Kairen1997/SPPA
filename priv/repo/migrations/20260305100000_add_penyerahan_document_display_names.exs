defmodule Sppa.Repo.Migrations.AddPenyerahanDocumentDisplayNames do
  use Ecto.Migration

  def change do
    alter table(:penyerahans) do
      add :manual_pengguna_nama, :string
      add :surat_akuan_nama, :string
    end
  end
end
