defmodule Sppa.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :nama, :string
    field :jabatan, :string
    field :status, :string
    field :fasa, :string
    field :tarikh_mula, :date
    field :tarikh_siap, :date
    field :dokumen_sokongan, :integer, default: 0
    field :last_updated, :utc_datetime

    belongs_to :approved_project, Sppa.ApprovedProjects.ApprovedProject,
      foreign_key: :approved_project_id

    belongs_to :developer, Sppa.Accounts.User, foreign_key: :developer_id
    belongs_to :project_manager, Sppa.Accounts.User, foreign_key: :project_manager_id
    belongs_to :user, Sppa.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :nama,
      :jabatan,
      :status,
      :fasa,
      :tarikh_mula,
      :tarikh_siap,
      :dokumen_sokongan,
      :last_updated,
      :developer_id,
      :project_manager_id,
      :approved_project_id
    ])
    |> validate_required([:nama])
    |> put_change(:last_updated, DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
