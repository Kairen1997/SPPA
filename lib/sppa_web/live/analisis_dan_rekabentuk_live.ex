defmodule SppaWeb.AnalisisDanRekabentukLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Start with no modules; user adds via "Tambah Modul"
      socket = stream_configure(socket, :modules, dom_id: &"module_#{&1.id}")
      socket = stream(socket, :modules, [], reset: true)

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
        |> assign(:current_step, 1)
        |> assign(:selected_module_id, nil)
        |> assign(:selected_module, nil)
        |> assign(:expanded_modules, MapSet.new())
        |> assign(:show_pdf_modal, false)
        |> assign(:pdf_data, nil)
        |> assign(:modules_count, 0)
        |> assign(:modules_list, [])
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
            initial_params = %{
              "nama_projek" => project.nama || "",
              "nama_agensi" => project.jabatan || ""
            }

            socket
            |> assign(:project, project)
            |> assign(:form, to_form(initial_params, as: :analisis_dan_rekabentuk))
            |> update_summary()
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

  defp get_project_for_form(project_id, current_scope, user_role) do
    current_user_id = current_scope.user.id

    project =
      case user_role do
        "ketua penolong pengarah" ->
          Projects.get_project_by_id(project_id)

        "pembangun sistem" ->
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.developer_id == current_user_id, do: p, else: nil
          end

        "pengurus projek" ->
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.project_manager_id == current_user_id, do: p, else: nil
          end

        _ ->
          nil
      end

    if project do
      Projects.format_project_for_display(project)
    else
      nil
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
    # For now, just show a success message
    # Later, this will save to the database
    socket =
      socket
      |> Phoenix.LiveView.put_flash(
        :info,
        "Borang verifikasi spesifikasi aplikasi telah disimpan dengan jayanya."
      )
      |> assign(:form, to_form(params, as: :analisis_dan_rekabentuk))

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_module", _params, socket) do
    module_id = "module_#{System.unique_integer([:positive])}"

    # Get next module number
    next_number = get_next_module_number(socket)

    new_module = %{
      id: module_id,
      number: next_number,
      name: "",
      functions: []
    }

    {:noreply,
     socket
     |> stream(:modules, [new_module])
     |> update(:modules_list, fn list -> (list || []) ++ [new_module] end)
     |> update(:modules_count, &(&1 + 1))
     |> update_summary()}
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

    {:noreply,
     socket
     |> stream(:modules, modules, reset: true)
     |> assign(:modules_list, modules)
     |> update(:modules_count, fn count -> max(0, count - 1) end)
     |> update_summary()}
  end

  @impl true
  def handle_event("update_module_name", params, socket) do
    module_id = params["module_id"]
    name = params["module_name"] || ""

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
      |> stream(:modules, updated_modules, reset: true)
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

    {:noreply, socket}
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
      |> stream(:modules, updated_modules, reset: true)
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

    {:noreply, socket}
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

    {:noreply,
     socket
     |> stream(:modules, updated_modules, reset: true)
     |> assign(:modules_list, updated_modules)
     |> update_summary()}
  end

  @impl true
  def handle_event("update_function_name", params, socket) do
    module_id = params["module_id"]
    func_id = params["func_id"]
    name = params["function_name"] || ""

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn module ->
        if module.id == module_id do
          updated_functions =
            Enum.map(module.functions, fn func ->
              if func.id == func_id do
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
      |> stream(:modules, updated_modules, reset: true)
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

    {:noreply, socket}
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

    {:noreply,
     socket
     |> stream(:modules, updated_modules, reset: true)
     |> assign(:modules_list, updated_modules)
     |> update_summary()}
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
      |> stream(:modules, updated_modules, reset: true)
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

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_sub_function_name", params, socket) do
    module_id = params["module_id"]
    func_id = params["func_id"]
    sub_func_id = params["sub_func_id"]
    name = params["sub_function_name"] || ""

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

    {:noreply,
     socket
     |> stream(:modules, updated_modules, reset: true)
     |> assign(:modules_list, updated_modules)
     |> update_summary()}
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

  defp get_selected_module_by_id(socket, module_id) do
    get_modules_from_stream(socket)
    |> Enum.find_value(fn module ->
      if module.id == module_id, do: module
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
end
