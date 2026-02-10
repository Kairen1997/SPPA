defmodule Sppa.UjianKeselamatan.UjianKeselamatan do
  @moduledoc """
  Schema for ujian keselamatan (Security Test).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "ujian_keselamatan" do
    field :tajuk, :string
    field :modul, :string
    field :tarikh_ujian, :date
    field :tarikh_dijangka_siap, :date
    field :status, :string, default: "Menunggu"
    field :penguji, :string
    field :hasil, :string, default: "Belum Selesai"
    field :disahkan_oleh, :string
    field :catatan, :string

    belongs_to :project, Sppa.Projects.Project

    belongs_to :analisis_dan_rekabentuk_module, Sppa.AnalisisDanRekabentuk.Module,
      foreign_key: :analisis_dan_rekabentuk_module_id

    has_many :kes_ujian, Sppa.UjianKeselamatan.KesUjianKeselamatan,
      foreign_key: :ujian_keselamatan_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ujian_keselamatan, attrs) do
    ujian_keselamatan
    |> cast(attrs, [
      :tajuk,
      :modul,
      :tarikh_ujian,
      :tarikh_dijangka_siap,
      :status,
      :penguji,
      :hasil,
      :disahkan_oleh,
      :catatan,
      :project_id,
      :analisis_dan_rekabentuk_module_id
    ])
    |> validate_required([:tajuk, :modul, :project_id])
    |> foreign_key_constraint(:project_id)
    |> foreign_key_constraint(:analisis_dan_rekabentuk_module_id)
  end
end
