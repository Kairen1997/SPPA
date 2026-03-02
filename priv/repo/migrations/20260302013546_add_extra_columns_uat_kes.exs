defmodule Sppa.Repo.Migrations.AddExtraColumnsUatKes do
  use Ecto.Migration

  def change do
    alter table(:ujian_penerimaan_pengguna) do
      add :extra_columns, :string, default: "[]"
    end

    alter table(:kes_ujian_penerimaan_pengguna) do
      add :extra_values, :string, default: "{}"
    end
  end
end
