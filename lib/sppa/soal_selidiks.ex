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
  Gets the latest soal_selidik for a project, regardless of who created it.

  This is used for project-level views (tab navigasi projek) where we want to
  show whatever soal selidik has been filled in for the project, even if it
  was created by a different user (e.g. developer mengisi, pengurus projek melihat).

  Returns nil if not found.
  """
  def get_soal_selidik_by_project_for_display(project_id, _current_scope) do
    SoalSelidik
    |> where([s], s.project_id == ^project_id)
    |> preload([:project, :user])
    |> order_by([s], desc: s.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Gets the soal_selidik for a project for display purposes.

  Prioriti:
  1. Rekod yang mempunyai `project_id` sepadan.
  2. Jika tiada, cuba padankan berdasarkan `nama_sistem` yang sama dengan nama projek.
  """
  def get_soal_selidik_for_project_or_by_name(project, current_scope) do
    require Logger
    project_id = project.id

    Logger.info(
      "get_soal_selidik_for_project_or_by_name: Looking for project_id=#{project_id}, nama=#{project.nama}"
    )

    result =
      case get_soal_selidik_by_project_for_display(project_id, current_scope) do
        %SoalSelidik{} = soal_selidik ->
          Logger.info("Found soal_selidik by project_id: ID=#{soal_selidik.id}")
          soal_selidik

        nil ->
          Logger.info(
            "No soal_selidik found by project_id, trying by nama_sistem=#{project.nama}"
          )

          result_by_name =
            SoalSelidik
            |> where([s], s.nama_sistem == ^project.nama)
            |> preload([:project, :user])
            |> order_by([s], desc: s.inserted_at)
            |> limit(1)
            |> Repo.one()

          if result_by_name do
            Logger.info("Found soal_selidik by nama_sistem: ID=#{result_by_name.id}")
          else
            Logger.info("No soal_selidik found by nama_sistem either")
          end

          result_by_name
      end

    result
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
  # Susunan Functional Requirement dari atas ke bawah (untuk normalize dari map)
  @fr_category_key_order ~w(pendaftaran_login pengurusan_data proses_kerja laporan integrasi role_akses peraturan_polisi lain_lain_ciri)
  # Susunan Non-Functional Requirement: Keselamatan, Akses/Capaian, Usability
  @nfr_category_key_order ~w(keselamatan akses_capaian usability)

  def to_liveview_format(%SoalSelidik{} = soal_selidik) do
    fr_data_normalized = normalize_data(soal_selidik.fr_data || %{})
    nfr_data_normalized = normalize_data(soal_selidik.nfr_data || %{})

    fr_categories_normalized = normalize_categories(soal_selidik.fr_categories || [], :fr)
    nfr_categories_normalized = normalize_categories(soal_selidik.nfr_categories || [], :nfr)

    # Merge questions from fr_data/nfr_data with questions from categories
    # This ensures all questions (including user-added ones) are displayed
    fr_categories_with_data =
      merge_questions_from_data(fr_categories_normalized, fr_data_normalized)

    nfr_categories_with_data =
      merge_questions_from_data(nfr_categories_normalized, nfr_data_normalized)

    %{
      id: soal_selidik.id,
      nama_sistem: soal_selidik.nama_sistem || "",
      document_id: soal_selidik.document_id || "JPKN-BPA-01/B1",
      fr_categories: fr_categories_with_data,
      nfr_categories: nfr_categories_with_data,
      fr_data: fr_data_normalized,
      nfr_data: nfr_data_normalized,
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
  defp normalize_categories(categories, _type) when is_list(categories), do: categories

  defp normalize_categories(categories, :fr) when is_map(categories) do
    order = @fr_category_key_order

    ordered =
      Enum.map(order, fn key ->
        case Map.get(categories, key) || Map.get(categories, to_string(key)) do
          nil -> nil
          c -> normalize_category(c)
        end
      end)
      |> Enum.reject(&is_nil/1)

    # Kategori dalam DB tetapi tidak dalam order (legacy) – append di hujung
    known_keys = MapSet.new(order)

    extra =
      categories
      |> Enum.reject(fn {k, _} -> MapSet.member?(known_keys, to_string(k)) end)
      |> Enum.map(fn {_, v} -> normalize_category(v) end)

    ordered ++ extra
  end

  defp normalize_categories(categories, :nfr) when is_map(categories) do
    order = @nfr_category_key_order

    ordered =
      Enum.map(order, fn key ->
        case Map.get(categories, key) || Map.get(categories, to_string(key)) do
          nil -> nil
          c -> normalize_category(c)
        end
      end)
      |> Enum.reject(&is_nil/1)

    known_keys = MapSet.new(order)

    extra =
      categories
      |> Enum.reject(fn {k, _} -> MapSet.member?(known_keys, to_string(k)) end)
      |> Enum.map(fn {_, v} -> normalize_category(v) end)

    ordered ++ extra
  end

  defp normalize_categories(_, _), do: []

  # Ensure category has :key, :title, :questions so category.key works in LiveView/templates.
  # DB stores "key"/"title"/"questions"; default uses :key etc.
  defp normalize_category(c) when is_map(c) do
    key = Map.get(c, :key) || Map.get(c, "key") || ""
    key_str = to_string(key)
    title = Map.get(c, :title) || Map.get(c, "title") || ""
    raw_questions = Map.get(c, :questions) || Map.get(c, "questions") || []
    questions = Enum.map(List.wrap(raw_questions), &normalize_question/1)

    %{
      key: key_str,
      title: title,
      questions: questions
    }
  end

  defp normalize_question(q) when is_map(q) do
    no = Map.get(q, :no) || Map.get(q, "no") || 0

    no_int =
      cond do
        is_integer(no) ->
          no

        true ->
          case Integer.parse(to_string(no)) do
            {n, _} -> n
            :error -> 0
          end
      end

    soalan = Map.get(q, :soalan) || Map.get(q, "soalan") || ""
    raw_type = Map.get(q, :type) || Map.get(q, "type") || :text
    type = to_question_type(raw_type)
    options = Map.get(q, :options) || Map.get(q, "options")
    options_list = if is_list(options), do: options, else: []

    %{
      no: no_int,
      soalan: soalan,
      type: type,
      options: options_list
    }
  end

  defp to_question_type(:text), do: :text
  defp to_question_type("text"), do: :text
  defp to_question_type(:textarea), do: :textarea
  defp to_question_type("textarea"), do: :textarea
  defp to_question_type(:select), do: :select
  defp to_question_type("select"), do: :select
  defp to_question_type(:checkbox), do: :checkbox
  defp to_question_type("checkbox"), do: :checkbox
  defp to_question_type(_), do: :text

  defp normalize_data(data) when is_map(data) do
    # Ensure all keys are strings for form display (Phoenix.Form.input_value uses "fr.category.1.soalan")
    Enum.reduce(data, %{}, fn {cat_k, cat_v}, acc ->
      cat_key = to_string(cat_k)

      cat_map =
        if is_map(cat_v) do
          Enum.reduce(cat_v, %{}, fn {qno_k, qno_v}, qacc ->
            qno_key = to_string(qno_k)
            qno_map = if is_map(qno_v), do: string_key_map(qno_v), else: qno_v
            Map.put(qacc, qno_key, qno_map)
          end)
        else
          cat_v
        end

      Map.put(acc, cat_key, cat_map)
    end)
  end

  defp normalize_data(_), do: %{}

  defp string_key_map(m) when is_map(m) do
    Enum.reduce(m, %{}, fn {k, v}, acc -> Map.put(acc, to_string(k), v) end)
  end

  defp normalize_disediakan_oleh(data) when is_map(data), do: data
  defp normalize_disediakan_oleh(_), do: %{}

  defp normalize_custom_tabs(data) when is_map(data), do: data
  defp normalize_custom_tabs(_), do: %{}

  # Ensure tabs always come back as maps with atom keys (:id, :label, :type, :removable)
  # Order: fr, nfr, disediakan_oleh, then custom tabs
  @default_tab_order ~w(fr nfr disediakan_oleh)

  defp normalize_tabs(tabs) when is_list(tabs) do
    tabs
    |> Enum.map(&normalize_tab/1)
    |> sort_tabs_by_order()
  end

  defp normalize_tabs(tabs) when is_map(tabs) do
    tabs
    |> Map.values()
    |> Enum.map(&normalize_tab/1)
    |> sort_tabs_by_order()
  end

  defp normalize_tabs(_), do: []

  # Sort tabs: default tabs first (fr, nfr, disediakan_oleh), then custom tabs
  defp sort_tabs_by_order(tabs) do
    # Separate default and custom tabs
    {default_tabs, custom_tabs} =
      Enum.split_with(tabs, fn tab ->
        tab.type == :default || tab.type == "default"
      end)

    # Sort default tabs by predefined order
    sorted_default_tabs =
      Enum.sort_by(default_tabs, fn tab ->
        id_string = to_string(tab.id)

        case Enum.find_index(@default_tab_order, &(&1 == id_string)) do
          # Put unknown default tabs at the end
          nil -> 999
          index -> index
        end
      end)

    # Sort custom tabs by id (alphabetically)
    sorted_custom_tabs = Enum.sort_by(custom_tabs, & &1.id)

    # Combine: default tabs first, then custom tabs
    sorted_default_tabs ++ sorted_custom_tabs
  end

  defp normalize_tab(tab) when is_map(tab) do
    id = Map.get(tab, :id) || Map.get(tab, "id")
    label = Map.get(tab, :label) || Map.get(tab, "label")
    removable = Map.get(tab, :removable) || Map.get(tab, "removable") || false

    raw_type = Map.get(tab, :type) || Map.get(tab, "type") || :default

    type =
      case raw_type do
        t when is_atom(t) -> t
        "default" -> :default
        "custom" -> :custom
        other -> other
      end

    %{
      id: id,
      label: label,
      removable: removable,
      type: type
    }
  end

  # Merge questions from data (fr_data/nfr_data) with questions from categories
  # This ensures all questions are displayed, including user-added ones that may not be in category structure
  defp merge_questions_from_data(categories, data) when is_list(categories) and is_map(data) do
    Enum.map(categories, fn category ->
      category_key = category.key
      category_key_str = to_string(category_key)

      # Try both atom and string keys
      category_data =
        Map.get(data, category_key, %{}) ||
          Map.get(data, category_key_str, %{}) ||
          %{}

      # Only process if category_data is a map
      if is_map(category_data) do
        # Get existing questions from category
        existing_questions = category.questions || []

        # Get question numbers that exist in category.questions
        existing_question_nos =
          existing_questions
          |> Enum.map(& &1.no)
          |> MapSet.new()

        # Find questions in data that are not in category.questions
        additional_questions =
          category_data
          |> Enum.filter(fn {qno_str, qdata} ->
            # Only include if qdata is a map (valid question data)
            is_map(qdata) &&
              case Integer.parse(to_string(qno_str)) do
                {qno, _} -> not MapSet.member?(existing_question_nos, qno)
                :error -> false
              end
          end)
          |> Enum.map(fn {qno_str, qdata} ->
            # Extract soalan from data if available
            soalan =
              Map.get(qdata, "soalan") ||
                Map.get(qdata, :soalan) ||
                ""

            # Parse question number (we know it's valid from filter above)
            {qno, _} = Integer.parse(to_string(qno_str))

            %{
              no: qno,
              soalan: soalan,
              type: :text,
              options: []
            }
          end)
          |> Enum.sort_by(& &1.no)

        # Combine existing and additional questions, sorted by question number
        all_questions = (existing_questions ++ additional_questions) |> Enum.sort_by(& &1.no)

        Map.put(category, :questions, all_questions)
      else
        # If category_data is not a map, return category as-is
        category
      end
    end)
  end

  defp merge_questions_from_data(categories, _data), do: categories
end
