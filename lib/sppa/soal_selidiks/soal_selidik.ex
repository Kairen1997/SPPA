defmodule Sppa.SoalSelidiks.SoalSelidik do
  use Ecto.Schema
  import Ecto.Changeset

  schema "soal_selidiks" do
    field :nama_sistem, :string
    field :document_id, :string, default: "JPKN-BPA-01/B1"
    field :fr_categories, :map, default: %{}
    field :nfr_categories, :map, default: %{}
    field :fr_data, :map, default: %{}
    field :nfr_data, :map, default: %{}
    field :disediakan_oleh, :map, default: %{}
    field :custom_tabs, :map, default: %{}
    field :tabs, :map, default: %{}

    belongs_to :project, Sppa.Projects.Project, foreign_key: :project_id
    belongs_to :user, Sppa.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(soal_selidik, attrs) do
    soal_selidik
    |> cast(attrs, [
      :nama_sistem,
      :document_id,
      :fr_categories,
      :nfr_categories,
      :fr_data,
      :nfr_data,
      :disediakan_oleh,
      :custom_tabs,
      :tabs,
      :project_id
    ])
    |> validate_required([:nama_sistem, :user_id])
    |> put_default_document_id()
  end

  defp put_default_document_id(changeset) do
    case get_field(changeset, :document_id) do
      nil -> put_change(changeset, :document_id, "JPKN-BPA-01/B1")
      "" -> put_change(changeset, :document_id, "JPKN-BPA-01/B1")
      _ -> changeset
    end
  end
end
