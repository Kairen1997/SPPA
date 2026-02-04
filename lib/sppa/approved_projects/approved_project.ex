defmodule Sppa.ApprovedProjects.ApprovedProject do
  use Ecto.Schema
  import Ecto.Changeset

  schema "approved_projects" do
    field :external_application_id, :integer
    field :nama_projek, :string
    field :jabatan, :string
    field :pengurus_email, :string

    field :tarikh_mula, :date
    field :tarikh_jangkaan_siap, :date

    field :pembangun_sistem, :string

    field :latar_belakang, :string
    field :objektif, :string
    field :skop, :string
    field :kumpulan_pengguna, :string
    field :implikasi, :string

    field :kertas_kerja_path, :string
    field :external_updated_at, :utc_datetime

    has_one :project, Sppa.Projects.Project

    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:external_application_id, :nama_projek])
    |> unique_constraint(:external_application_id)
  end
end
