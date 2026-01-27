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
    changeset =
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
        :project_id,
        :user_id
      ])
      |> ensure_nama_sistem_in_changes(attrs)
      |> validate_required([:nama_sistem, :user_id])
      |> put_default_document_id()

    changeset
  end

  # Ensure nama_sistem is always in changes, even if empty, so validate_required can catch it
  # This handles the case where Ecto's cast might filter out empty strings
  defp ensure_nama_sistem_in_changes(changeset, attrs) do
    case get_change(changeset, :nama_sistem) do
      nil ->
        # If not in changes, check if it was in attrs (might have been filtered out by cast)
        # Use Map.has_key? to check existence, not just truthiness (empty string is valid)
        nama_sistem_value =
          cond do
            Map.has_key?(attrs, :nama_sistem) -> Map.get(attrs, :nama_sistem)
            Map.has_key?(attrs, "nama_sistem") -> Map.get(attrs, "nama_sistem")
            true -> nil
          end

        # Always add to changes if it was in attrs (even if empty string)
        # This ensures validate_required can properly validate it
        if nama_sistem_value != nil do
          put_change(changeset, :nama_sistem, String.trim(to_string(nama_sistem_value)))
        else
          # If not in attrs either, ensure it's in changes as empty string for validation
          put_change(changeset, :nama_sistem, "")
        end
      _ ->
        # Already in changes, no need to modify
        changeset
    end
  end

  defp put_default_document_id(changeset) do
    case get_field(changeset, :document_id) do
      nil -> put_change(changeset, :document_id, "JPKN-BPA-01/B1")
      "" -> put_change(changeset, :document_id, "JPKN-BPA-01/B1")
      _ -> changeset
    end
  end
end
