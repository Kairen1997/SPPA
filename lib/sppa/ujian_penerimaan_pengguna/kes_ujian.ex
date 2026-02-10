defmodule Sppa.UjianPenerimaanPengguna.KesUjian do
  @moduledoc """
  Schema for kes ujian (test case) within ujian penerimaan pengguna.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "kes_ujian_penerimaan_pengguna" do
    field :kod, :string
    field :senario, :string
    field :langkah, :string
    field :keputusan_dijangka, :string
    field :keputusan_sebenar, :string
    field :hasil, :string
    field :penguji, :string
    field :tarikh_ujian, :date
    field :disahkan_oleh, :string
    field :tarikh_pengesahan, :date

    belongs_to :ujian_penerimaan_pengguna, Sppa.UjianPenerimaanPengguna.UjianPenerimaanPengguna

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kes_ujian, attrs) do
    kes_ujian
    |> cast(attrs, [
      :kod,
      :senario,
      :langkah,
      :keputusan_dijangka,
      :keputusan_sebenar,
      :hasil,
      :penguji,
      :tarikh_ujian,
      :disahkan_oleh,
      :tarikh_pengesahan,
      :ujian_penerimaan_pengguna_id
    ])
    |> validate_required([:kod, :senario, :ujian_penerimaan_pengguna_id])
    |> foreign_key_constraint(:ujian_penerimaan_pengguna_id)
  end
end
