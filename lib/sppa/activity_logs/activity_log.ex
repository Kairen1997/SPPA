defmodule Sppa.ActivityLogs.ActivityLog do
  @moduledoc """
  Schema for activity/audit log entries.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :integer
    field :resource_name, :string
    field :details, :string

    belongs_to :actor, Sppa.Accounts.User, foreign_key: :actor_id

    timestamps(type: :utc_datetime)
  end

  @required [:actor_id, :action, :resource_type, :resource_id, :resource_name]
  @optional [:details]

  @doc false
  def changeset(activity_log, attrs) do
    activity_log
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:actor_id)
  end
end
