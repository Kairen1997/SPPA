defmodule SppaWeb.AnalisisDanRekabentukLive do
  use SppaWeb, :live_view

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]


  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Initialize modules
      initial_modules = [
        %{
          id: "module_1",
          number: 1,
          name: "Modul Pengurusan Pengguna",
          functions: [
            %{id: "func_1_1", name: "Pendaftaran Pengguna", sub_functions: [%{id: "sub_1_1_1", name: "Pengesahan Pendaftaran"}]},
            %{id: "func_1_2", name: "Laman Log Masuk", sub_functions: []},
            %{id: "func_1_3", name: "Penyelenggaraan Profail", sub_functions: [%{id: "sub_1_3_1", name: "Pengemaskinian Profil"}]}
          ]
        },
        %{
          id: "module_2",
          number: 2,
          name: "Penyelenggaraan Kata Laluan",
          functions: []
        },
        %{
          id: "module_3",
          number: 3,
          name: "Modul Permohonan",
          functions: [
            %{id: "func_3_1", name: "Pendaftaran Permohonan", sub_functions: []},
            %{id: "func_3_2", name: "Kemaskini Permohonan", sub_functions: []},
            %{id: "func_3_3", name: "Semakan Status Permohonan", sub_functions: []}
          ]
        },
        %{
          id: "module_4",
          number: 4,
          name: "Modul Pengurusan Permohonan",
          functions: [
            %{id: "func_4_1", name: "Verifikasi Permohonan", sub_functions: []},
            %{id: "func_4_2", name: "Kelulusan Permohonan", sub_functions: []}
          ]
        },
        %{
          id: "module_5",
          number: 5,
          name: "Modul Laporan",
          functions: [
            %{id: "func_5_1", name: "Laporan mengikut tahun", sub_functions: []},
            %{id: "func_5_2", name: "Laporan mengikut lokasi/daerah", sub_functions: []}
          ]
        },
        %{
          id: "module_6",
          number: 6,
          name: "Modul Dashboard",
          functions: []
        }
      ]

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Analisis dan Rekabentuk")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:current_path, "/analisis-dan-rekabentuk")
        |> assign(:document_id, "JPKN-BPA-01/B2")
        |> assign(:form, to_form(%{}, as: :analisis_dan_rekabentuk))
        |> assign(:current_step, 1)
        |> assign(:selected_module_id, nil)
        |> assign(:selected_module, nil)
        |> assign(:expanded_modules, MapSet.new())
        |> assign(:show_pdf_modal, false)
        |> assign(:pdf_data, nil)

      # Initialize modules as a stream and also keep a list for processing
      # Configure stream to use module.id as the DOM id
      socket = stream_configure(socket, :modules, dom_id: &"module_#{&1.id}")

      socket =
        initial_modules
        |> Enum.reduce(socket, fn module, acc ->
          stream(acc, :modules, [module])
        end)
        |> assign(:modules_count, length(initial_modules))
        |> assign(:modules_list, initial_modules)
        |> update_summary()

      {:ok, socket}
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
    {:noreply, update(socket, :notifications_open, &(!&1))}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
  end

  @impl true
  def handle_event("generate_pdf", _params, socket) do
    # Generate dummy data
    dummy_data = generate_dummy_data(socket)

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

    socket = if current_step < max_step do
      new_step = current_step + 1
      # Update selected_module if we're going to step 3
      socket = if new_step == 3 and socket.assigns.selected_module_id do
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
      |> Phoenix.LiveView.put_flash(:info, "Borang verifikasi spesifikasi aplikasi telah disimpan dengan jayanya.")
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

    socket = socket
      |> stream(:modules, updated_modules, reset: true)
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket = if socket.assigns.selected_module_id == module_id do
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

    socket = socket
      |> stream(:modules, updated_modules, reset: true)
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket = if socket.assigns.selected_module_id == module_id do
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

    {:noreply, socket
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
      |> Enum.map(fn {id, module} ->
        if module.id == module_id do
          updated_functions =
            Enum.map(module.functions, fn func ->
              if func.id == func_id do
                Map.put(func, :name, name)
              else
                func
              end
            end)
          {id, Map.put(module, :functions, updated_functions)}
        else
          {id, module}
        end
      end)

    socket = socket
      |> stream(:modules, updated_modules, reset: true)
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket = if socket.assigns.selected_module_id == module_id do
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

    {:noreply, socket
      |> stream(:modules, updated_modules, reset: true)
      |> assign(:modules_list, updated_modules)
      |> update_summary()}
  end

  @impl true
  def handle_event("remove_sub_function", %{"module_id" => module_id, "func_id" => func_id, "sub_func_id" => sub_func_id}, socket) do
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

    socket = socket
      |> stream(:modules, updated_modules, reset: true)
      |> assign(:modules_list, updated_modules)
      |> update_summary()

    # Update selected_module if it's the one being edited
    socket = if socket.assigns.selected_module_id == module_id do
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

    {:noreply, socket
      |> stream(:modules, updated_modules, reset: true)
      |> assign(:modules_list, updated_modules)
      |> update_summary()}
  end

  defp generate_dummy_data(socket) do
    modules = get_modules_from_stream(socket)
    form_data = socket.assigns.form.params || %{}

    # Get current date in DD/MM/YYYY format
    today =
      Date.utc_today()
      |> Date.to_string()
      |> String.split("-")
      |> Enum.reverse()
      |> Enum.join("/")

    %{
      document_id: socket.assigns.document_id || "JPKN-BPA-01/B2",
      nama_projek: Map.get(form_data, "nama_projek") || "Sistem Pengurusan Permohonan Aplikasi (SPPA)",
      nama_agensi: Map.get(form_data, "nama_agensi") || "Jabatan Pendaftaran Negara Sabah (JPKN)",
      versi: Map.get(form_data, "versi") || "1.0.0",
      tarikh_semakan: Map.get(form_data, "tarikh_semakan") || today,
      rujukan_perubahan: Map.get(form_data, "rujukan_perubahan") || "Mesyuarat Jawatankuasa Teknologi Maklumat - 15 Disember 2024",
      modules: modules,
      total_modules: length(modules),
      total_functions:
        modules
        |> Enum.map(fn module -> length(module.functions) end)
        |> Enum.sum(),
      prepared_by_name: Map.get(form_data, "prepared_by_name") || "Ahmad bin Abdullah",
      prepared_by_position: Map.get(form_data, "prepared_by_position") || "Pengurus Projek",
      prepared_by_date: Map.get(form_data, "prepared_by_date") || today,
      approved_by_name: Map.get(form_data, "approved_by_name") || "Dr. Siti binti Hassan",
      approved_by_position: Map.get(form_data, "approved_by_position") || "Ketua Penolong Pengarah",
      approved_by_date: Map.get(form_data, "approved_by_date") || today
    }
  end

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
