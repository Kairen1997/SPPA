defmodule Sppa.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :name, :string
    field :status, :string
    field :last_updated, :utc_datetime
    belongs_to :developer, Sppa.Accounts.User, foreign_key: :developer_id
    belongs_to :project_manager, Sppa.Accounts.User, foreign_key: :project_manager_id
    belongs_to :user, Sppa.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :status, :last_updated, :developer_id, :project_manager_id])
    |> validate_required([:name, :status])
    |> put_change(:last_updated, DateTime.utc_now())
  end
end
