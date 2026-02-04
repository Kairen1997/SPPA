defmodule Sppa.AnalisisDanRekabentuk.AnalisisDanRekabentuk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analisis_dan_rekabentuk" do
    field :document_id, :string, default: "JPKN-BPA-01/B2"
    field :nama_projek, :string
    field :nama_agensi, :string
    field :versi, :string
    field :tarikh_semakan, :date
    field :rujukan_perubahan, :string

    # Prepared by section
    field :prepared_by_name, :string
    field :prepared_by_position, :string
    field :prepared_by_date, :date

    # Approved by section
    field :approved_by_name, :string
    field :approved_by_position, :string
    field :approved_by_date, :date

    belongs_to :project, Sppa.Projects.Project, foreign_key: :project_id
    belongs_to :user, Sppa.Accounts.User

    has_many :modules, Sppa.AnalisisDanRekabentuk.Module, foreign_key: :analisis_dan_rekabentuk_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(analisis_dan_rekabentuk, attrs) do
    analisis_dan_rekabentuk
    |> cast(attrs, [
      :document_id,
      :nama_projek,
      :nama_agensi,
      :versi,
      :tarikh_semakan,
      :rujukan_perubahan,
      :prepared_by_name,
      :prepared_by_position,
      :prepared_by_date,
      :approved_by_name,
      :approved_by_position,
      :approved_by_date,
      :project_id,
      :user_id
    ])
    |> validate_required([:user_id])
    |> put_default_document_id()
  end

  defp put_default_document_id(changeset) do
    case get_field(changeset, :document_id) do
      nil -> put_change(changeset, :document_id, "JPKN-BPA-01/B2")
      "" -> put_change(changeset, :document_id, "JPKN-BPA-01/B2")
      _ -> changeset
    end
  end
end
