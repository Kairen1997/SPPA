defmodule Sppa.ModulPengaturcaraan.ModulPengaturcaraan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "modul_pengaturcaraan" do
    field :keutamaan, :string
    field :status, :string, default: "Belum Mula"
    field :tarikh_mula, :date
    field :tarikh_jangka_siap, :date
    field :catatan, :string

    belongs_to :project, Sppa.Projects.Project
    belongs_to :analisis_dan_rekabentuk_module, Sppa.AnalisisDanRekabentuk.Module,
      foreign_key: :analisis_dan_rekabentuk_module_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(modul_pengaturcaraan, attrs) do
    modul_pengaturcaraan
    |> cast(attrs, [
      :keutamaan,
      :status,
      :tarikh_mula,
      :tarikh_jangka_siap,
      :catatan,
      :project_id,
      :analisis_dan_rekabentuk_module_id
    ])
    |> validate_required([:project_id, :analisis_dan_rekabentuk_module_id])
    |> validate_inclusion(:status, ["Belum Mula", "Sedang Dibangunkan", "Dalam Ujian", "Selesai"])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:analisis_dan_rekabentuk_module_id)
    |> unique_constraint([:project_id, :analisis_dan_rekabentuk_module_id],
      name: :modul_pengaturcaraan_project_module_index
    )
  end
end
