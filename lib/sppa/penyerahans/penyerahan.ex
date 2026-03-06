defmodule Sppa.Penyerahans.Penyerahan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "penyerahans" do
    field :nama_sistem, :string
    field :versi, :string
    field :penerima, :string
    field :pengurus_projek, :string
    field :tarikh_penyerahan, :date
    field :manual_pengguna, :string
    field :manual_pengguna_nama, :string
    field :surat_akuan_penerimaan, :string
    field :surat_akuan_nama, :string

    belongs_to :project, Sppa.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(penyerahan, attrs) do
    penyerahan
    |> cast(attrs, [
      :nama_sistem,
      :versi,
      :penerima,
      :pengurus_projek,
      :tarikh_penyerahan,
      :manual_pengguna,
      :manual_pengguna_nama,
      :surat_akuan_penerimaan,
      :surat_akuan_nama,
      :project_id
    ])
    |> validate_required([:project_id])
    |> foreign_key_constraint(:project_id)
  end
end
