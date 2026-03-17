defmodule Sppa.UjianPenerimaanPengguna.UjianPenerimaanPengguna do
  @moduledoc """
  Schema for ujian penerimaan pengguna (User Acceptance Test).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "ujian_penerimaan_pengguna" do
    field :tajuk, :string
    field :modul, :string
    field :no_ujian, :string
    field :tarikh_ujian, :date
    field :tarikh_dijangka_siap, :date
    field :status, :string, default: "Menunggu"
    field :penguji, :string
    field :hasil, :string, default: "Belum Selesai"
    field :catatan, :string
    field :dokumen_ujian, :string
    field :dokumen_ujian_nama, :string
    field :extra_columns, :string, default: "[]"

    belongs_to :project, Sppa.Projects.Project
    has_many :kes_ujian, Sppa.UjianPenerimaanPengguna.KesUjian

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ujian_penerimaan_pengguna, attrs) do
    ujian_penerimaan_pengguna
    |> cast(attrs, [
      :tajuk,
      :modul,
      :no_ujian,
      :tarikh_ujian,
      :tarikh_dijangka_siap,
      :status,
      :penguji,
      :hasil,
      :catatan,
      :dokumen_ujian,
      :dokumen_ujian_nama,
      :project_id
    ])
    |> validate_required([:tajuk, :modul, :tarikh_ujian, :tarikh_dijangka_siap, :project_id])
    |> foreign_key_constraint(:project_id)
  end
end
