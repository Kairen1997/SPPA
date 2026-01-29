defmodule Sppa.ProjectModules.ProjectModule do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_modules" do
    field :title, :string
    field :description, :string
    field :priority, :string
    field :status, :string, default: "in_progress"
    field :fasa, :string
    field :versi, :string
    field :due_date, :date

    belongs_to :project, Sppa.Projects.Project
    belongs_to :developer, Sppa.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(project_module, attrs) do
    project_module
    |> cast(attrs, [:title, :description, :priority, :status, :fasa, :versi, :due_date, :project_id, :developer_id])
    |> validate_required([:title, :project_id])
  end
end
