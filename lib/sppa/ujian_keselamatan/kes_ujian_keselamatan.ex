defmodule Sppa.UjianKeselamatan.KesUjianKeselamatan do
  @moduledoc """
  Schema for kes ujian (test case) within ujian keselamatan.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "kes_ujian_keselamatan" do
    field :kod, :string
    field :senario, :string
    field :langkah, :string
    field :keputusan_dijangka, :string
    field :keputusan_sebenar, :string
    field :hasil, :string
    field :penguji, :string
    field :tarikh_ujian, :date
    field :disahkan, :boolean, default: false
    field :disahkan_oleh, :string
    field :tarikh_pengesahan, :date

    belongs_to :ujian_keselamatan, Sppa.UjianKeselamatan.UjianKeselamatan,
      foreign_key: :ujian_keselamatan_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(kes_ujian_keselamatan, attrs) do
    kes_ujian_keselamatan
    |> cast(attrs, [
      :kod,
      :senario,
      :langkah,
      :keputusan_dijangka,
      :keputusan_sebenar,
      :hasil,
      :penguji,
      :tarikh_ujian,
      :disahkan,
      :disahkan_oleh,
      :tarikh_pengesahan,
      :ujian_keselamatan_id
    ])
    |> validate_required([:kod, :ujian_keselamatan_id])
    |> foreign_key_constraint(:ujian_keselamatan_id)
  end
end
