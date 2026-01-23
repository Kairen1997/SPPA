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

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Soal Selidik")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/soal-selidik")
        |> assign(:soal_selidik_id, soal_selidik_id)
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
  def handle_event("remove_tab", %{"tab_id" => tab_id}, socket) do
    # Prevent removing default tabs
    tab = Enum.find(socket.assigns.tabs, &(&1.id == tab_id))

    if tab && tab.removable do
      updated_tabs = Enum.reject(socket.assigns.tabs, &(&1.id == tab_id))

      # If we removed the active tab, switch to the first tab
      new_active_tab =
        if socket.assigns.active_tab == tab_id do
          case List.first(updated_tabs) do
            nil -> "fr"
            first_tab -> first_tab.id
          end
        else
          socket.assigns.active_tab
        end

      {:noreply,
       socket
       |> assign(:tabs, updated_tabs)
       |> assign(:active_tab, new_active_tab)
       |> Phoenix.LiveView.put_flash(:info, "Tab telah dibuang.")}
    else
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Tab ini tidak boleh dibuang.")}
    end
  end

  @impl true
  def handle_event("validate", %{"soal_selidik" => params}, socket) do
    # The PreserveFormData hook should send all form data in params
    # But we still need to ensure soalan from categories is included
    # Start with params (which should be complete from the hook)
    params_with_soalan = merge_soalan_from_categories(params, socket.assigns.fr_categories, socket.assigns.nfr_categories)

    # Use params_with_soalan (from current form + categories) as the single source of truth
    # We no longer deep-merge with any existing params to avoid unintended data retention
    # Ensure the params structure is complete
    final_params = ensure_complete_params(params_with_soalan, socket.assigns.fr_categories, socket.assigns.nfr_categories)

    form = to_form(final_params, as: :soal_selidik)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"soal_selidik" => params}, socket) do
    # Prepare data for saving
    attrs = prepare_save_data(params, socket)

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

      {:error, _changeset} ->
        socket =
          socket
          |> assign(:form, to_form(params, as: :soal_selidik))
          |> Phoenix.LiveView.put_flash(
            :error,
            "Ralat semasa menyimpan soal selidik. Sila cuba lagi."
          )

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("generate_pdf", _params, socket) do
    nama_sistem =
      Phoenix.HTML.Form.input_value(socket.assigns.form, :nama_sistem) ||
        socket.assigns.system_name ||
        "Sistem Pengurusan Projek Aplikasi (SPPA)"

    dummy_data = Sppa.SoalSelidik.pdf_data(nama_sistem: nama_sistem)

    {:noreply,
      socket
     |> assign(:show_pdf_modal, true)
     |> assign(:pdf_data, dummy_data)}
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

    # Update form as well
    updated_form = to_form(soal_selidik_params, as: :soal_selidik)

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

  # Load initial data from database or use defaults
  defp load_initial_data(params, socket) do
    case Map.get(params, "id") do
      nil ->
        # No ID provided, use defaults
        {nil,
         %{
           document_id: "JPKN-BPA-01/B1",
           nama_sistem: "",
           tabs: nil,
           fr_categories: nil,
           nfr_categories: nil,
           form_data: %{}
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

              {id_int,
               %{
                 document_id: data.document_id,
                 nama_sistem: data.nama_sistem,
                 tabs: data.tabs,
                 fr_categories: data.fr_categories,
                 nfr_categories: data.nfr_categories,
                 form_data: form_data
               }}
            rescue
              Ecto.NoResultsError ->
                # ID not found, use defaults
                {nil,
                 %{
                   document_id: "JPKN-BPA-01/B1",
                   nama_sistem: "",
                   tabs: nil,
                   fr_categories: nil,
                   nfr_categories: nil,
                   form_data: %{}
                 }}
            end

          :error ->
            # Invalid ID, use defaults
            {nil,
             %{
               document_id: "JPKN-BPA-01/B1",
               nama_sistem: "",
               tabs: nil,
               fr_categories: nil,
               nfr_categories: nil,
               form_data: %{}
             }}
        end
    end
  end

  # Prepare data for saving to database
  defp prepare_save_data(params, socket) do
    # Extract basic fields
    nama_sistem = Map.get(params, "nama_sistem", "") || socket.assigns.system_name || ""
    document_id = socket.assigns.document_id || "JPKN-BPA-01/B1"

    # Extract disediakan_oleh
    disediakan_oleh = Map.get(params, "disediakan_oleh", %{})

    # Extract fr_data and nfr_data
    fr_data = Map.get(params, "fr", %{})
    nfr_data = Map.get(params, "nfr", %{})

    # Extract custom_tabs
    custom_tabs = Map.get(params, "custom_tabs", %{})

    # Get categories and tabs from assigns
    fr_categories = socket.assigns.fr_categories || []
    nfr_categories = socket.assigns.nfr_categories || []
    tabs = socket.assigns.tabs || []

    %{
      nama_sistem: nama_sistem,
      document_id: document_id,
      fr_categories: fr_categories,
      nfr_categories: nfr_categories,
      fr_data: fr_data,
      nfr_data: nfr_data,
      disediakan_oleh: disediakan_oleh,
      custom_tabs: custom_tabs,
      tabs: tabs
    }
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
            # Only add if doesn't exist, preserve existing values
            if Map.has_key?(cat_acc, question_no) do
              cat_acc
            else
              Map.put(cat_acc, question_no, %{})
            end
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
            # Only add if doesn't exist, preserve existing values
            if Map.has_key?(cat_acc, question_no) do
              cat_acc
            else
              Map.put(cat_acc, question_no, %{})
            end
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
