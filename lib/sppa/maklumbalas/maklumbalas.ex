defmodule Sppa.Maklumbalas.Maklumbalas do
  @moduledoc """
  Schema untuk rekod maklumbalas pelanggan bagi sesuatu projek.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "maklumbalas" do
    field :tarikh_maklumbalas, :date
    field :jabatan, :string
    field :responden, :string
    field :butiran, :string

    belongs_to :project, Sppa.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(maklumbalas, attrs) do
    maklumbalas
    |> cast(attrs, [:tarikh_maklumbalas, :jabatan, :responden, :butiran, :project_id])
    |> validate_required([:project_id])
    |> foreign_key_constraint(:project_id)
  end
end
