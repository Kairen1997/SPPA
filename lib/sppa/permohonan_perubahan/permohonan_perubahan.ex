defmodule Sppa.PermohonanPerubahan.PermohonanPerubahan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "permohonan_perubahan" do
    field :tajuk, :string
    field :jenis, :string
    field :modul_terlibat, :string
    field :status, :string, default: "Dalam Semakan"
    field :keutamaan, :string
    field :tarikh_dibuat, :date
    field :tarikh_dijangka_siap, :date
    field :justifikasi, :string
    field :kesan, :string
    field :catatan, :string

    belongs_to :project, Sppa.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(permohonan_perubahan, attrs) do
    permohonan_perubahan
    |> cast(attrs, [
      :tajuk,
      :jenis,
      :modul_terlibat,
      :status,
      :keutamaan,
      :tarikh_dibuat,
      :tarikh_dijangka_siap,
      :justifikasi,
      :kesan,
      :catatan,
      :project_id
    ])
    |> validate_required([:tajuk, :jenis, :modul_terlibat, :tarikh_dibuat, :project_id])
    |> foreign_key_constraint(:project_id)
  end
end
