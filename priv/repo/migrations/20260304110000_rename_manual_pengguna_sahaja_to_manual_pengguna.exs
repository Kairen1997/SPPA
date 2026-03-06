defmodule Sppa.Repo.Migrations.RenameManualPenggunaSahajaToManualPengguna do
  use Ecto.Migration

  def change do
    rename table(:penyerahans), :manual_pengguna_sahaja, to: :manual_pengguna
  end
end
