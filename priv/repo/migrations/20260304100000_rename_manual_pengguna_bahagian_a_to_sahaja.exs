defmodule Sppa.Repo.Migrations.RenameManualPenggunaBahagianAToSahaja do
  use Ecto.Migration

  def change do
    rename table(:penyerahans), :manual_pengguna_bahagian_a, to: :manual_pengguna_sahaja
  end
end
