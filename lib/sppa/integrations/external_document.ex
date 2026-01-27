defmodule Sppa.Integrations.ExternalDocument do
  use Ecto.Schema
  import Ecto.Changeset

  schema "external_documents" do
    field :"\\", :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(external_document, attrs, user_scope) do
    external_document
    |> cast(attrs, [:"\\"])
    |> validate_required([:"\\"])
    |> put_change(:user_id, user_scope.user.id)
  end
end
