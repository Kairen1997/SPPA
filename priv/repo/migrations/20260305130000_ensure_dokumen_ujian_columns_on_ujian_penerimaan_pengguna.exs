defmodule Sppa.Repo.Migrations.EnsureDokumenUjianColumnsOnUjianPenerimaanPengguna do
  use Ecto.Migration

  def change do
    execute("""
    ALTER TABLE ujian_penerimaan_pengguna
    ADD COLUMN IF NOT EXISTS dokumen_ujian varchar,
    ADD COLUMN IF NOT EXISTS dokumen_ujian_nama varchar
    """)
  end
end

