defmodule Sppa.SoalSelidiks do
  @moduledoc """
  The SoalSelidiks context.
  """

  import Ecto.Query, warn: false
  alias Sppa.Repo
  alias Sppa.SoalSelidiks.SoalSelidik

  @doc """
  Returns the list of soal_selidiks for a user scope.
  """
  def list_soal_selidiks(current_scope) do
    SoalSelidik
    |> where([s], s.user_id == ^current_scope.user.id)
    |> preload([:project, :user])
    |> order_by([s], desc: s.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single soal_selidik.

  Raises `Ecto.NoResultsError` if the Soal Selidik does not exist.
  """
  def get_soal_selidik!(id, current_scope) do
    SoalSelidik
    |> where([s], s.id == ^id and s.user_id == ^current_scope.user.id)
    |> preload([:project, :user])
    |> Repo.one!()
  end

  @doc """
  Gets a single soal_selidik by project_id.

  Returns nil if not found.
  """
  def get_soal_selidik_by_project(project_id, current_scope) do
    SoalSelidik
    |> where([s], s.project_id == ^project_id and s.user_id == ^current_scope.user.id)
    |> preload([:project, :user])
    |> Repo.one()
  end

  @doc """
  Creates a soal_selidik.
  """
  def create_soal_selidik(attrs, current_scope) do
    # user_id should already be in attrs, but ensure it's set if missing
    attrs = Map.put_new(attrs, :user_id, current_scope.user.id)

    %SoalSelidik{}
    |> SoalSelidik.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a soal_selidik.
  """
  def update_soal_selidik(%SoalSelidik{} = soal_selidik, attrs) do
    soal_selidik
    |> SoalSelidik.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a soal_selidik.
  """
  def delete_soal_selidik(%SoalSelidik{} = soal_selidik) do
    Repo.delete(soal_selidik)
  end

  @doc """
  Converts a soal_selidik from database to the format expected by the LiveView.
  """
  def to_liveview_format(%SoalSelidik{} = soal_selidik) do
    %{
      id: soal_selidik.id,
      nama_sistem: soal_selidik.nama_sistem || "",
      document_id: soal_selidik.document_id || "JPKN-BPA-01/B1",
      fr_categories: normalize_categories(soal_selidik.fr_categories || []),
      nfr_categories: normalize_categories(soal_selidik.nfr_categories || []),
      fr_data: normalize_data(soal_selidik.fr_data || %{}),
      nfr_data: normalize_data(soal_selidik.nfr_data || %{}),
      disediakan_oleh: normalize_disediakan_oleh(soal_selidik.disediakan_oleh || %{}),
      custom_tabs: normalize_custom_tabs(soal_selidik.custom_tabs || %{}),
      tabs: normalize_tabs(soal_selidik.tabs || [])
    }
  end

  @doc """
  Converts LiveView format to database format.
  """
  def from_liveview_format(attrs) do
    %{
      nama_sistem: Map.get(attrs, :nama_sistem, ""),
      document_id: Map.get(attrs, :document_id, "JPKN-BPA-01/B1"),
      fr_categories: Map.get(attrs, :fr_categories, []),
      nfr_categories: Map.get(attrs, :nfr_categories, []),
      fr_data: Map.get(attrs, :fr_data, %{}),
      nfr_data: Map.get(attrs, :nfr_data, %{}),
      disediakan_oleh: Map.get(attrs, :disediakan_oleh, %{}),
      custom_tabs: Map.get(attrs, :custom_tabs, %{}),
      tabs: Map.get(attrs, :tabs, [])
    }
  end

  # Helper functions to normalize data structures
  defp normalize_categories(categories) when is_list(categories), do: categories
  defp normalize_categories(categories) when is_map(categories) do
    categories
    |> Map.values()
    |> Enum.sort_by(&Map.get(&1, :key, ""))
  end
  defp normalize_categories(_), do: []

  defp normalize_data(data) when is_map(data), do: data
  defp normalize_data(_), do: %{}

  defp normalize_disediakan_oleh(data) when is_map(data), do: data
  defp normalize_disediakan_oleh(_), do: %{}

  defp normalize_custom_tabs(data) when is_map(data), do: data
  defp normalize_custom_tabs(_), do: %{}

  defp normalize_tabs(tabs) when is_list(tabs), do: tabs
  defp normalize_tabs(tabs) when is_map(tabs) do
    tabs
    |> Map.values()
    |> Enum.sort_by(&Map.get(&1, :id, ""))
  end
  defp normalize_tabs(_), do: []
end
