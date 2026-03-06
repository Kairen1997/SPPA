defmodule Sppa.Repo.Migrations.AddDokumenUjianToUjianPenerimaanPengguna do
  use Ecto.Migration

  def change do
    alter table(:ujian_penerimaan_pengguna) do
      add :dokumen_ujian, :string
      add :dokumen_ujian_nama, :string
    end
  end
end
