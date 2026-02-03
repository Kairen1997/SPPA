defmodule Sppa.AnalisisDanRekabentuk.Module do
  use Ecto.Schema
  import Ecto.Changeset

  schema "analisis_dan_rekabentuk_modules" do
    field :number, :integer
    field :name, :string

    belongs_to :analisis_dan_rekabentuk, Sppa.AnalisisDanRekabentuk.AnalisisDanRekabentuk,
      foreign_key: :analisis_dan_rekabentuk_id

    has_many :functions, Sppa.AnalisisDanRekabentuk.Function,
      foreign_key: :analisis_dan_rekabentuk_module_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(module, attrs) do
    module
    |> cast(attrs, [:number, :name, :analisis_dan_rekabentuk_id])
    # Pastikan kolum `name` tidak NULL di DB – guna "" jika tiada.
    |> ensure_non_null_name()
    # Benarkan nama kosong semasa pengguna masih mengisi borang.
    # Kita hanya paksa nombor dan hubungan parent supaya deraf kekal.
    |> validate_required([:number, :analisis_dan_rekabentuk_id])
  end

  defp ensure_non_null_name(changeset) do
    case get_field(changeset, :name) do
      nil -> put_change(changeset, :name, "")
      _ -> changeset
    end
  end
end
