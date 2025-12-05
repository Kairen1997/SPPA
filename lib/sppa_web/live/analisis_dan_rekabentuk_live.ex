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

      # Initialize modules as a stream
      socket =
        initial_modules
        |> Enum.reduce(socket, fn module, acc ->
          stream(acc, :modules, [module])
        end)
        |> assign(:modules_count, length(initial_modules))

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
  def handle_event("validate", %{"analisis_dan_rekabentuk" => params}, socket) do
    form = to_form(params, as: :analisis_dan_rekabentuk)
    {:noreply, assign(socket, form: form)}
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
     |> update(:modules_count, &(&1 + 1))}
  end

  @impl true
  def handle_event("remove_module", %{"id" => module_id}, socket) do
    modules =
      get_modules_from_stream(socket)
      |> Enum.reject(fn {_id, module} -> module.id == module_id end)
      |> Enum.with_index(1)
      |> Enum.map(fn {{id, module}, new_number} ->
        {id, Map.put(module, :number, new_number)}
      end)

    {:noreply,
     socket
     |> stream(:modules, modules, reset: true)
     |> update(:modules_count, fn count -> max(0, count - 1) end)}
  end

  @impl true
  def handle_event("update_module_name", params, socket) do
    module_id = params["module_id"]
    name = params["module_name"] || ""

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn {id, module} ->
        if module.id == module_id do
          {id, Map.put(module, :name, name)}
        else
          {id, module}
        end
      end)

    {:noreply, stream(socket, :modules, updated_modules, reset: true)}
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
      |> Enum.map(fn {id, module} ->
        if module.id == module_id do
          updated_functions = module.functions ++ [new_function]
          {id, Map.put(module, :functions, updated_functions)}
        else
          {id, module}
        end
      end)

    {:noreply, stream(socket, :modules, updated_modules, reset: true)}
  end

  @impl true
  def handle_event("remove_function", %{"module_id" => module_id, "func_id" => func_id}, socket) do
    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn {id, module} ->
        if module.id == module_id do
          updated_functions = Enum.reject(module.functions, &(&1.id == func_id))
          {id, Map.put(module, :functions, updated_functions)}
        else
          {id, module}
        end
      end)

    {:noreply, stream(socket, :modules, updated_modules, reset: true)}
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

    {:noreply, stream(socket, :modules, updated_modules, reset: true)}
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
      |> Enum.map(fn {id, module} ->
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
          {id, Map.put(module, :functions, updated_functions)}
        else
          {id, module}
        end
      end)

    {:noreply, stream(socket, :modules, updated_modules, reset: true)}
  end

  @impl true
  def handle_event("remove_sub_function", %{"module_id" => module_id, "func_id" => func_id, "sub_func_id" => sub_func_id}, socket) do
    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn {id, module} ->
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
          {id, Map.put(module, :functions, updated_functions)}
        else
          {id, module}
        end
      end)

    {:noreply, stream(socket, :modules, updated_modules, reset: true)}
  end

  @impl true
  def handle_event("update_sub_function_name", params, socket) do
    module_id = params["module_id"]
    func_id = params["func_id"]
    sub_func_id = params["sub_func_id"]
    name = params["sub_function_name"] || ""

    updated_modules =
      get_modules_from_stream(socket)
      |> Enum.map(fn {id, module} ->
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
          {id, Map.put(module, :functions, updated_functions)}
        else
          {id, module}
        end
      end)

    {:noreply, stream(socket, :modules, updated_modules, reset: true)}
  end

  defp get_modules_from_stream(socket) do
    case Map.get(socket.assigns.streams || %{}, :modules) do
      %Phoenix.LiveView.LiveStream{} = stream -> Enum.to_list(stream)
      _ -> []
    end
  end

  defp get_next_module_number(socket) do
    # Use modules_count assign to get next number
    (socket.assigns.modules_count || 0) + 1
  end
end
