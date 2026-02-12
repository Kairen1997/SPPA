defmodule SppaWeb.SoalSelidikLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.Projects.Project
  alias Sppa.Repo
  alias Sppa.SoalSelidiks

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  # Functional Requirements Categories (susunan dari atas ke bawah)
  @fr_categories [
    %{key: "pendaftaran_login", title: "Pendaftaran dan Log Masuk", questions: []},
    %{key: "pengurusan_data", title: "Pengurusan Data", questions: []},
    %{key: "proses_kerja", title: "Proses Kerja", questions: []},
    %{key: "laporan", title: "Laporan", questions: []},
    %{key: "integrasi", title: "Integrasi", questions: []},
    %{key: "role_akses", title: "Akses Role Management", questions: []},
    %{key: "peraturan_polisi", title: "Peraturan/Perundingan", questions: []},
    %{key: "lain_lain_ciri", title: "Lain-lain Ciri Fungsian", questions: []}
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

      # Nama sistem is always taken from project data
      # Priority: project.nama -> existing soal_selidik nama_sistem (for backward compatibility) -> empty string
      nama_sistem =
        cond do
          # Priority 1: Always use project name if project exists
          project && project.nama && project.nama != "" ->
            project.nama

          # Priority 2: Fallback to existing nama_sistem if no project (for backward compatibility)
          initial_data.nama_sistem && initial_data.nama_sistem != "" ->
            initial_data.nama_sistem

          # Priority 3: Otherwise empty string
          true ->
            ""
        end

      # Always update form_data with nama_sistem to ensure it's in the form
      base_form_data = initial_data.form_data

      updated_form_data = Map.put(base_form_data, "nama_sistem", nama_sistem)

      # Ensure form has full fr/nfr structure (all categories & questions) so input_value works.
      # Preserves existing fr_data/nfr_data when loading from DB (e.g. Edit Borang).
      fr_cats = initial_data[:fr_categories] || @fr_categories
      nfr_cats = initial_data[:nfr_categories] || @nfr_categories

      form_data_with_structure =
        updated_form_data
        |> ensure_map()
        |> ensure_complete_params(fr_cats, nfr_cats)
        |> Map.put("nama_sistem", nama_sistem)

      # Add project_id to form_data when we have project (Edit Borang) so it's always submitted
      form_data_for_form =
        if project do
          Map.put(form_data_with_structure, "project_id", to_string(project.id))
        else
          form_data_with_structure
        end

      # Update initial_data with nama_sistem and form_data for any downstream use
      initial_data =
        initial_data
        |> Map.put(:nama_sistem, nama_sistem)
        |> Map.put(:form_data, form_data_for_form)

      # Debug: Log values to understand what's happening
      require Logger
      Logger.info("=== NAMA SISTEM DEBUG ===")
      Logger.info("project_id from params: #{inspect(Map.get(params, "project_id"))}")

      Logger.info(
        "project loaded: #{inspect(if project, do: "YES - #{project.nama}", else: "NO")}"
      )

      Logger.info("soal_selidik_id: #{inspect(soal_selidik_id)}")
      Logger.info("initial_data.nama_sistem: #{inspect(initial_data.nama_sistem)}")
      Logger.info("nama_sistem final: #{inspect(nama_sistem)}")

      Logger.info(
        "form_data_for_form nama_sistem: #{inspect(Map.get(form_data_for_form, "nama_sistem"))}"
      )

      Logger.info("=========================")

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
        |> assign(:system_name, nama_sistem)
        |> assign(:nama_sistem_value, nama_sistem)
        |> assign(:active_tab, "fr")
        |> assign(:tabs, initial_data.tabs || default_tabs)
        |> assign(:fr_categories, initial_data.fr_categories || @fr_categories)
        |> assign(:nfr_categories, initial_data.nfr_categories || @nfr_categories)
        |> assign(:form, to_form(form_data_for_form, as: :soal_selidik))
        |> assign(:show_pdf_modal, false)
        |> assign(:pdf_data, nil)
        |> assign(:show_edit_question_modal, false)
        |> assign(:selected_question, nil)
        |> assign(:edit_question_form, to_form(%{}, as: :edit_question))
        |> assign(:open_category_ids, MapSet.new())

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
  def handle_event("toggle_soal_selidik_category", %{"key" => key, "open" => open}, socket)
      when is_binary(key) do
    open? = open in [true, "true", "1"]
    ids =
      if open? do
        MapSet.put(socket.assigns.open_category_ids, key)
      else
        MapSet.delete(socket.assigns.open_category_ids, key)
      end

    {:noreply, assign(socket, :open_category_ids, ids)}
  end

  def handle_event("toggle_soal_selidik_category", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("validate", %{"soal_selidik" => params}, socket) do
    require Logger

    try do
      # Get existing form data to preserve user input
      existing_soal_selidik = extract_form_data(socket.assigns.form)

      # Log for debugging
      Logger.info("=== VALIDATE EVENT DEBUG ===")
      Logger.info("Incoming params keys: #{inspect(Map.keys(params))}")
      Logger.info("Existing form data keys: #{inspect(Map.keys(existing_soal_selidik))}")

      # Log disediakan_oleh specifically
      Logger.info("Incoming disediakan_oleh: #{inspect(Map.get(params, "disediakan_oleh"))}")

      Logger.info(
        "Existing disediakan_oleh: #{inspect(Map.get(existing_soal_selidik, "disediakan_oleh"))}"
      )

      # Special handling for disediakan_oleh to prevent fields from clearing each other
      incoming_disediakan_oleh = Map.get(params, "disediakan_oleh", %{})
      existing_disediakan_oleh = Map.get(existing_soal_selidik, "disediakan_oleh", %{})

      merged_disediakan_oleh =
        Map.merge(existing_disediakan_oleh, incoming_disediakan_oleh, fn key,
                                                                         existing_val,
                                                                         new_val ->
          # If new value is empty string but we already have a value, keep existing
          if new_val == "" and existing_val not in [nil, ""] do
            Logger.debug(
              "validate: preserving existing disediakan_oleh.#{key} value: #{inspect(existing_val)}"
            )

            existing_val
          else
            Logger.debug("validate: using new disediakan_oleh.#{key} value: #{inspect(new_val)}")

            new_val
          end
        end)

      # Put merged disediakan_oleh back into both existing data and incoming params
      existing_soal_selidik =
        Map.put(existing_soal_selidik, "disediakan_oleh", merged_disediakan_oleh)

      params = Map.put(params, "disediakan_oleh", merged_disediakan_oleh)

      # Log sample data to see what we're working with
      case Map.get(params, "fr") do
        %{} = fr when map_size(fr) > 0 ->
          first_cat = fr |> Map.keys() |> List.first()

          if first_cat do
            cat_data = Map.get(fr, first_cat, %{})

            if map_size(cat_data) > 0 do
              first_q = cat_data |> Map.keys() |> List.first()

              if first_q do
                q_data = Map.get(cat_data, first_q, %{})

                Logger.info(
                  "Incoming params sample [fr][#{first_cat}][#{first_q}]: #{inspect(q_data)}"
                )
              end
            end
          end

        _ ->
          Logger.info("No FR data in incoming params")
      end

      case Map.get(existing_soal_selidik, "fr") do
        %{} = fr when map_size(fr) > 0 ->
          first_cat = fr |> Map.keys() |> List.first()

          if first_cat do
            cat_data = Map.get(fr, first_cat, %{})

            if map_size(cat_data) > 0 do
              first_q = cat_data |> Map.keys() |> List.first()

              if first_q do
                q_data = Map.get(cat_data, first_q, %{})

                Logger.info(
                  "Existing form data sample [fr][#{first_cat}][#{first_q}]: #{inspect(q_data)}"
                )
              end
            end
          end

        _ ->
          Logger.info("No FR data in existing form data")
      end

      # CRITICAL: When phx-change is triggered, params may only contain the changed field
      # OR it may contain all form data from hook JavaScript (with empty strings for inactive fields)
      # We must merge with existing data to preserve all other fields
      # Start with existing (to preserve all fields), then merge new params on top
      # The key is: if a field exists in existing but not in new params, keep existing
      # If a field exists in both, use new ONLY if new is not empty (user just typed it)
      merged_params = deep_merge_params(existing_soal_selidik, params)

      Logger.info("Merged params keys: #{inspect(Map.keys(merged_params))}")

      # Log sample merged data
      case Map.get(merged_params, "fr") do
        %{} = fr when map_size(fr) > 0 ->
          first_cat = fr |> Map.keys() |> List.first()

          if first_cat do
            cat_data = Map.get(fr, first_cat, %{})

            if map_size(cat_data) > 0 do
              first_q = cat_data |> Map.keys() |> List.first()

              if first_q do
                q_data = Map.get(cat_data, first_q, %{})

                Logger.info(
                  "Merged params sample [fr][#{first_cat}][#{first_q}]: #{inspect(q_data)}"
                )

                Logger.info("  - soalan: #{inspect(Map.get(q_data, "soalan"))}")
                Logger.info("  - maklumbalas: #{inspect(Map.get(q_data, "maklumbalas"))}")
                Logger.info("  - catatan: #{inspect(Map.get(q_data, "catatan"))}")
              end
            end
          end

        _ ->
          Logger.info("No FR data in merged params")
      end

      # CRITICAL: After merging, we need to ensure structure is complete
      # But we should NOT call merge_soalan_from_categories as it may overwrite data
      # Instead, only ensure structure exists without overwriting values
      # Only merge soalan from categories if it doesn't exist in merged_params
      final_params =
        merged_params
        |> ensure_complete_params(socket.assigns.fr_categories, socket.assigns.nfr_categories)
        |> merge_soalan_from_categories_safe(
          socket.assigns.fr_categories,
          socket.assigns.nfr_categories
        )

      Logger.info("Final params keys: #{inspect(Map.keys(final_params))}")

      # Log final sample data
      case Map.get(final_params, "fr") do
        %{} = fr when map_size(fr) > 0 ->
          first_cat = fr |> Map.keys() |> List.first()

          if first_cat do
            cat_data = Map.get(fr, first_cat, %{})

            if map_size(cat_data) > 0 do
              first_q = cat_data |> Map.keys() |> List.first()

              if first_q do
                q_data = Map.get(cat_data, first_q, %{})

                Logger.info(
                  "Final params sample [fr][#{first_cat}][#{first_q}]: #{inspect(q_data)}"
                )

                Logger.info("  - soalan: #{inspect(Map.get(q_data, "soalan"))}")
                Logger.info("  - maklumbalas: #{inspect(Map.get(q_data, "maklumbalas"))}")
                Logger.info("  - catatan: #{inspect(Map.get(q_data, "catatan"))}")
              end
            end
          end

        _ ->
          Logger.info("No FR data in final params")
      end

      Logger.info("===========================")

      # Create form with the merged params - this will be used to render input values
      # The form will contain ALL fields (existing + new), so input values will be preserved
      form = to_form(final_params, as: :soal_selidik)

      # CRITICAL: Auto-save to database to persist data
      # This ensures data is saved even if user doesn't click "Save" button
      # Only save if we have a soal_selidik_id (existing record) or if we have project_id (new record)
      socket =
        if socket.assigns.current_scope && socket.assigns.current_scope.user do
          auto_save_to_database(socket, final_params)
        else
          socket
        end

      {:noreply, assign(socket, form: form)}
    rescue
      e ->
        # Log error but don't crash - return current form state
        require Logger
        Logger.error("Error in validate: #{inspect(e)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    # Fallback for validate events without soal_selidik params
    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "save_field",
        %{
          "tab_type" => tab_type,
          "category_key" => category_key,
          "question_no" => question_no,
          "field" => field,
          "value" => value
        },
        socket
      ) do
    unless socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Sesi anda telah tamat. Sila log masuk semula.")}
    else
      try do
        # Get existing form data to preserve all other fields
        existing_soal_selidik = extract_form_data(socket.assigns.form)

        # Update only the specific field with the new value
        updated_data =
          existing_soal_selidik
          |> Map.put_new(tab_type, %{})
          |> Map.update!(tab_type, fn tab_data ->
            tab_data
            |> Map.put_new(category_key, %{})
            |> Map.update!(category_key, fn cat_data ->
              cat_data
              |> Map.put_new(question_no, %{})
              |> Map.update!(question_no, fn q_data ->
                Map.put(q_data, field, value)
              end)
            end)
          end)

        # Ensure structure is complete
        final_params =
          updated_data
          |> ensure_complete_params(socket.assigns.fr_categories, socket.assigns.nfr_categories)
          |> merge_soalan_from_categories_safe(
            socket.assigns.fr_categories,
            socket.assigns.nfr_categories
          )

        # Save to database immediately
        attrs = prepare_save_data(final_params, socket)
        attrs = Map.put(attrs, :user_id, socket.assigns.current_scope.user.id)

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
            # Update form with saved data
            form = to_form(final_params, as: :soal_selidik)

            socket =
              socket
              |> assign(:form, form)
              |> assign(:soal_selidik_id, soal_selidik.id)

            {:noreply, socket}

          {:error, _changeset} ->
            # If save fails, still update form so user input is preserved
            form = to_form(final_params, as: :soal_selidik)
            {:noreply, assign(socket, form: form)}
        end
      rescue
        e ->
          require Logger
          Logger.error("Error in save_field: #{inspect(e)}")
          {:noreply, socket}
      end
    end
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
      Logger.info(
        "Attempting to save soal selidik with attrs: #{inspect(attrs, limit: :infinity)}"
      )

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
          # Verify data was saved by logging the saved record
          Logger.info("Soal selidik saved successfully with ID: #{soal_selidik.id}")
          Logger.info("Saved fr_data keys: #{inspect(Map.keys(soal_selidik.fr_data || %{}))}")
          Logger.info("Saved nfr_data keys: #{inspect(Map.keys(soal_selidik.nfr_data || %{}))}")

          # Log sample data from saved record
          case soal_selidik.fr_data do
            %{} = fr when map_size(fr) > 0 ->
              first_category = fr |> Map.keys() |> List.first()

              if first_category do
                category_data = Map.get(fr, first_category, %{})

                if map_size(category_data) > 0 do
                  first_question = category_data |> Map.keys() |> List.first()

                  if first_question do
                    question_data = Map.get(category_data, first_question, %{})

                    Logger.info(
                      "Saved fr_data[#{first_category}][#{first_question}]: #{inspect(question_data)}"
                    )

                    Logger.info(
                      "  - soalan in DB: #{Map.has_key?(question_data, :soalan) || Map.has_key?(question_data, "soalan")}"
                    )

                    Logger.info(
                      "  - maklumbalas in DB: #{Map.has_key?(question_data, :maklumbalas) || Map.has_key?(question_data, "maklumbalas")}"
                    )

                    Logger.info(
                      "  - catatan in DB: #{Map.has_key?(question_data, :catatan) || Map.has_key?(question_data, "catatan")}"
                    )
                  end
                end
              end

            _ ->
              Logger.info("Saved fr_data is empty")
          end

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
  def handle_event(
        "add_question",
        %{"tab_type" => tab_type, "category_key" => category_key},
        socket
      ) do
    unless socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Sesi anda telah tamat. Sila log masuk semula.")}
    else
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

      # Update form only (no DB round-trip) so the page does not refresh; data is saved on blur/validate or "Simpan"
      existing_soal_selidik = extract_form_data(socket.assigns.form)

      params_with_soalan =
        merge_soalan_from_categories(
          existing_soal_selidik,
          socket.assigns.fr_categories,
          socket.assigns.nfr_categories
        )

      final_params =
        ensure_complete_params(
          params_with_soalan,
          socket.assigns.fr_categories,
          socket.assigns.nfr_categories
        )

      final_params =
        if socket.assigns[:project] do
          Map.put(final_params, "project_id", to_string(socket.assigns.project.id))
        else
          final_params
        end

      form = to_form(final_params, as: :soal_selidik)

      {:noreply,
       socket
       |> assign(:form, form)
       |> assign(:open_category_ids, MapSet.put(socket.assigns.open_category_ids || MapSet.new(), category_key))
       |> Phoenix.LiveView.put_flash(
         :info,
         "Baris baru telah ditambah. Klik Simpan untuk menyimpan."
       )}
    end
  end

  @impl true
  def handle_event(
        "update_question_text",
        %{"soal_selidik" => soal_selidik_params} = params,
        socket
      ) do
    # This handler is kept for backward compatibility
    # But now soalan input uses phx-change="validate" which handles form updates
    # So we just update the categories to keep them in sync
    tab_type = Map.get(params, "tab_type")
    category_key = Map.get(params, "category_key")
    question_no = Map.get(params, "question_no")

    # Get the value from the form params
    soalan_value =
      get_in(soal_selidik_params, [tab_type, category_key, question_no, "soalan"]) || ""

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
    params_with_soalan =
      merge_soalan_from_categories(
        merged_params,
        socket.assigns.fr_categories,
        socket.assigns.nfr_categories
      )

    # Ensure complete structure
    final_params =
      ensure_complete_params(
        params_with_soalan,
        socket.assigns.fr_categories,
        socket.assigns.nfr_categories
      )

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
  def handle_event(
        "edit_question",
        %{"tab_type" => tab_type, "category_key" => category_key, "question_no" => question_no},
        socket
      ) do
    try do
      # Find the question to edit
      categories =
        case tab_type do
          "fr" -> socket.assigns[:fr_categories] || []
          "nfr" -> socket.assigns[:nfr_categories] || []
          _ -> []
        end

      question =
        categories
        |> Enum.find(&(&1.key == category_key))
        |> then(fn category ->
          if category && category.questions do
            Enum.find(category.questions, fn q -> to_string(q.no) == to_string(question_no) end)
          else
            nil
          end
        end)

      if question do
        # Get soalan, maklumbalas and catatan from form data
        form_params =
          if socket.assigns[:form] do
            extract_form_data(socket.assigns.form)
          else
            %{}
          end

        question_data =
          get_in(form_params, [tab_type, category_key, to_string(question_no)]) || %{}

        # Get soalan from form data first (handle both string and atom keys), fallback to question.soalan from categories
        soalan_from_form = Map.get(question_data, "soalan") || Map.get(question_data, :soalan)

        soalan =
          if soalan_from_form && soalan_from_form != "" do
            soalan_from_form
          else
            question.soalan || ""
          end

        maklumbalas =
          Map.get(question_data, "maklumbalas") || Map.get(question_data, :maklumbalas) || ""

        catatan = Map.get(question_data, "catatan") || Map.get(question_data, :catatan) || ""

        # Handle maklumbalas if it's a list (for checkbox type)
        maklumbalas_str =
          cond do
            is_list(maklumbalas) -> Enum.join(maklumbalas, ", ")
            is_binary(maklumbalas) -> maklumbalas
            true -> ""
          end

        form_data = %{
          "soalan" => soalan || "",
          "maklumbalas" => maklumbalas_str || "",
          "catatan" => catatan || ""
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
    rescue
      e ->
        require Logger
        Logger.error("Error in edit_question: #{inspect(e)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")

        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(
           :error,
           "Ralat semasa membuka editor soalan. Sila cuba lagi."
         )}
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
      maklumbalas = Map.get(edit_question_params, "maklumbalas", "") |> String.trim()
      catatan = Map.get(edit_question_params, "catatan", "") |> String.trim()

      # Get existing form data
      existing_form_data = extract_form_data(socket.assigns.form)

      # Update the specific question's data in form params
      updated_form_data =
        existing_form_data
        |> Map.put_new(tab_type, %{})
        |> Map.update!(tab_type, fn tab_data ->
          tab_data
          |> Map.put_new(category_key, %{})
          |> Map.update!(category_key, fn cat_data ->
            cat_data
            |> Map.put_new(to_string(question_no), %{})
            |> Map.update!(to_string(question_no), fn q_data ->
              q_data
              |> Map.put("soalan", soalan)
              |> Map.put("maklumbalas", maklumbalas)
              |> Map.put("catatan", catatan)
            end)
          end)
        end)

      # Update question in categories (for soalan display)
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
                  Map.put(question, :soalan, soalan)
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

      # Ensure complete structure and merge soalan from categories
      final_params =
        updated_form_data
        |> ensure_complete_params(socket.assigns.fr_categories, socket.assigns.nfr_categories)
        |> merge_soalan_from_categories_safe(
          socket.assigns.fr_categories,
          socket.assigns.nfr_categories
        )

      # Ensure project_id in params when we have a project
      final_params =
        if socket.assigns[:project] do
          Map.put(final_params, "project_id", to_string(socket.assigns.project.id))
        else
          final_params
        end

      # Save to database
      attrs = prepare_save_data(final_params, socket)
      attrs = Map.put(attrs, :user_id, socket.assigns.current_scope.user.id)

      result =
        case socket.assigns.soal_selidik_id do
          nil ->
            SoalSelidiks.create_soal_selidik(attrs, socket.assigns.current_scope)

          id ->
            try do
              soal_selidik = SoalSelidiks.get_soal_selidik!(id, socket.assigns.current_scope)
              SoalSelidiks.update_soal_selidik(soal_selidik, attrs)
            rescue
              Ecto.NoResultsError ->
                SoalSelidiks.create_soal_selidik(attrs, socket.assigns.current_scope)
            end
        end

      case result do
        {:ok, soal_selidik} ->
          socket =
            socket
            |> assign(:soal_selidik_id, soal_selidik.id)
            |> assign(:form, to_form(final_params, as: :soal_selidik))
            |> assign(:show_edit_question_modal, false)
            |> assign(:selected_question, nil)
            |> assign(:edit_question_form, to_form(%{}, as: :edit_question))
            |> Phoenix.LiveView.put_flash(:info, "Soalan telah dikemaskini.")

          {:noreply, socket}

        {:error, changeset} ->
          error_message =
            if changeset.errors != [] do
              errors = Enum.map(changeset.errors, fn {f, {msg, _}} -> "#{f}: #{msg}" end)
              "Ralat: #{Enum.join(errors, ", ")}"
            else
              "Ralat semasa mengemaskini soalan. Sila cuba lagi."
            end

          {:noreply,
           socket
           |> Phoenix.LiveView.put_flash(:error, error_message)}
      end
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
          |> Map.put(
            tab_type,
            Map.merge(
              Map.get(existing_soal_selidik, tab_type, %{}),
              Map.get(soal_selidik_params, tab_type, %{})
            )
          )

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
              |> Phoenix.LiveView.put_flash(
                :info,
                "Baris #{question_no} telah disimpan dengan jayanya."
              )

            {:noreply, socket}

          {:error, changeset} ->
            error_message =
              if changeset.errors != [] do
                errors =
                  Enum.map(changeset.errors, fn {field, {msg, _}} -> "#{field}: #{msg}" end)

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
  def handle_event(
        "delete_question",
        %{"tab_type" => tab_type, "category_key" => category_key, "question_no" => question_no},
        socket
      ) do
    unless socket.assigns.current_scope && socket.assigns.current_scope.user do
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Sesi anda telah tamat. Sila log masuk semula.")}
    else
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

      # Sync form with updated question structure and remove deleted question from form data
      existing_soal_selidik = extract_form_data(socket.assigns.form)

      # Remove the deleted question from form data
      updated_soal_selidik =
        case tab_type do
          "fr" ->
            fr_data = Map.get(existing_soal_selidik, "fr", %{})
            category_data = Map.get(fr_data, category_key, %{})
            # Remove the question_no key from category_data
            updated_category_data = Map.delete(category_data, question_no)
            updated_fr_data = Map.put(fr_data, category_key, updated_category_data)
            Map.put(existing_soal_selidik, "fr", updated_fr_data)

          "nfr" ->
            nfr_data = Map.get(existing_soal_selidik, "nfr", %{})
            category_data = Map.get(nfr_data, category_key, %{})
            # Remove the question_no key from category_data
            updated_category_data = Map.delete(category_data, question_no)
            updated_nfr_data = Map.put(nfr_data, category_key, updated_category_data)
            Map.put(existing_soal_selidik, "nfr", updated_nfr_data)

          _ ->
            existing_soal_selidik
        end

      # Merge soalan from categories to ensure form structure is complete
      params_with_soalan =
        merge_soalan_from_categories(
          updated_soal_selidik,
          socket.assigns.fr_categories,
          socket.assigns.nfr_categories
        )

      final_params =
        ensure_complete_params(
          params_with_soalan,
          socket.assigns.fr_categories,
          socket.assigns.nfr_categories
        )

      # Ensure project_id in params when we have a project (e.g. from URL)
      final_params =
        if socket.assigns[:project] do
          Map.put(final_params, "project_id", to_string(socket.assigns.project.id))
        else
          final_params
        end

      attrs = prepare_save_data(final_params, socket)
      attrs = Map.put(attrs, :user_id, socket.assigns.current_scope.user.id)

      result =
        case socket.assigns.soal_selidik_id do
          nil ->
            SoalSelidiks.create_soal_selidik(attrs, socket.assigns.current_scope)

          id ->
            try do
              soal_selidik = SoalSelidiks.get_soal_selidik!(id, socket.assigns.current_scope)
              SoalSelidiks.update_soal_selidik(soal_selidik, attrs)
            rescue
              Ecto.NoResultsError ->
                SoalSelidiks.create_soal_selidik(attrs, socket.assigns.current_scope)
            end
        end

      case result do
        {:ok, soal_selidik} ->
          socket =
            socket
            |> assign(:soal_selidik_id, soal_selidik.id)
            |> assign(:form, to_form(final_params, as: :soal_selidik))
            |> Phoenix.LiveView.put_flash(:info, "Soalan telah dipadam dan disimpan.")

          {:noreply, socket}

        {:error, changeset} ->
          # Revert categories so UI matches DB
          socket =
            case tab_type do
              "fr" -> assign(socket, :fr_categories, categories)
              "nfr" -> assign(socket, :nfr_categories, categories)
              _ -> socket
            end

          error_message =
            if changeset.errors != [] do
              errors = Enum.map(changeset.errors, fn {f, {msg, _}} -> "#{f}: #{msg}" end)
              "Ralat: #{Enum.join(errors, ", ")}"
            else
              "Ralat semasa memadam soalan. Sila cuba lagi."
            end

          {:noreply,
           socket
           |> Phoenix.LiveView.put_flash(:error, error_message)}
      end
    end
  end

  # Ensure value is a map (for to_form compatibility)
  defp ensure_map(data) when is_map(data), do: data

  defp load_project_info(params, socket, soal_selidik_id, initial_data) do
    # Extract project_id from initial_data first
    project_id_from_data = Map.get(initial_data, :project_id)

    cond do
      # If project_id is in params, load project directly (accessed via Edit Borang button)
      # Load without user_id filter to allow access from project page
      Map.has_key?(params, "project_id") ->
        case Integer.parse(params["project_id"]) do
          {project_id, _} ->
            try do
              # Load project by ID only, without user_id filter
              # This allows access when clicking Edit Borang from project page
              project = Repo.get(Project, project_id)

              if project do
                # Preload associations if needed
                Repo.preload(project, [:developer, :project_manager])
              else
                nil
              end
            rescue
              Ecto.NoResultsError -> nil
              _ -> nil
            end

          :error ->
            nil
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
          soal_selidik =
            SoalSelidiks.get_soal_selidik!(soal_selidik_id, socket.assigns.current_scope)

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
      true ->
        nil
    end
  end

  # Load initial data from database or use defaults
  defp load_initial_data(params, socket) do
    id_param = Map.get(params, "id")

    if id_param && id_param != "" do
      load_initial_by_id(id_param, params, socket)
    else
      load_initial_by_project_or_default(params, socket)
    end
  end

  # Helper: load when an explicit soal_selidik ID is given
  defp load_initial_by_id(id_param, params, socket) do
    case Integer.parse(id_param) do
      {id_int, _} ->
        try do
          soal_selidik = SoalSelidiks.get_soal_selidik!(id_int, socket.assigns.current_scope)
          data = SoalSelidiks.to_liveview_format(soal_selidik)

          form_data = %{
            "nama_sistem" => data.nama_sistem,
            "disediakan_oleh" => %{
              "nama" =>
                Map.get(data.disediakan_oleh, :nama, Map.get(data.disediakan_oleh, "nama", "")),
              "jawatan" =>
                Map.get(
                  data.disediakan_oleh,
                  :jawatan,
                  Map.get(data.disediakan_oleh, "jawatan", "")
                ),
              "tarikh" =>
                Map.get(
                  data.disediakan_oleh,
                  :tarikh,
                  Map.get(data.disediakan_oleh, "tarikh", "")
                )
            }
          }

          form_data =
            form_data
            |> Map.put("fr", data.fr_data)
            |> Map.put("nfr", data.nfr_data)

          project_id =
            if Ecto.assoc_loaded?(soal_selidik.project) && soal_selidik.project do
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
            load_default_initial(params)
        end

      :error ->
        load_default_initial(params)
    end
  end

  # Helper: load using project_id (or fall back to latest soal_selidik / clean defaults)
  defp load_initial_by_project_or_default(params, socket) do
    project_id =
      if Map.has_key?(params, "project_id") do
        case Integer.parse(params["project_id"]) do
          {id, _} -> id
          :error -> nil
        end
      else
        nil
      end

    # First try soal_selidik linked to this project
    case project_id &&
           SoalSelidiks.get_soal_selidik_by_project(project_id, socket.assigns.current_scope) do
      %{} = soal_selidik ->
        build_initial_from_soal_selidik(soal_selidik, project_id)

      _ ->
        # No existing soal_selidik for this project – fall back to clean defaults
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
    end
  end

  # Helper: build the initial data tuple from a soal_selidik struct
  defp build_initial_from_soal_selidik(soal_selidik, project_id_override) do
    data = SoalSelidiks.to_liveview_format(soal_selidik)

    form_data = %{
      "nama_sistem" => data.nama_sistem,
      "disediakan_oleh" => %{
        "nama" => Map.get(data.disediakan_oleh, :nama, Map.get(data.disediakan_oleh, "nama", "")),
        "jawatan" =>
          Map.get(data.disediakan_oleh, :jawatan, Map.get(data.disediakan_oleh, "jawatan", "")),
        "tarikh" =>
          Map.get(data.disediakan_oleh, :tarikh, Map.get(data.disediakan_oleh, "tarikh", ""))
      }
    }

    form_data =
      form_data
      |> Map.put("fr", data.fr_data)
      |> Map.put("nfr", data.nfr_data)

    project_id =
      cond do
        project_id_override != nil ->
          project_id_override

        Ecto.assoc_loaded?(soal_selidik.project) && soal_selidik.project ->
          soal_selidik.project.id

        true ->
          soal_selidik.project_id
      end

    {soal_selidik.id,
     %{
       document_id: data.document_id,
       nama_sistem: data.nama_sistem,
       tabs: data.tabs,
       fr_categories: data.fr_categories,
       nfr_categories: data.nfr_categories,
       form_data: form_data,
       project_id: project_id
     }}
  end

  # Helper: default initial data when we cannot load any existing record
  defp load_default_initial(params) do
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

  # Prepare data for saving to database
  defp prepare_save_data(params, socket) do
    require Logger

    # Log all params keys for debugging
    Logger.info("prepare_save_data params keys: #{inspect(Map.keys(params))}")
    Logger.info("prepare_save_data full params: #{inspect(params, limit: :infinity)}")

    # Extract nama_sistem - always take from project data if available
    # Priority: project.nama -> existing soal_selidik nama_sistem -> empty string
    nama_sistem =
      cond do
        # First priority: Use project name if project is available
        socket.assigns[:project] && socket.assigns.project.nama &&
            socket.assigns.project.nama != "" ->
          socket.assigns.project.nama |> String.trim()

        # Fallback: Use existing nama_sistem from soal_selidik if available
        socket.assigns[:system_name] && socket.assigns.system_name != "" ->
          socket.assigns.system_name |> String.trim()

        # Otherwise empty string - validate_required will catch it
        true ->
          ""
      end

    # Log for debugging
    Logger.info(
      "nama_sistem from project: #{inspect(if socket.assigns[:project], do: socket.assigns.project.nama, else: nil)}"
    )

    Logger.info("nama_sistem from assigns: #{inspect(socket.assigns[:system_name])}")
    Logger.info("nama_sistem final (after trim): #{inspect(nama_sistem)}")

    document_id = socket.assigns.document_id || "JPKN-BPA-01/B1"

    # Extract disediakan_oleh
    disediakan_oleh_raw = Map.get(params, "disediakan_oleh", %{})

    # Log disediakan_oleh to verify it's being extracted correctly
    Logger.info("disediakan_oleh from params: #{inspect(disediakan_oleh_raw)}")
    Logger.info("disediakan_oleh keys: #{inspect(Map.keys(disediakan_oleh_raw))}")

    # Filter out _unused_* fields and get actual values
    # CRITICAL: Only extract actual field names, ignore Phoenix form helper fields
    nama_raw = Map.get(disediakan_oleh_raw, "nama", "")
    jawatan_raw = Map.get(disediakan_oleh_raw, "jawatan", "")
    tarikh_raw = Map.get(disediakan_oleh_raw, "tarikh", "")

    Logger.info("disediakan_oleh nama: #{inspect(nama_raw)}")
    Logger.info("disediakan_oleh jawatan: #{inspect(jawatan_raw)}")
    Logger.info("disediakan_oleh tarikh: #{inspect(tarikh_raw)}")

    # Ensure disediakan_oleh has all required fields, preserving existing values
    # CRITICAL: Only trim non-empty strings, preserve empty strings as-is
    nama_trimmed =
      if nama_raw != "" do
        String.trim(nama_raw)
      else
        nama_raw
      end

    jawatan_trimmed =
      if jawatan_raw != "" do
        String.trim(jawatan_raw)
      else
        jawatan_raw
      end

    disediakan_oleh = %{
      "nama" => nama_trimmed,
      "jawatan" => jawatan_trimmed,
      "tarikh" => tarikh_raw
    }

    Logger.info("disediakan_oleh after processing: #{inspect(disediakan_oleh)}")

    # Extract fr_data and nfr_data
    fr_data = Map.get(params, "fr", %{})
    nfr_data = Map.get(params, "nfr", %{})

    # Log fr_data and nfr_data to verify soalan, maklumbalas, and catatan are included
    Logger.info("fr_data keys: #{inspect(Map.keys(fr_data))}")
    Logger.info("nfr_data keys: #{inspect(Map.keys(nfr_data))}")

    # Log sample data from first category/question if available
    case fr_data do
      %{} = fr when map_size(fr) > 0 ->
        first_category = fr |> Map.keys() |> List.first()

        if first_category do
          category_data = Map.get(fr, first_category, %{})

          if map_size(category_data) > 0 do
            first_question = category_data |> Map.keys() |> List.first()

            if first_question do
              question_data = Map.get(category_data, first_question, %{})

              Logger.info(
                "Sample fr_data[#{first_category}][#{first_question}]: #{inspect(question_data)}"
              )

              Logger.info("  - soalan present: #{Map.has_key?(question_data, "soalan")}")

              Logger.info(
                "  - maklumbalas present: #{Map.has_key?(question_data, "maklumbalas")}"
              )

              Logger.info("  - catatan present: #{Map.has_key?(question_data, "catatan")}")
            end
          end
        end

      _ ->
        Logger.info("fr_data is empty")
    end

    # Extract custom_tabs
    custom_tabs = Map.get(params, "custom_tabs", %{})

    # Derive project_id so the soal selidik is linked to the project
    project_id_from_params =
      case Map.get(params, "project_id") do
        nil ->
          nil

        pid when is_integer(pid) ->
          pid

        pid when is_binary(pid) ->
          case Integer.parse(pid) do
            {id, _} -> id
            :error -> nil
          end

        _ ->
          nil
      end

    project_id_from_assigns =
      case socket.assigns[:project] do
        %{} = project -> project.id
        _ -> socket.assigns[:project_id]
      end

    project_id = project_id_from_params || project_id_from_assigns

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
      project_id: project_id,
      custom_tabs: custom_tabs,
      tabs: tabs_map
    }
  end

  # Helper to extract form data from form source
  # Handles both changeset and map sources
  # CRITICAL: This must extract ALL form data to preserve user input
  defp extract_form_data(form) when is_nil(form), do: %{}

  defp extract_form_data(form) do
    require Logger

    result =
      case form do
        %{source: source} when not is_nil(source) ->
          extract_from_source(source)

        _ ->
          Logger.warning("extract_form_data: Form has no source, returning empty map")
          %{}
      end

    # Log sample data for debugging
    case Map.get(result, "fr") do
      %{} = fr when map_size(fr) > 0 ->
        first_cat = fr |> Map.keys() |> List.first()

        if first_cat do
          cat_data = Map.get(fr, first_cat, %{})

          if map_size(cat_data) > 0 do
            first_q = cat_data |> Map.keys() |> List.first()

            if first_q do
              q_data = Map.get(cat_data, first_q, %{})

              Logger.debug(
                "extract_form_data: Sample data [fr][#{first_cat}][#{first_q}]: #{inspect(q_data)}"
              )
            end
          end
        end

      _ ->
        :ok
    end

    result
  end

  defp extract_from_source(source) do
    require Logger

    case source do
      %{params: form_params} when is_map(form_params) ->
        # Changeset source - params are nested under form name
        extracted = Map.get(form_params, "soal_selidik", %{})

        Logger.debug(
          "extract_form_data: Extracted from changeset params, keys: #{inspect(Map.keys(extracted))}"
        )

        extracted

      source when is_map(source) ->
        # Direct map source - this is what we get from to_form(map, as: :soal_selidik)
        # The source IS the soal_selidik params (not nested under "soal_selidik")
        # Make sure we return the entire map to preserve all fields
        # CRITICAL: Return a deep copy to avoid mutation issues
        Logger.debug(
          "extract_form_data: Extracted from direct map source, keys: #{inspect(Map.keys(source))}"
        )

        source

      _ ->
        Logger.warning("extract_form_data: Unknown form source type, returning empty map")
        %{}
    end
  end

  # Deep merge params to preserve existing user input
  # This ensures that when new params come in, existing values are not lost
  # CRITICAL: This function must preserve ALL existing fields when merging
  # CRITICAL: Empty strings from form data should NOT overwrite existing values
  defp deep_merge_params(existing, new) do
    require Logger

    # If new is empty, return existing
    if map_size(new) == 0 do
      existing
    else
      # Log for debugging
      Logger.debug("deep_merge_params: existing keys: #{inspect(Map.keys(existing))}")
      Logger.debug("deep_merge_params: new keys: #{inspect(Map.keys(new))}")

      # Log disediakan_oleh specifically
      Logger.info(
        "deep_merge_params: existing disediakan_oleh: #{inspect(Map.get(existing, "disediakan_oleh"))}"
      )

      Logger.info(
        "deep_merge_params: new disediakan_oleh: #{inspect(Map.get(new, "disediakan_oleh"))}"
      )

      # Start with existing as base, then merge new on top
      # This way new values (user input) take precedence, but existing values are preserved
      result =
        Map.merge(existing, new, fn
          key, existing_val, new_val when is_map(existing_val) and is_map(new_val) ->
            # Recursively merge nested maps - this preserves all fields in both maps
            # CRITICAL: This is where we preserve fields like maklumbalas and catatan
            # For disediakan_oleh specifically, ensure all fields are preserved
            merged =
              if key == "disediakan_oleh" do
                # Special handling for disediakan_oleh to ensure all fields are preserved
                # CRITICAL: Start with existing to preserve all fields, then update only fields that exist in new
                # Filter out _unused_* fields from new_val
                filtered_new_val =
                  new_val
                  |> Map.reject(fn {k, _v} -> String.starts_with?(k, "_unused_") end)

                result_map =
                  existing_val
                  |> Map.merge(filtered_new_val, fn
                    sub_key, existing_sub_val, new_sub_val ->
                      # CRITICAL: If new value is empty string and existing has a non-empty value, keep existing
                      # This prevents empty strings from overwriting user input
                      cond do
                        # New value is empty string and existing has a value - preserve existing
                        new_sub_val == "" && existing_sub_val != "" && existing_sub_val != nil ->
                          Logger.debug(
                            "deep_merge_params: preserving existing #{sub_key} value: #{inspect(existing_sub_val)}"
                          )

                          existing_sub_val

                        # New value exists (even if empty - user might have cleared it) - use new
                        true ->
                          Logger.debug(
                            "deep_merge_params: using new #{sub_key} value: #{inspect(new_sub_val)}"
                          )

                          new_sub_val
                      end
                  end)
                  # Ensure all required fields exist
                  |> Map.put_new("nama", "")
                  |> Map.put_new("jawatan", "")
                  |> Map.put_new("tarikh", "")

                Logger.info(
                  "deep_merge_params: merged disediakan_oleh - existing: #{inspect(existing_val)}, new: #{inspect(filtered_new_val)}, result: #{inspect(result_map)}"
                )

                result_map
              else
                # For other nested maps, use recursive merge
                deep_merge_params(existing_val, new_val)
              end

            Logger.debug("deep_merge_params: merged nested map for key #{key}")
            merged

          key, existing_val, _new_val when is_map(existing_val) ->
            # Existing is map but new is not - keep existing map (preserves all fields)
            Logger.debug("deep_merge_params: keeping existing map for key #{key}")
            existing_val

          key, _existing_val, new_val when is_map(new_val) ->
            # New is map but existing is not - use new map, but merge with empty existing to preserve structure
            Logger.debug("deep_merge_params: using new map for key #{key}")

            # Special handling for disediakan_oleh to ensure structure is complete
            if key == "disediakan_oleh" do
              # Ensure all fields exist even if empty
              %{
                "nama" => Map.get(new_val, "nama", ""),
                "jawatan" => Map.get(new_val, "jawatan", ""),
                "tarikh" => Map.get(new_val, "tarikh", "")
              }
            else
              deep_merge_params(%{}, new_val)
            end

          key, existing_val, new_val ->
            # Both are simple values
            # CRITICAL: If new value is empty string and existing has a value, keep existing
            # This prevents empty strings from form data (when field is not focused) from overwriting user input
            result =
              cond do
                # If new value is empty string and existing has a non-empty value, keep existing
                new_val == "" && existing_val != "" && existing_val != nil ->
                  Logger.debug(
                    "deep_merge_params: preserving existing value for key #{key} (new is empty)"
                  )

                  existing_val

                # Otherwise, use new value (user just typed it, even if empty)
                true ->
                  Logger.debug("deep_merge_params: using new value for key #{key}")
                  new_val
              end

            result
        end)

      # CRITICAL: After merging, ensure we haven't lost any nested structure
      # If existing had a nested map but new only had a partial path, we need to preserve the rest
      result = ensure_nested_structure_preserved(existing, new, result)

      Logger.debug("deep_merge_params: final result keys: #{inspect(Map.keys(result))}")
      result
    end
  end

  # Helper to ensure nested structure is preserved when merging
  # This handles cases where new params only contain partial paths (e.g., only fr.pengurusan_data.1.maklumbalas)
  # but existing has complete structure (e.g., fr.pengurusan_data.1.soalan, maklumbalas, catatan)
  defp ensure_nested_structure_preserved(existing, new, merged) do
    # For each top-level key in existing (fr, nfr, etc.)
    Enum.reduce(Map.keys(existing), merged, fn top_key, acc ->
      existing_top = Map.get(existing, top_key)
      new_top = Map.get(new, top_key)
      merged_top = Map.get(acc, top_key)

      # If existing has a map at this level, ensure all nested structure is preserved
      if is_map(existing_top) do
        # If merged doesn't have this key or it's not a map, use existing
        if not is_map(merged_top) do
          Map.put(acc, top_key, existing_top)
        else
          # Recursively ensure nested structure is preserved
          preserved_top =
            ensure_nested_structure_preserved(existing_top, new_top || %{}, merged_top)

          Map.put(acc, top_key, preserved_top)
        end
      else
        acc
      end
    end)
  end

  # Ensure params structure is complete with all required keys
  # This prevents data loss when params come in incomplete
  # IMPORTANT: This function only adds missing structure, it NEVER overwrites existing values
  defp ensure_complete_params(params, fr_categories, nfr_categories) do
    # Start with existing params - preserve all existing data
    result = params

    # Ensure FR structure exists (only if missing)
    result = Map.put_new(result, "fr", %{})

    # Ensure each FR category has complete structure
    result =
      Enum.reduce(fr_categories || [], result, fn category, acc ->
        fr_params = Map.get(acc, "fr", %{})
        category_key = category.key
        # Get existing category params or create empty map
        category_params = Map.get(fr_params, category_key, %{})

        # Ensure each question has a map entry (preserve existing if exists)
        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            # CRITICAL: Only add if doesn't exist - preserve all existing values
            if Map.has_key?(cat_acc, question_no) do
              # Already exists, keep it as-is (preserve user input)
              cat_acc
            else
              # Doesn't exist, add empty map for structure
              Map.put(cat_acc, question_no, %{})
            end
          end)

        updated_fr_params = Map.put(fr_params, category_key, updated_category_params)
        Map.put(acc, "fr", updated_fr_params)
      end)

    # Ensure NFR structure exists (only if missing)
    result = Map.put_new(result, "nfr", %{})

    # Ensure each NFR category has complete structure
    result =
      Enum.reduce(nfr_categories || [], result, fn category, acc ->
        nfr_params = Map.get(acc, "nfr", %{})
        category_key = category.key
        # Get existing category params or create empty map
        category_params = Map.get(nfr_params, category_key, %{})

        # Ensure each question has a map entry (preserve existing if exists)
        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            # CRITICAL: Only add if doesn't exist - preserve all existing values
            if Map.has_key?(cat_acc, question_no) do
              # Already exists, keep it as-is (preserve user input)
              cat_acc
            else
              # Doesn't exist, add empty map for structure
              Map.put(cat_acc, question_no, %{})
            end
          end)

        updated_nfr_params = Map.put(nfr_params, category_key, updated_category_params)
        Map.put(acc, "nfr", updated_nfr_params)
      end)

    # Ensure disediakan_oleh structure exists
    # Only add structure if missing, preserve existing values if present
    existing_disediakan_oleh = Map.get(result, "disediakan_oleh", %{})

    result =
      if map_size(existing_disediakan_oleh) == 0 do
        # Structure doesn't exist, create empty structure
        Map.put(result, "disediakan_oleh", %{
          "nama" => "",
          "jawatan" => "",
          "tarikh" => ""
        })
      else
        # Structure exists, ensure all keys are present but preserve existing values
        updated_disediakan_oleh =
          existing_disediakan_oleh
          |> Map.put_new("nama", "")
          |> Map.put_new("jawatan", "")
          |> Map.put_new("tarikh", "")

        Map.put(result, "disediakan_oleh", updated_disediakan_oleh)
      end

    result
  end

  # Merge soalan values from categories into form params
  # Only adds soalan if it's not already in params (to preserve user input)
  # CRITICAL: This function must preserve ALL existing fields (maklumbalas, catatan, etc.)
  defp merge_soalan_from_categories(params, fr_categories, nfr_categories) do
    # Extract soalan from FR categories
    fr_with_soalan =
      Enum.reduce(fr_categories || [], params, fn category, acc ->
        category_key = category.key
        fr_params = Map.get(acc, "fr", %{})
        category_params = Map.get(fr_params, category_key, %{})

        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            # CRITICAL: Get existing question_params and preserve ALL fields
            question_params = Map.get(cat_acc, question_no, %{})

            # Only add soalan from category if it's not already in params (preserve user input)
            # This preserves ALL other fields (maklumbalas, catatan, etc.)
            updated_question_params =
              if Map.has_key?(question_params, "soalan") do
                # User input exists, keep ALL existing params (including maklumbalas, catatan, etc.)
                question_params
              else
                # No user input for soalan, use value from category if it exists
                # But preserve ALL other existing fields
                if question.soalan && question.soalan != "" do
                  Map.put(question_params, "soalan", question.soalan)
                else
                  question_params
                end
              end

            Map.put(cat_acc, question_no, updated_question_params)
          end)

        updated_fr_params = Map.put(fr_params, category_key, updated_category_params)
        Map.put(acc, "fr", updated_fr_params)
      end)

    # Extract soalan from NFR categories
    final_params =
      Enum.reduce(nfr_categories || [], fr_with_soalan, fn category, acc ->
        category_key = category.key
        nfr_params = Map.get(acc, "nfr", %{})
        category_params = Map.get(nfr_params, category_key, %{})

        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            # CRITICAL: Get existing question_params and preserve ALL fields
            question_params = Map.get(cat_acc, question_no, %{})

            # Only add soalan from category if it's not already in params (preserve user input)
            # This preserves ALL other fields (maklumbalas, catatan, etc.)
            updated_question_params =
              if Map.has_key?(question_params, "soalan") do
                # User input exists, keep ALL existing params (including maklumbalas, catatan, etc.)
                question_params
              else
                # No user input for soalan, use value from category if it exists
                # But preserve ALL other existing fields
                if question.soalan && question.soalan != "" do
                  Map.put(question_params, "soalan", question.soalan)
                else
                  question_params
                end
              end

            Map.put(cat_acc, question_no, updated_question_params)
          end)

        updated_nfr_params = Map.put(nfr_params, category_key, updated_category_params)
        Map.put(acc, "nfr", updated_nfr_params)
      end)

    final_params
  end

  # Safe version of merge_soalan_from_categories that NEVER overwrites existing data
  # Only adds soalan if it doesn't exist, and preserves ALL other fields
  defp merge_soalan_from_categories_safe(params, fr_categories, nfr_categories) do
    # Extract soalan from FR categories - only if not already in params
    fr_with_soalan =
      Enum.reduce(fr_categories || [], params, fn category, acc ->
        category_key = category.key
        fr_params = Map.get(acc, "fr", %{})
        category_params = Map.get(fr_params, category_key, %{})

        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            question_params = Map.get(cat_acc, question_no, %{})

            # CRITICAL: Only add soalan if it doesn't exist AND is not empty string
            # This prevents overwriting user input
            updated_question_params =
              cond do
                # If soalan already exists in params (even if empty), keep it as-is
                Map.has_key?(question_params, "soalan") ->
                  question_params

                # If question has soalan value, add it
                question.soalan && question.soalan != "" ->
                  Map.put(question_params, "soalan", question.soalan)

                # Otherwise, keep params as-is
                true ->
                  question_params
              end

            Map.put(cat_acc, question_no, updated_question_params)
          end)

        updated_fr_params = Map.put(fr_params, category_key, updated_category_params)
        Map.put(acc, "fr", updated_fr_params)
      end)

    # Extract soalan from NFR categories - only if not already in params
    final_params =
      Enum.reduce(nfr_categories || [], fr_with_soalan, fn category, acc ->
        category_key = category.key
        nfr_params = Map.get(acc, "nfr", %{})
        category_params = Map.get(nfr_params, category_key, %{})

        updated_category_params =
          Enum.reduce(category.questions || [], category_params, fn question, cat_acc ->
            question_no = to_string(question.no)
            question_params = Map.get(cat_acc, question_no, %{})

            # CRITICAL: Only add soalan if it doesn't exist AND is not empty string
            # This prevents overwriting user input
            updated_question_params =
              cond do
                # If soalan already exists in params (even if empty), keep it as-is
                Map.has_key?(question_params, "soalan") ->
                  question_params

                # If question has soalan value, add it
                question.soalan && question.soalan != "" ->
                  Map.put(question_params, "soalan", question.soalan)

                # Otherwise, keep params as-is
                true ->
                  question_params
              end

            Map.put(cat_acc, question_no, updated_question_params)
          end)

        updated_nfr_params = Map.put(nfr_params, category_key, updated_category_params)
        Map.put(acc, "nfr", updated_nfr_params)
      end)

    final_params
  end

  # Auto-save data to database to persist user input
  # This ensures data is saved even if user doesn't click "Save" button
  defp auto_save_to_database(socket, final_params) do
    require Logger

    # Only save if we have a soal_selidik_id (existing record) or if we have project_id (new record)
    should_save =
      socket.assigns.soal_selidik_id != nil ||
        (socket.assigns[:project] && socket.assigns.project.id != nil) ||
        Map.get(final_params, "project_id") != nil

    if should_save do
      try do
        # Prepare data for saving
        attrs = prepare_save_data(final_params, socket)
        attrs = Map.put(attrs, :user_id, socket.assigns.current_scope.user.id)

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
            # Update socket with soal_selidik_id if it's a new record
            if socket.assigns.soal_selidik_id == nil do
              assign(socket, :soal_selidik_id, soal_selidik.id)
            else
              socket
            end

          {:error, changeset} ->
            # Log error but don't crash - data will be saved on next validate or manual save
            Logger.warning("Auto-save failed: #{inspect(changeset.errors)}")
            socket
        end
      rescue
        e ->
          # Log error but don't crash - data will be saved on next validate or manual save
          Logger.error("Auto-save error: #{inspect(e)}")
          socket
      end
    else
      # No project_id or soal_selidik_id, can't save yet
      socket
    end
  end
end
