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
    # Benarkan nama kosong semasa pengguna masih mengisi fungsi.
    |> validate_required([:analisis_dan_rekabentuk_module_id])
  end
end
