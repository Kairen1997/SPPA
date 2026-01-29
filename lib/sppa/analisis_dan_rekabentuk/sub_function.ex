defmodule Sppa.AnalisisDanRekabentuk.SubFunction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analisis_dan_rekabentuk_sub_functions" do
    field :name, :string

    belongs_to :analisis_dan_rekabentuk_function, Sppa.AnalisisDanRekabentuk.Function,
      foreign_key: :analisis_dan_rekabentuk_function_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sub_function, attrs) do
    sub_function
    |> cast(attrs, [:name, :analisis_dan_rekabentuk_function_id])
    # Benarkan nama kosong semasa pengguna masih mengisi sub-fungsi.
    |> validate_required([:analisis_dan_rekabentuk_function_id])
  end
end
