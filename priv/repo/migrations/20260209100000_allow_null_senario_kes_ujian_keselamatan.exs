defmodule Sppa.Repo.Migrations.AllowNullSenarioKesUjianKeselamatan do
  use Ecto.Migration

  def change do
    alter table(:kes_ujian_keselamatan) do
      modify :senario, :string, null: true, default: ""
    end
  end
end
