defmodule Sppa.Repo.Migrations.AddNoUjianToUjianPenerimaanPengguna do
  use Ecto.Migration

  def change do
    alter table(:ujian_penerimaan_pengguna) do
      add :no_ujian, :string
    end
  end
end
