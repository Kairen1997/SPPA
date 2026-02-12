defmodule SppaWeb.AnalisisDanRekabentukLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.AnalisisDanRekabentuk

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Start with no modules; user adds via "Tambah Modul". Use assign only (no stream) so display = modules_list and no duplicate rows.
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Analisis dan Rekabentuk")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/analisis-dan-rekabentuk")
        |> assign(:document_id, "JPKN-BPA-01/B2")
        |> assign(:form, to_form(%{}, as: :analisis_dan_rekabentuk))
        |> assign(:project, nil)
        |> assign(:analisis_dan_rekabentuk_id, nil)
        |> assign(:current_step, 1)
        |> assign(:selected_module_id, nil)
        |> assign(:selected_module, nil)
        |> assign(:expanded_modules, MapSet.new())
        |> assign(:show_pdf_modal, false)
        |> assign(:pdf_data, nil)
        |> assign(:modules_count, 0)
        |> assign(:modules_list, [])
        |> assign(:adding_module, false)
        |> update_summary()

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
  def handle_params(params, uri, socket) do
    socket =
      case project_id_from_request(params, uri) do
        nil ->
          socket

        project_id ->
          current_scope = socket.assigns.current_scope
          user_role = current_scope && current_scope.user && current_scope.user.role

          project =
            if user_role && user_role in @allowed_roles do
              get_project_for_form(project_id, current_scope, user_role)
            else
              nil
            end

          if project do
            # Try to load existing analisis_dan_rekabentuk for this project
            existing_analisis =
              AnalisisDanRekabentuk.get_analisis_dan_rekabentuk_by_project_for_display(
                project_id,
                current_scope
              )

            socket =
              if existing_analisis do
                # Load existing data
                load_existing_analisis(socket, existing_analisis, project)
              else
                # Initialize with project data
                initial_params = %{
                  "nama_projek" => project.nama || "",
                  "nama_agensi" => project.jabatan || ""
                }

                socket
                |> assign(:project, project)
                |> assign(:form, to_form(initial_params, as: :analisis_dan_rekabentuk))
                |> update_summary()
              end

            socket
          else
            socket
          end
      end

    {:noreply, socket}
  end

  defp project_id_from_request(params, uri) do
    with id when is_binary(id) <- params["project_id"] || uri_query_param(uri, "project_id"),
         {num, _} when num > 0 <- Integer.parse(id) do
      num
    else
      _ -> nil
    end
  end

  defp uri_query_param(uri, key) do
    uri = if is_binary(uri), do: URI.parse(uri), else: uri
    if uri.query, do: URI.decode_query(uri.query)[key], else: nil
  end

  # Ensure URL has project_id so that on refresh we load existing analisis (and modules) from DB
  defp ensure_project_id_in_url(socket) do
    case socket.assigns.project do
      %{id: project_id} ->
        push_patch(socket, to: ~p"/analisis-dan-rekabentuk?project_id=#{project_id}")

      _ ->
        socket
    end
  end

  defp get_project_for_form(project_id, _current_scope, _user_role) do
    # Untuk borang Analisis & Rekabentuk, kita benarkan capaian projek
    # berasaskan project_id sahaja (router sudah kawal authentication/role).
    # Nama projek & jabatan diutamakan dari Approved Project.
    case Projects.get_project_by_id(project_id) do
      nil ->
        nil

      project ->
        ap = project.approved_project
        formatted = Projects.format_project_for_display(project)

        formatted
        |> Map.put(:nama, (ap && ap.nama_projek) || formatted.nama)
        |> Map.put(:jabatan, (ap && ap.jabatan) || formatted.jabatan)
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
  def handle_event("generate_pdf", _params, socket) do
    # Generate preview data
    modules = get_modules_from_stream(socket)
    form_data = socket.assigns.form.params || %{}

    dummy_data =
      Sppa.AnalisisDanRekabentuk.pdf_data(
        document_id: socket.assigns.document_id || "JPKN-BPA-01/B2",
        nama_projek: Map.get(form_data, "nama_projek"),
        nama_agensi: Map.get(form_data, "nama_agensi"),
        versi: Map.get(form_data, "versi"),
        tarikh_semakan: Map.get(form_data, "tarikh_semakan"),
        rujukan_perubahan: Map.get(form_data, "rujukan_perubahan"),
        prepared_by_name: Map.get(form_data, "prepared_by_name"),
        prepared_by_position: Map.get(form_data, "prepared_by_position"),
        prepared_by_date: Map.get(form_data, "prepared_by_date"),
        approved_by_name: Map.get(form_data, "approved_by_name"),
        approved_by_position: Map.get(form_data, "approved_by_position"),
        approved_by_date: Map.get(form_data, "approved_by_date"),
        modules: modules
      )

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
  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.current_step || 1

    if current_step > 1 do
      {:noreply, assign(socket, :current_step, current_step - 1)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("go_to_step", %{"step" => step}, socket) do
    step_num = String.to_integer(step)

    if step_num >= 1 and step_num <= 4 do
      {:noreply, assign(socket, :current_step, step_num)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_module", %{"module_id" => module_id}, socket) do
    selected_module = get_selected_module_by_id(socket, module_id)

    {:noreply,
     socket
     |> assign(:selected_module_id, module_id)
     |> assign(:selected_module, selected_module)
     |> assign(:current_step, 3)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step || 1
    max_step = 4

    socket =
      if current_step < max_step do
        new_step = current_step + 1
        # Update selected_module if we're going to step 3
        socket =
          if new_step == 3 and socket.assigns.selected_module_id do
            selected_module = get_selected_module_by_id(socket, socket.assigns.selected_module_id)
            assign(socket, :selected_module, selected_module)
          else
            socket
          end

        assign(socket, :current_step, new_step)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_module_expand", %{"module_id" => module_id}, socket) do
    expanded = socket.assigns.expanded_modules || MapSet.new()

    expanded =
      if MapSet.member?(expanded, module_id) do
        MapSet.delete(expanded, module_id)
      else
        MapSet.put(expanded, module_id)
      end

    {:noreply, assign(socket, :expanded_modules, expanded)}
  end

  @impl true
  def handle_event("validate", %{"analisis_dan_rekabentuk" => params}, socket) do
    form = to_form(params, as: :analisis_dan_rekabentuk)
    {:noreply, socket |> assign(form: form) |> update_summary()}
  end

  @impl true
  def handle_event("save", %{"analisis_dan_rekabentuk" => params}, socket) do
    current_scope = socket.assigns.current_scope
    project = socket.assigns.project
    modules = get_modules_from_stream(socket)

    # Prepare data for database
    attrs =
      %{
        document_id: socket.assigns.document_id || "JPKN-BPA-01/B2",
        nama_projek: Map.get(params, "nama_projek", ""),
        nama_agensi: Map.get(params, "nama_agensi", ""),
        versi: Map.get(params, "versi", ""),
        tarikh_semakan: parse_date(Map.get(params, "tarikh_semakan")),
        rujukan_perubahan: Map.get(params, "rujukan_perubahan", ""),
        prepared_by_name: Map.get(params, "prepared_by_name", ""),
        prepared_by_position: Map.get(params, "prepared_by_position", ""),
        prepared_by_date: parse_date(Map.get(params, "prepared_by_date")),
        approved_by_name: Map.get(params, "approved_by_name", ""),
        approved_by_position: Map.get(params, "approved_by_position", ""),
        approved_by_date: parse_date(Map.get(params, "approved_by_date")),
        project_id: if(project, do: project.id, else: nil),
        modules: modules
      }

    result =
      if socket.assigns.analisis_dan_rekabentuk_id do
        # Update existing record
        existing =
          AnalisisDanRekabentuk.get_analisis_dan_rekabentuk!(
            socket.assigns.analisis_dan_rekabentuk_id,
            current_scope
          )

        AnalisisDanRekabentuk.update_analisis_dan_rekabentuk(existing, attrs)
      else
        # Create new record
        AnalisisDanRekabentuk.create_analisis_dan_rekabentuk(attrs, current_scope)
      end

    case result do
      {:ok, saved_analisis} ->
        # Reload the data into the socket
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :info,
            "Borang verifikasi spesifikasi aplikasi telah disimpan dengan jayanya."
          )
          |> assign(:form, to_form(params, as: :analisis_dan_rekabentuk))
          |> assign(:analisis_dan_rekabentuk_id, saved_analisis.id)
          |> load_existing_analisis(saved_analisis, project)
          |> ensure_project_id_in_url()

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Ralat berlaku semasa menyimpan borang. Sila cuba lagi."
          )
          |> assign(:form, to_form(params, as: :analisis_dan_rekabentuk))

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_module", _params, socket) do
    # Guard: prevent double-add when phx-click fires twice (only 1 in DB but 2 shown)
    if socket.assigns[:adding_module] do
      {:noreply, assign(socket, :adding_module, false)}
    else
      socket = assign(socket, :adding_module, true)

      module_id = "module_#{System.unique_integer([:positive])}"
      next_number = get_next_module_number(socket)

      new_module = %{
        id: module_id,
        number: next_number,
        name: "",
        functions: []
      }

      # Single source of truth: build new list from current modules_list, then set stream from that list (reset: true) so display matches DB
      current_list = get_modules_from_stream(socket)
      new_list = current_list ++ [new_module]

      socket =
        socket
        |> assign(:modules_list, new_list)
        |> update(:modules_count, &(&1 + 1))
        |> update_summary()

      Process.send_after(self(), :clear_adding_module_after_delay, 200)

      case persist_analisis_to_db(socket) do
        {:ok, updated_socket} -> {:noreply, updated_socket}
        {:error, updated_socket} -> {:noreply, updated_socket}
      end
    end
  end

  @impl true
  def handle_event("remove_module", %{"id" => module_id}, socket) do
    modules =
      get_modules_from_stream(socket)
      |> Enum.reject(fn module -> module.id == module_id end)
      |> Enum.with_index(1)
      |> Enum.map(fn {module, new_number} ->
        Map.put(module, :number, new_number)
      end)

    socket =
      socket
      |> assign(:modules_list, modules)
      |> update(:modules_count, fn count -> max(0, count - 1) end)
      |> update_summary()

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event("update_module_name", params, socket) do
    module_id = params["module_id"]
    # phx-blur sends value; phx-change sends module_name
    name = params["module_name"] || params["value"] || ""

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module.id == module_id do
          Map.put(module, :name, name)
        else
          module
        end
      end)

    socket =
      socket
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket =
      if socket.assigns.selected_module_id == module_id do
        selected_module = get_selected_module_by_id(socket, module_id)
        assign(socket, :selected_module, selected_module)
      else
        socket
      end

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event("add_function", %{"module_id" => module_id}, socket) do
    func_id = "func_#{System.unique_integer([:positive])}"

    new_function = %{
      id: func_id,
      name: "",
      sub_functions: []
    }

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module.id == module_id do
          updated_functions = module.functions ++ [new_function]
          Map.put(module, :functions, updated_functions)
        else
          module
        end
      end)

    socket =
      socket
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket =
      if socket.assigns.selected_module_id == module_id do
        selected_module = get_selected_module_by_id(socket, module_id)
        assign(socket, :selected_module, selected_module)
      else
        socket
      end

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event("remove_function", %{"module_id" => module_id, "func_id" => func_id}, socket) do
    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module.id == module_id do
          updated_functions = Enum.reject(module.functions, &(&1.id == func_id))
          Map.put(module, :functions, updated_functions)
        else
          module
        end
      end)

    socket =
      socket
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Refresh selected_module so the deleted function disappears from the "Fungsi Modul" panel
    socket =
      if socket.assigns.selected_module_id == module_id do
        selected_module = get_selected_module_by_id(socket, module_id)
        assign(socket, :selected_module, selected_module)
      else
        socket
      end

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event("update_function_name", params, socket) do
    module_id = params["module_id"]
    func_id = params["func_id"]
    # FunctionInputBlur hook sends "value"; phx-change sends "function_name"
    name = params["function_name"] || params["value"] || ""

    # Normalize IDs for comparison (hook sends strings; in-memory ids may be string or from DB format)
    module_id_norm = module_id && to_string(module_id)
    func_id_norm = func_id && to_string(func_id)

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module_id_norm && to_string(module.id) == module_id_norm do
          updated_functions =
            Enum.map(module.functions, fn func ->
              if func_id_norm && to_string(func.id) == func_id_norm do
                Map.put(func, :name, name)
              else
                func
              end
            end)

          Map.put(module, :functions, updated_functions)
        else
          module
        end
      end)

    socket =
      socket
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket =
      if module_id_norm && to_string(socket.assigns.selected_module_id) == module_id_norm do
        selected_module = get_selected_module_by_id(socket, module_id)
        assign(socket, :selected_module, selected_module)
      else
        socket
      end

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event("add_sub_function", %{"module_id" => module_id, "func_id" => func_id}, socket) do
    sub_func_id = "sub_#{System.unique_integer([:positive])}"

    new_sub_function = %{
      id: sub_func_id,
      name: ""
    }

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module.id == module_id do
          updated_functions =
            Enum.map(module.functions, fn func ->
              if func.id == func_id do
                updated_sub_functions = func.sub_functions ++ [new_sub_function]
                Map.put(func, :sub_functions, updated_sub_functions)
              else
                func
              end
            end)

          Map.put(module, :functions, updated_functions)
        else
          module
        end
      end)

    socket =
      socket
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Refresh selected_module so the new sub-function row appears in the "Fungsi Modul" section
    socket =
      if socket.assigns.selected_module_id == module_id do
        selected_module = get_selected_module_by_id(socket, module_id)
        assign(socket, :selected_module, selected_module)
      else
        socket
      end

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event(
        "remove_sub_function",
        %{"module_id" => module_id, "func_id" => func_id, "sub_func_id" => sub_func_id},
        socket
      ) do
    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module.id == module_id do
          updated_functions =
            Enum.map(module.functions, fn func ->
              if func.id == func_id do
                updated_sub_functions = Enum.reject(func.sub_functions, &(&1.id == sub_func_id))
                Map.put(func, :sub_functions, updated_sub_functions)
              else
                func
              end
            end)

          Map.put(module, :functions, updated_functions)
        else
          module
        end
      end)

    socket =
      socket
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket =
      if socket.assigns.selected_module_id == module_id do
        selected_module = get_selected_module_by_id(socket, module_id)
        assign(socket, :selected_module, selected_module)
      else
        socket
      end

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_event("update_sub_function_name", params, socket) do
    module_id = params["module_id"]
    func_id = params["func_id"]
    sub_func_id = params["sub_func_id"]
    # Value: from unique input name, or LiveView's "value" for the blurred input
    name =
      params["sub_function_name_#{sub_func_id}"] ||
        params["sub_function_name"] ||
        params["value"] ||
        ""

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module.id == module_id do
          updated_functions =
            Enum.map(module.functions, fn func ->
              if func.id == func_id do
                updated_sub_functions =
                  Enum.map(func.sub_functions, fn sub_func ->
                    if sub_func.id == sub_func_id do
                      Map.put(sub_func, :name, name)
                    else
                      sub_func
                    end
                  end)

                Map.put(func, :sub_functions, updated_sub_functions)
              else
                func
              end
            end)

          Map.put(module, :functions, updated_functions)
        else
          module
        end
      end)

    socket =
      socket
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Refresh selected_module so the input shows the saved name
    socket =
      if socket.assigns.selected_module_id == module_id do
        selected_module = get_selected_module_by_id(socket, module_id)
        assign(socket, :selected_module, selected_module)
      else
        socket
      end

    case persist_analisis_to_db(socket) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
      {:error, updated_socket} -> {:noreply, updated_socket}
    end
  end

  @impl true
  def handle_info(:clear_adding_module_after_delay, socket) do
    {:noreply, assign(socket, :adding_module, false)}
  end

  # `Sppa.AnalisisDanRekabentuk.pdf_data/1` now owns preview generation.

  defp get_modules_from_stream(socket) do
    # Use the modules_list assign for processing instead of converting stream
    socket.assigns.modules_list || []
  end

  defp get_next_module_number(socket) do
    # Use modules_count assign to get next number
    (socket.assigns.modules_count || 0) + 1
  end

  defp get_selected_module_by_id(_socket, nil), do: nil

  defp get_selected_module_by_id(socket, module_id) do
    module_id_str = to_string(module_id)

    get_modules_from_stream(socket)
    |> Enum.find_value(fn module ->
      if to_string(module.id) == module_id_str, do: module
    end)
  end

  defp update_summary(socket) do
    modules = get_modules_from_stream(socket)
    form_data = socket.assigns.form.params || %{}

    summary = %{
      nama_projek: Map.get(form_data, "nama_projek", ""),
      nama_agensi: Map.get(form_data, "nama_agensi", ""),
      versi: Map.get(form_data, "versi", ""),
      ringkasan_projek: Map.get(form_data, "ringkasan_projek", ""),
      total_modules: length(modules),
      total_functions:
        modules
        |> Enum.map(fn module -> length(module.functions) end)
        |> Enum.sum(),
      platform: Map.get(form_data, "platform_sistem", ""),
      user_roles: Map.get(form_data, "user_roles", "")
    }

    assign(socket, :summary, summary)
  end

  defp load_existing_analisis(socket, analisis_dan_rekabentuk, project) do
    # Convert database format to LiveView format
    liveview_data = AnalisisDanRekabentuk.to_liveview_format(analisis_dan_rekabentuk)

    # Prepare form params
    form_params = %{
      "nama_projek" => liveview_data.nama_projek || "",
      "nama_agensi" => liveview_data.nama_agensi || "",
      "versi" => liveview_data.versi || "",
      "tarikh_semakan" => format_date_for_input(liveview_data.tarikh_semakan),
      "rujukan_perubahan" => liveview_data.rujukan_perubahan || "",
      "prepared_by_name" => liveview_data.prepared_by_name || "",
      "prepared_by_position" => liveview_data.prepared_by_position || "",
      "prepared_by_date" => format_date_for_input(liveview_data.prepared_by_date),
      "approved_by_name" => liveview_data.approved_by_name || "",
      "approved_by_position" => liveview_data.approved_by_position || "",
      "approved_by_date" => format_date_for_input(liveview_data.approved_by_date)
    }

    # Load modules into assign (single source of truth for display)
    modules = liveview_data.modules

    socket
    |> assign(:project, project)
    |> assign(:analisis_dan_rekabentuk_id, analisis_dan_rekabentuk.id)
    |> assign(:document_id, liveview_data.document_id)
    |> assign(:form, to_form(form_params, as: :analisis_dan_rekabentuk))
    |> assign(:modules_list, modules)
    |> assign(:modules_count, length(modules))
    |> update_summary()
  end

  defp format_date_for_input(nil), do: ""
  defp format_date_for_input(%Date{} = date), do: Date.to_string(date)
  defp format_date_for_input(date_string) when is_binary(date_string), do: date_string
  defp format_date_for_input(_), do: ""

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp parse_date(_), do: nil

  # Auto-save to DB (used after module/function/sub_function changes so user doesn't need to click Simpan)
  defp persist_analisis_to_db(socket) do
    current_scope = socket.assigns.current_scope

    if current_scope && current_scope.user do
      do_persist_analisis_to_db(socket, current_scope)
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(
          :error,
          "Sesi tidak sah. Sila log masuk semula."
        )

      {:error, socket}
    end
  end

  defp do_persist_analisis_to_db(socket, current_scope) do
    project = socket.assigns.project
    params = socket.assigns.form.params || %{}
    modules = get_modules_from_stream(socket)

    attrs =
      %{
        document_id: socket.assigns.document_id || "JPKN-BPA-01/B2",
        nama_projek: Map.get(params, "nama_projek", ""),
        nama_agensi: Map.get(params, "nama_agensi", ""),
        versi: Map.get(params, "versi", ""),
        tarikh_semakan: parse_date(Map.get(params, "tarikh_semakan")),
        rujukan_perubahan: Map.get(params, "rujukan_perubahan", ""),
        prepared_by_name: Map.get(params, "prepared_by_name", ""),
        prepared_by_position: Map.get(params, "prepared_by_position", ""),
        prepared_by_date: parse_date(Map.get(params, "prepared_by_date")),
        approved_by_name: Map.get(params, "approved_by_name", ""),
        approved_by_position: Map.get(params, "approved_by_position", ""),
        approved_by_date: parse_date(Map.get(params, "approved_by_date")),
        project_id: if(project, do: project.id, else: nil),
        modules: modules
      }

    result =
      try do
        if socket.assigns.analisis_dan_rekabentuk_id do
          existing =
            AnalisisDanRekabentuk.get_analisis_dan_rekabentuk(
              socket.assigns.analisis_dan_rekabentuk_id,
              current_scope
            )

          if existing do
            AnalisisDanRekabentuk.update_analisis_dan_rekabentuk(existing, attrs)
          else
            # Record was deleted or no longer accessible; create new instead of crashing
            AnalisisDanRekabentuk.create_analisis_dan_rekabentuk(attrs, current_scope)
          end
        else
          AnalisisDanRekabentuk.create_analisis_dan_rekabentuk(attrs, current_scope)
        end
      rescue
        e ->
          require Logger
          Logger.error("persist_analisis_to_db failed: #{inspect(e)}")
          {:error, %Ecto.Changeset{}}
      end

    case result do
      {:ok, saved_analisis} ->
        # Only set id so next auto-save or Simpan uses update; don't reload stream to avoid losing UI state / selection
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:info, "Perubahan telah disimpan secara automatik.")
          |> assign(:analisis_dan_rekabentuk_id, saved_analisis.id)
          |> ensure_project_id_in_url()

        {:ok, socket}

      {:error, error} ->
        changeset =
          cond do
            is_struct(error, Ecto.Changeset) ->
              error

            is_tuple(error) and tuple_size(error) == 2 ->
              case elem(error, 1) do
                cs when is_struct(cs, Ecto.Changeset) -> cs
                _ -> nil
              end

            true ->
              nil
          end

        require Logger

        if changeset do
          Logger.warning(
            "persist_analisis_to_db failed: #{inspect(Ecto.Changeset.traverse_errors(changeset, &translate_error/1))}"
          )
        else
          Logger.warning("persist_analisis_to_db failed: #{inspect(error)}")
        end

        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Ralat berlaku semasa menyimpan. Sila cuba lagi atau klik Simpan."
          )

        {:error, socket}
    end
  end
end
