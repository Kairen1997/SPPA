defmodule SppaWeb.SoalSelidikLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.SoalSelidiks

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  # Functional Requirements Categories
  @fr_categories [
    %{
      key: "pendaftaran_login",
      title: "Pendaftaran & Login",
      questions: []
    },
    %{
      key: "pengurusan_data",
      title: "Pengurusan Data",
      questions: []
    },
    %{
      key: "proses_kerja",
      title: "Proses Kerja",
      questions: []
    },
    %{
      key: "laporan",
      title: "Laporan",
      questions: []
    },
    %{
      key: "integrasi",
      title: "Integrasi",
      questions: []
    },
    %{
      key: "role_akses",
      title: "Role & Akses",
      questions: []
    },
    %{
      key: "peraturan_polisi",
      title: "Peraturan / Polisi",
      questions: []
    },
    %{
      key: "lain_lain_ciri",
      title: "Lain-lain Ciri Fungsian",
      questions: []
    }
  ]

  # Non-Functional Requirements Categories
  @nfr_categories [
    %{
      key: "keselamatan",
      title: "Keselamatan",
      questions: []
    },
    %{
      key: "akses_capaian",
      title: "Akses / Capaian",
      questions: []
    },
    %{
      key: "usability",
      title: "Usability",
      questions: []
    }
  ]

  @impl true
  def mount(params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Initialize default tabs
      default_tabs = [
        %{id: "fr", label: "Functional Requirement", type: :default, removable: false},
        %{id: "nfr", label: "Non-Functional Requirement", type: :default, removable: false},
        %{id: "disediakan_oleh", label: "Disediakan Oleh", type: :default, removable: false}
      ]

      # Try to load existing soal selidik if ID is provided
      {soal_selidik_id, initial_data} = load_initial_data(params, socket)

      # Load project information
      project = load_project_info(params, socket, soal_selidik_id, initial_data)
      project_name = if project, do: project.nama, else: ""

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Soal Selidik")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/soal-selidik")
        |> assign(:soal_selidik_id, soal_selidik_id)
        |> assign(:project, project)
        |> assign(:project_name, project_name)
        |> assign(:document_id, initial_data.document_id)
        |> assign(:system_name, initial_data.nama_sistem)
        |> assign(:active_tab, "fr")
        |> assign(:tabs, initial_data.tabs || default_tabs)
        |> assign(:fr_categories, initial_data.fr_categories || @fr_categories)
        |> assign(:nfr_categories, initial_data.nfr_categories || @nfr_categories)
        |> assign(:form, to_form(ensure_map(initial_data.form_data), as: :soal_selidik))
        |> assign(:show_pdf_modal, false)
        |> assign(:pdf_data, nil)
        |> assign(:show_edit_question_modal, false)
        |> assign(:selected_question, nil)
        |> assign(:edit_question_form, to_form(%{}, as: :edit_question))

      if connected?(socket) do
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
        notifications_count = length(activities)

        {:ok,
         socket
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        {:ok,
         socket
         |> assign(:activities, [])
         |> assign(:notifications_count, 0)}
      end
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "Anda tidak mempunyai kebenaran untuk mengakses halaman ini."
        )
        |> Phoenix.LiveView.redirect(to: ~p"/users/log-in")

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end

  @impl true
  def handle_event("close_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, false)}
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply,
     socket
     |> update(:notifications_open, &(!&1))
     |> assign(:profile_menu_open, false)}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
  end

  @impl true
  def handle_event("toggle_profile_menu", _params, socket) do
    {:noreply,
     socket
     |> update(:profile_menu_open, &(!&1))
     |> assign(:notifications_open, false)}
  end

  @impl true
  def handle_event("close_profile_menu", _params, socket) do
    {:noreply, assign(socket, :profile_menu_open, false)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("validate", %{"soal_selidik" => params}, socket) do
    try do
      # Get existing form data to preserve user input
      # Handle both map source and changeset source
      existing_form_data =
        case socket.assigns.form.source do
          %{params: form_params} when is_map(form_params) ->
            form_params
          source when is_map(source) ->
            source
          _ ->
            %{}
        end

      existing_soal_selidik = Map.get(existing_form_data, "soal_selidik", %{})

      # Deep merge: preserve existing user input, then add new params
      # This ensures user input is never lost
      # Start with existing (to preserve all fields), then merge new params on top
      merged_params = deep_merge_params(existing_soal_selidik, params)

      # Merge soalan from categories (only if not already in params)
      params_with_soalan = merge_soalan_from_categories(merged_params, socket.assigns.fr_categories, socket.assigns.nfr_categories)

      # Ensure the params structure is complete (but preserve existing values)
      final_params = ensure_complete_params(params_with_soalan, socket.assigns.fr_categories, socket.assigns.nfr_categories)

      # Create form with the merged params - this will be used to render input values
      form = to_form(final_params, as: :soal_selidik)
      {:noreply, assign(socket, form: form)}
    rescue
      e ->
        # Log error but don't crash - return current form state
        require Logger
        Logger.error("Error in validate: #{inspect(e)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # Fallback for validate events without soal_selidik params
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"soal_selidik" => params}, socket) do
    require Logger

    # Check if current_scope exists
    unless socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Sesi anda telah tamat. Sila log masuk semula.")}
    else
      # Log incoming params for debugging
      Logger.info("Save event received with params: #{inspect(params, limit: :infinity)}")

      # Prepare data for saving
      attrs = prepare_save_data(params, socket)

      # Add user_id to attrs for changeset validation
      attrs = Map.put(attrs, :user_id, socket.assigns.current_scope.user.id)

      # Log the attrs for debugging
      Logger.info("Attempting to save soal selidik with attrs: #{inspect(attrs, limit: :infinity)}")
      Logger.info("nama_sistem in attrs: #{inspect(Map.get(attrs, :nama_sistem))}")
      Logger.info("nama_sistem key exists: #{inspect(Map.has_key?(attrs, :nama_sistem))}")

      result =
        case socket.assigns.soal_selidik_id do
          nil ->
            # Create new
            SoalSelidiks.create_soal_selidik(attrs, socket.assigns.current_scope)

          id ->
            # Update existing
            soal_selidik = SoalSelidiks.get_soal_selidik!(id, socket.assigns.current_scope)
            SoalSelidiks.update_soal_selidik(soal_selidik, attrs)
        end

      case result do
        {:ok, soal_selidik} ->
          socket =
            socket
            |> assign(:soal_selidik_id, soal_selidik.id)
            |> assign(:form, to_form(params, as: :soal_selidik))
            |> Phoenix.LiveView.put_flash(:info, "Soal selidik telah disimpan dengan jayanya.")

          {:noreply, socket}

        {:error, changeset} ->
          # Log the actual errors
          Logger.error("Failed to save soal selidik. Errors: #{inspect(changeset.errors)}")
          Logger.error("Changeset changes: #{inspect(changeset.changes)}")
          Logger.error("Changeset data: #{inspect(changeset.data)}")

          # Build detailed error message
          error_message =
            if changeset.errors != [] do
              errors =
                Enum.map(changeset.errors, fn {field, {msg, _}} ->
                  "#{field}: #{msg}"
                end)
              "Ralat: #{Enum.join(errors, ", ")}"
            else
              "Ralat semasa menyimpan soal selidik. Sila cuba lagi."
            end

          socket =
            socket
            |> assign(:form, to_form(params, as: :soal_selidik))
            |> Phoenix.LiveView.put_flash(:error, error_message)

          {:noreply, socket}
      end
    end
  end

  @impl true
  def handle_event("generate_pdf", _params, socket) do
    {:noreply,
      socket
     |> assign(:show_pdf_modal, false)
     |> assign(:pdf_data, nil)}
  end

  @impl true
  def handle_event("close_pdf_modal", _params, socket) do
    {:noreply,
      socket
     |> assign(:show_pdf_modal, false)
     |> assign(:pdf_data, nil)}
  end

  @impl true
  def handle_event("add_question", %{"tab_type" => tab_type, "category_key" => category_key}, socket) do
    # Find the category and add a new question
    categories =
      case tab_type do
        "fr" -> socket.assigns.fr_categories
        "nfr" -> socket.assigns.nfr_categories
        _ -> []
      end

    updated_categories =
      Enum.map(categories, fn category ->
        if category.key == category_key do
          # Determine next question number
          next_no =
            case category.questions do
              [] -> 1
              questions -> (Enum.max_by(questions, & &1.no).no || 0) + 1
            end

          # Create new question with default values
          new_question = %{
            no: next_no,
            soalan: "",
            type: :text
          }

          updated_questions = category.questions ++ [new_question]
          Map.put(category, :questions, updated_questions)
        else
          category
        end
      end)

    socket =
      case tab_type do
        "fr" ->
          assign(socket, :fr_categories, updated_categories)
        "nfr" ->
          assign(socket, :nfr_categories, updated_categories)
        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_question_text", %{"soal_selidik" => soal_selidik_params} = params, socket) do
    # This handler is kept for backward compatibility
    # But now soalan input uses phx-change="validate" which handles form updates
    # So we just update the categories to keep them in sync
    tab_type = Map.get(params, "tab_type")
    category_key = Map.get(params, "category_key")
    question_no = Map.get(params, "question_no")

    # Get the value from the form params
    soalan_value = get_in(soal_selidik_params, [tab_type, category_key, question_no, "soalan"]) || ""

    categories =
      case tab_type do
        "fr" -> socket.assigns.fr_categories
        "nfr" -> socket.assigns.nfr_categories
        _ -> []
      end

    updated_categories =
      Enum.map(categories, fn category ->
        if category.key == category_key do
          updated_questions =
            Enum.map(category.questions, fn question ->
              if to_string(question.no) == to_string(question_no) do
                Map.put(question, :soalan, soalan_value)
              else
                question
              end
            end)
          Map.put(category, :questions, updated_questions)
        else
          category
        end
      end)

    # Get existing form data to preserve other fields
    existing_form_data =
      case socket.assigns.form.source do
        %{params: form_params} when is_map(form_params) ->
          form_params
        source when is_map(source) ->
          source
        _ ->
          %{}
      end

    existing_soal_selidik = Map.get(existing_form_data, "soal_selidik", %{})

    # Merge new params with existing to preserve all data
    merged_params = deep_merge_params(existing_soal_selidik, soal_selidik_params)

    # Merge soalan from categories
    params_with_soalan = merge_soalan_from_categories(merged_params, socket.assigns.fr_categories, socket.assigns.nfr_categories)

    # Ensure complete structure
    final_params = ensure_complete_params(params_with_soalan, socket.assigns.fr_categories, socket.assigns.nfr_categories)

    # Update form
    updated_form = to_form(final_params, as: :soal_selidik)

    socket =
      case tab_type do
        "fr" ->
          socket
          |> assign(:fr_categories, updated_categories)
          |> assign(:form, updated_form)
        "nfr" ->
          socket
          |> assign(:nfr_categories, updated_categories)
          |> assign(:form, updated_form)
        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_question_text", _params, socket) do
    # Fallback if params don't have the expected structure
    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_question", %{"tab_type" => tab_type, "category_key" => category_key, "question_no" => question_no}, socket) do
    # Find the question to edit
    categories =
      case tab_type do
        "fr" -> socket.assigns.fr_categories
        "nfr" -> socket.assigns.nfr_categories
        _ -> []
      end

    question =
      categories
      |> Enum.find(&(&1.key == category_key))
      |> then(fn category ->
        if category do
          Enum.find(category.questions, fn q -> to_string(q.no) == to_string(question_no) end)
        else
          nil
        end
      end)

    if question do
      # Create form with question data
      type_str =
        case question.type do
          :text -> "text"
          :textarea -> "textarea"
          :select -> "select"
          :checkbox -> "checkbox"
          _ -> "text"
        end

      options_str =
        if question.options && length(question.options) > 0 do
          Enum.join(question.options, "\n")
        else
          ""
        end

      form_data = %{
        "soalan" => question.soalan || "",
        "type" => type_str,
        "options" => options_str
      }

      form = to_form(form_data, as: :edit_question)

      {:noreply,
       socket
       |> assign(:show_edit_question_modal, true)
       |> assign(:selected_question, %{
         tab_type: tab_type,
         category_key: category_key,
         question_no: question_no,
         question: question
       })
       |> assign(:edit_question_form, form)}
    else
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Soalan tidak ditemui.")}
    end
  end

  @impl true
  def handle_event("close_edit_question_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_question_modal, false)
     |> assign(:selected_question, nil)
     |> assign(:edit_question_form, to_form(%{}, as: :edit_question))}
  end

  @impl true
  def handle_event("validate_edit_question", %{"edit_question" => edit_question_params}, socket) do
    form = to_form(edit_question_params, as: :edit_question)
    {:noreply, assign(socket, :edit_question_form, form)}
  end

  @impl true
  def handle_event("save_edit_question", %{"edit_question" => edit_question_params}, socket) do
    selected = socket.assigns.selected_question

    if selected do
      tab_type = selected.tab_type
      category_key = selected.category_key
      question_no = selected.question_no

      soalan = Map.get(edit_question_params, "soalan", "") |> String.trim()
      type_str = Map.get(edit_question_params, "type", "text")

      # Safely convert string to atom
      type =
        case type_str do
          "text" -> :text
          "textarea" -> :textarea
          "select" -> :select
          "checkbox" -> :checkbox
          _ -> :text
        end

      options_str = Map.get(edit_question_params, "options", "") |> String.trim()

      options =
        if options_str != "" do
          options_str
          |> String.split("\n")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        else
          nil
        end

      categories =
        case tab_type do
          "fr" -> socket.assigns.fr_categories
          "nfr" -> socket.assigns.nfr_categories
          _ -> []
        end

      updated_categories =
        Enum.map(categories, fn category ->
          if category.key == category_key do
            updated_questions =
              Enum.map(category.questions, fn question ->
                if to_string(question.no) == to_string(question_no) do
                  question
                  |> Map.put(:soalan, soalan)
                  |> Map.put(:type, type)
                  |> then(fn q ->
                    if options do
                      Map.put(q, :options, options)
                    else
                      Map.delete(q, :options)
                    end
                  end)
                else
                  question
                end
              end)
            Map.put(category, :questions, updated_questions)
          else
            category
          end
        end)

      socket =
        case tab_type do
          "fr" ->
            assign(socket, :fr_categories, updated_categories)
          "nfr" ->
            assign(socket, :nfr_categories, updated_categories)
          _ ->
            socket
        end

      {:noreply,
       socket
       |> assign(:show_edit_question_modal, false)
       |> assign(:selected_question, nil)
       |> assign(:edit_question_form, to_form(%{}, as: :edit_question))
       |> Phoenix.LiveView.put_flash(:info, "Soalan telah dikemaskini.")}
    else
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Ralat: Soalan tidak ditemui.")}
    end
  end

  @impl true
  def handle_event("save_row", params, socket) do
    try do
      # Get parameters from phx-value attributes
      tab_type = Map.get(params, "tab_type")
      category_key = Map.get(params, "category_key")
      question_no = Map.get(params, "question_no")

      if is_nil(tab_type) || is_nil(category_key) || is_nil(question_no) do
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:error, "Data tidak lengkap. Sila cuba lagi.")}
      else
        # Get form data from socket assigns (form is already updated with user input)
        form_data = socket.assigns.form.source.params || %{}
        soal_selidik_params = Map.get(form_data, "soal_selidik", %{})

        # Get data for this specific row
        row_data = get_in(soal_selidik_params, [tab_type, category_key, question_no]) || %{}

        # Update the question in categories with the form data
        categories =
          case tab_type do
            "fr" -> socket.assigns.fr_categories || []
            "nfr" -> socket.assigns.nfr_categories || []
            _ -> []
          end

        updated_categories =
          Enum.map(categories, fn category ->
            if category.key == category_key do
              updated_questions =
                Enum.map(category.questions || [], fn question ->
                  if to_string(question.no) == to_string(question_no) do
                    question
                    |> Map.put(:soalan, Map.get(row_data, "soalan", question.soalan || ""))
                    |> Map.put(:maklumbalas, Map.get(row_data, "maklumbalas", ""))
                    |> Map.put(:catatan, Map.get(row_data, "catatan", ""))
                  else
                    question
                  end
                end)
              Map.put(category, :questions, updated_questions)
            else
              category
            end
          end)

        socket =
          case tab_type do
            "fr" ->
              assign(socket, :fr_categories, updated_categories)
            "nfr" ->
              assign(socket, :nfr_categories, updated_categories)
            _ ->
              socket
          end

        # Merge with existing form data
        existing_form_data = socket.assigns.form.source.params || %{}
        existing_soal_selidik = Map.get(existing_form_data, "soal_selidik", %{})

        # Merge the new data with existing data
        merged_soal_selidik =
          existing_soal_selidik
          |> Map.put(tab_type, Map.merge(Map.get(existing_soal_selidik, tab_type, %{}), Map.get(soal_selidik_params, tab_type, %{})))

        # Update form with merged data
        updated_form_data = Map.put(existing_form_data, "soal_selidik", merged_soal_selidik)

        # Save to database
        attrs = prepare_save_data(merged_soal_selidik, socket)

        result =
          case socket.assigns.soal_selidik_id do
            nil ->
              # Create new
              SoalSelidiks.create_soal_selidik(attrs, socket.assigns.current_scope)

            id ->
              # Update existing
              try do
                soal_selidik = SoalSelidiks.get_soal_selidik!(id, socket.assigns.current_scope)
                SoalSelidiks.update_soal_selidik(soal_selidik, attrs)
              rescue
                Ecto.NoResultsError ->
                  # If not found, create new
                  SoalSelidiks.create_soal_selidik(attrs, socket.assigns.current_scope)
              end
          end

        case result do
          {:ok, soal_selidik} ->
            socket =
              socket
              |> assign(:soal_selidik_id, soal_selidik.id)
              |> assign(:form, to_form(updated_form_data, as: :soal_selidik))
              |> Phoenix.LiveView.put_flash(:info, "Baris #{question_no} telah disimpan dengan jayanya.")

            {:noreply, socket}

          {:error, changeset} ->
            error_message =
              if changeset.errors != [] do
                errors = Enum.map(changeset.errors, fn {field, {msg, _}} -> "#{field}: #{msg}" end)
                "Ralat: #{Enum.join(errors, ", ")}"
              else
                "Ralat semasa menyimpan baris #{question_no}. Sila cuba lagi."
              end

            {:noreply,
             socket
             |> Phoenix.LiveView.put_flash(:error, error_message)}
        end
      end
    rescue
      e ->
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(
           :error,
           "Ralat tidak dijangka: #{Exception.message(e)}"
         )}
    end
  end

  @impl true
  def handle_event("delete_question", %{"tab_type" => tab_type, "category_key" => category_key, "question_no" => question_no}, socket) do
    # Find the category and remove the question
    categories =
      case tab_type do
        "fr" -> socket.assigns.fr_categories
        "nfr" -> socket.assigns.nfr_categories
        _ -> []
      end

    updated_categories =
      Enum.map(categories, fn category ->
        if category.key == category_key do
          # Compare as strings since question_no comes from phx-value as string
          updated_questions =
            Enum.reject(category.questions, fn question ->
              to_string(question.no) == to_string(question_no)
            end)
          Map.put(category, :questions, updated_questions)
        else
          category
        end
      end)

    socket =
      case tab_type do
        "fr" ->
          assign(socket, :fr_categories, updated_categories)
        "nfr" ->
          assign(socket, :nfr_categories, updated_categories)
        _ ->
          socket
      end

    {:noreply,
     socket
     |> Phoenix.LiveView.put_flash(:info, "Soalan telah dipadam.")}
  end

  # Ensure value is a map (for to_form compatibility)
  defp ensure_map(data) when is_map(data), do: data

  defp load_project_info(params, socket, soal_selidik_id, initial_data) do
    # Extract project_id from initial_data first
    project_id_from_data = Map.get(initial_data, :project_id)

    cond do
      # If project_id is in params, load project directly
      Map.has_key?(params, "project_id") ->
        case Integer.parse(params["project_id"]) do
          {project_id, _} ->
            try do
              Projects.get_project!(project_id, socket.assigns.current_scope)
            rescue
              Ecto.NoResultsError -> nil
            end
          :error -> nil
        end

      # If we have project_id in initial_data (from soal_selidik)
      project_id_from_data != nil ->
        try do
          Projects.get_project!(project_id_from_data, socket.assigns.current_scope)
        rescue
          Ecto.NoResultsError -> nil
        end

      # If we have a soal_selidik_id, try to load project from it
      soal_selidik_id != nil ->
        try do
          soal_selidik = SoalSelidiks.get_soal_selidik!(soal_selidik_id, socket.assigns.current_scope)
          # Project should be preloaded
          if Ecto.assoc_loaded?(soal_selidik.project) && soal_selidik.project do
            soal_selidik.project
          else
            # If not preloaded, load it separately
            if soal_selidik.project_id do
              try do
                Projects.get_project!(soal_selidik.project_id, socket.assigns.current_scope)
              rescue
                Ecto.NoResultsError -> nil
              end
            else
              nil
            end
          end
        rescue
          Ecto.NoResultsError -> nil
        end

      # Default: no project
      true -> nil
    end
  end
  # Load initial data from database or use defaults
  defp load_initial_data(params, socket) do
    case Map.get(params, "id") do
      nil ->
        # No ID provided, use defaults
        # Check if project_id is in params
        project_id =
          if Map.has_key?(params, "project_id") do
            case Integer.parse(params["project_id"]) do
              {id, _} -> id
              :error -> nil
            end
          else
            nil
          end

        {nil,
         %{
           document_id: "JPKN-BPA-01/B1",
           nama_sistem: "",
           tabs: nil,
           fr_categories: nil,
           nfr_categories: nil,
           form_data: %{"nama_sistem" => ""},
           project_id: project_id
         }}

      id ->
        # Try to load from database
        case Integer.parse(id) do
          {id_int, _} ->
            try do
              soal_selidik = SoalSelidiks.get_soal_selidik!(id_int, socket.assigns.current_scope)
              data = SoalSelidiks.to_liveview_format(soal_selidik)

              # Prepare form data
              form_data = %{
                "nama_sistem" => data.nama_sistem,
                "disediakan_oleh" => %{
                  "nama" => Map.get(data.disediakan_oleh, :nama, Map.get(data.disediakan_oleh, "nama", "")),
                  "jawatan" => Map.get(data.disediakan_oleh, :jawatan, Map.get(data.disediakan_oleh, "jawatan", "")),
                  "tarikh" => Map.get(data.disediakan_oleh, :tarikh, Map.get(data.disediakan_oleh, "tarikh", ""))
                }
              }

              # Merge fr_data and nfr_data into form_data
              form_data =
                form_data
                |> Map.put("fr", data.fr_data)
                |> Map.put("nfr", data.nfr_data)

              # Get project_id from soal_selidik if available
              project_id = if Ecto.assoc_loaded?(soal_selidik.project) && soal_selidik.project do
                soal_selidik.project.id
              else
                soal_selidik.project_id
              end

              {id_int,
               %{
                 document_id: data.document_id,
                 nama_sistem: data.nama_sistem,
                 tabs: data.tabs,
                 fr_categories: data.fr_categories,
                 nfr_categories: data.nfr_categories,
                 form_data: form_data,
                 project_id: project_id
               }}
            rescue
              Ecto.NoResultsError ->
                # ID not found, use defaults
                # Check if project_id is in params
                project_id =
                  if Map.has_key?(params, "project_id") do
                    case Integer.parse(params["project_id"]) do
                      {id, _} -> id
                      :error -> nil
                    end
                  else
                    nil
                  end

                {nil,
                 %{
                   document_id: "JPKN-BPA-01/B1",
                   nama_sistem: "",
                   tabs: nil,
                   fr_categories: nil,
                   nfr_categories: nil,
                   form_data: %{},
                   project_id: project_id
                 }}
            end

          :error ->
            # Invalid ID, use defaults
            # Check if project_id is in params
            project_id =
              if Map.has_key?(params, "project_id") do
                case Integer.parse(params["project_id"]) do
                  {id, _} -> id
                  :error -> nil
                end
              else
                nil
              end

            {nil,
             %{
               document_id: "JPKN-BPA-01/B1",
               nama_sistem: "",
               tabs: nil,
               fr_categories: nil,
               nfr_categories: nil,
               form_data: %{},
               project_id: project_id
             }}
        end
    end
  end

  # Prepare data for saving to database
  defp prepare_save_data(params, socket) do
    require Logger

    # Log all params keys for debugging
    Logger.info("prepare_save_data params keys: #{inspect(Map.keys(params))}")
    Logger.info("prepare_save_data full params: #{inspect(params, limit: :infinity)}")

    # Extract basic fields - trim whitespace
    # Priority: params -> socket.assigns.system_name -> form data -> empty string (let validation catch it)
    nama_sistem_raw = Map.get(params, "nama_sistem")
    nama_sistem_from_assigns = socket.assigns[:system_name]

    # Also check form data as fallback (in case params don't have it)
    nama_sistem_from_form =
      case socket.assigns.form do
        %{source: %{params: form_params}} when is_map(form_params) ->
          Map.get(form_params, "nama_sistem")
        %{source: form_source} when is_map(form_source) ->
          Map.get(form_source, "nama_sistem")
        _ ->
          nil
      end

    nama_sistem =
      cond do
        # If in params (even if empty string), use it after trimming
        Map.has_key?(params, "nama_sistem") ->
          (nama_sistem_raw || "") |> String.trim()
        # Fallback to assigns if available
        nama_sistem_from_assigns && nama_sistem_from_assigns != "" ->
          nama_sistem_from_assigns |> String.trim()
        # Fallback to form data
        nama_sistem_from_form && nama_sistem_from_form != "" ->
          nama_sistem_from_form |> String.trim()
        # Otherwise empty string - validate_required will catch it
        true ->
          ""
      end

    # Log for debugging
    Logger.info("nama_sistem from params: #{inspect(nama_sistem_raw)}")
    Logger.info("nama_sistem from assigns: #{inspect(nama_sistem_from_assigns)}")
    Logger.info("nama_sistem from form: #{inspect(nama_sistem_from_form)}")
    Logger.info("nama_sistem final (after trim): #{inspect(nama_sistem)}")

    document_id = socket.assigns.document_id || "JPKN-BPA-01/B1"

    # Extract disediakan_oleh
    disediakan_oleh = Map.get(params, "disediakan_oleh", %{})

    # Extract fr_data and nfr_data
    fr_data = Map.get(params, "fr", %{})
    nfr_data = Map.get(params, "nfr", %{})

    # Extract custom_tabs
    custom_tabs = Map.get(params, "custom_tabs", %{})

    # Get categories and tabs from assigns
    # Convert lists to maps for database storage (database expects :map type)
    fr_categories_list = socket.assigns.fr_categories || []
    nfr_categories_list = socket.assigns.nfr_categories || []
    tabs_list = socket.assigns.tabs || []

    # Convert lists to maps: use category key as map key
    fr_categories_map =
      fr_categories_list
      |> Enum.map(fn category -> {category.key, category} end)
      |> Map.new()

    nfr_categories_map =
      nfr_categories_list
      |> Enum.map(fn category -> {category.key, category} end)
      |> Map.new()

    # Convert tabs list to map: use tab id as map key
    tabs_map =
      tabs_list
      |> Enum.map(fn tab -> {tab.id, tab} end)
      |> Map.new()

    %{
      nama_sistem: nama_sistem,
      document_id: document_id,
      fr_categories: fr_categories_map,
      nfr_categories: nfr_categories_map,
      fr_data: fr_data,
      nfr_data: nfr_data,
      disediakan_oleh: disediakan_oleh,
      custom_tabs: custom_tabs,
      tabs: tabs_map
    }
  end

  # Deep merge params to preserve existing user input
  # This ensures that when new params come in, existing values are not lost
  defp deep_merge_params(existing, new) do
    # Start with existing, then merge new on top
    # This way new values (user input) take precedence, but existing values are preserved
    Map.merge(existing, new, fn
      _key, existing_val, new_val when is_map(existing_val) and is_map(new_val) ->
        # Recursively merge nested maps
        deep_merge_params(existing_val, new_val)
      _key, existing_val, _new_val when is_map(existing_val) ->
        # Existing is map but new is not - keep existing
        existing_val
      _key, _existing_val, new_val when is_map(new_val) ->
        # New is map but existing is not - use new
        new_val
      _key, existing_val, new_val ->
        # Both are simple values - prefer new if not empty, otherwise keep existing
        cond do
          # If new value is not empty, use it (user just typed this)
          new_val != "" && new_val != nil ->
            new_val
          # If existing value exists and new is empty, keep existing (preserve previous input)
          existing_val != "" && existing_val != nil ->
            existing_val
          # Otherwise use new value
          true ->
            new_val
        end
    end)
  end

  # Ensure params structure is complete with all required keys
  # This prevents data loss when params come in incomplete
  defp ensure_complete_params(params, fr_categories, nfr_categories) do
    # Start with existing params
    result = params

    # Ensure FR structure exists
    result = Map.put_new(result, "fr", %{})

    # Ensure each FR category has complete structure
    result =
      Enum.reduce(fr_categories || [], result, fn category, acc ->
        fr_params = Map.get(acc, "fr", %{})
        category_key = category.key
        category_params = Map.get(fr_params, category_key, %{})

        # Ensure each question has a map entry (preserve existing if exists)
        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            # Preserve existing values, only add empty map if doesn't exist
            existing_question_params = Map.get(cat_acc, question_no, %{})
            Map.put(cat_acc, question_no, existing_question_params)
          end)

        updated_fr_params = Map.put(fr_params, category_key, updated_category_params)
        Map.put(acc, "fr", updated_fr_params)
      end)

    # Ensure NFR structure exists
    result = Map.put_new(result, "nfr", %{})

    # Ensure each NFR category has complete structure
    result =
      Enum.reduce(nfr_categories || [], result, fn category, acc ->
        nfr_params = Map.get(acc, "nfr", %{})
        category_key = category.key
        category_params = Map.get(nfr_params, category_key, %{})

        # Ensure each question has a map entry (preserve existing if exists)
        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            # Preserve existing values, only add empty map if doesn't exist
            existing_question_params = Map.get(cat_acc, question_no, %{})
            Map.put(cat_acc, question_no, existing_question_params)
          end)

        updated_nfr_params = Map.put(nfr_params, category_key, updated_category_params)
        Map.put(acc, "nfr", updated_nfr_params)
      end)

    result
  end

  # Merge soalan values from categories into form params
  # Only adds soalan if it's not already in params (to preserve user input)
  defp merge_soalan_from_categories(params, fr_categories, nfr_categories) do
    # Extract soalan from FR categories
    fr_with_soalan =
      Enum.reduce(fr_categories || [], params, fn category, acc ->
        category_key = category.key
        category_params = Map.get(acc, "fr", %{}) |> Map.get(category_key, %{})

        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            question_params = Map.get(cat_acc, question_no, %{})

            # Only add soalan from category if it's not already in params (preserve user input)
            updated_question_params =
              if Map.has_key?(question_params, "soalan") do
                # User input exists, keep it
                question_params
              else
                # No user input, use value from category if it exists
                if question.soalan && question.soalan != "" do
                  Map.put(question_params, "soalan", question.soalan)
                else
                  question_params
                end
              end

            Map.put(cat_acc, question_no, updated_question_params)
          end)

        fr_params = Map.get(acc, "fr", %{})
        updated_fr_params = Map.put(fr_params, category_key, updated_category_params)
        Map.put(acc, "fr", updated_fr_params)
      end)

    # Extract soalan from NFR categories
    final_params =
      Enum.reduce(nfr_categories || [], fr_with_soalan, fn category, acc ->
        category_key = category.key
        category_params = Map.get(acc, "nfr", %{}) |> Map.get(category_key, %{})

        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            question_params = Map.get(cat_acc, question_no, %{})

            # Only add soalan from category if it's not already in params (preserve user input)
            updated_question_params =
              if Map.has_key?(question_params, "soalan") do
                # User input exists, keep it
                question_params
              else
                # No user input, use value from category if it exists
                if question.soalan && question.soalan != "" do
                  Map.put(question_params, "soalan", question.soalan)
                else
                  question_params
                end
              end

            Map.put(cat_acc, question_no, updated_question_params)
          end)

        nfr_params = Map.get(acc, "nfr", %{})
        updated_nfr_params = Map.put(nfr_params, category_key, updated_category_params)
        Map.put(acc, "nfr", updated_nfr_params)
      end)

    final_params
  end

end
