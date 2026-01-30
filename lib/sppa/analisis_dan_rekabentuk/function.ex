defmodule Sppa.AnalisisDanRekabentuk.Function do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analisis_dan_rekabentuk_functions" do
    field :name, :string

    belongs_to :analisis_dan_rekabentuk_module, Sppa.AnalisisDanRekabentuk.Module,
      foreign_key: :analisis_dan_rekabentuk_module_id

    has_many :sub_functions, Sppa.AnalisisDanRekabentuk.SubFunction,
      foreign_key: :analisis_dan_rekabentuk_function_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(function, attrs) do
    function
    |> cast(attrs, [:name, :analisis_dan_rekabentuk_module_id])
    |> ensure_non_null_name()
    |> validate_required([:analisis_dan_rekabentuk_module_id])
  end

  defp ensure_non_null_name(changeset) do
    case get_field(changeset, :name) do
      nil -> put_change(changeset, :name, "")
      _ -> changeset
    end
  end
end
