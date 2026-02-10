defmodule Sppa.Penempatans.Penempatan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "penempatans" do
    field :nama_sistem, :string
    field :versi, :string, default: "1.0.0"
    field :lokasi, :string
    field :jenis, :string
    field :status, :string, default: "Menunggu"
    field :persekitaran, :string
    field :tarikh_penempatan, :date
    field :tarikh_dijangka, :date
    field :url, :string
    field :catatan, :string
    field :dibina_oleh, :string
    field :disemak_oleh, :string
    field :diluluskan_oleh, :string
    field :tarikh_dibina, :date
    field :tarikh_disemak, :date
    field :tarikh_diluluskan, :date

    belongs_to :project, Sppa.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(penempatan, attrs) do
    penempatan
    |> cast(attrs, [
      :nama_sistem,
      :versi,
      :lokasi,
      :jenis,
      :status,
      :persekitaran,
      :tarikh_penempatan,
      :tarikh_dijangka,
      :url,
      :catatan,
      :dibina_oleh,
      :disemak_oleh,
      :diluluskan_oleh,
      :tarikh_dibina,
      :tarikh_disemak,
      :tarikh_diluluskan,
      :project_id
    ])
    |> validate_required([:nama_sistem, :versi, :lokasi, :tarikh_penempatan, :jenis, :status])
    |> foreign_key_constraint(:project_id)
  end
end
