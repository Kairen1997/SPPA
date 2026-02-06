defmodule SppaWeb.UjianKeselamatanLive do
  use SppaWeb, :live_view

  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.Projects
  alias Sppa.UjianKeselamatan

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"project_id" => project_id, "id" => id}, _session, socket) do
    mount_show(id, socket, String.to_integer(project_id))
  end

  def mount(%{"project_id" => project_id}, _session, socket) do
    mount_index(socket, String.to_integer(project_id))
  end

  def mount(%{"id" => _id}, _session, socket) do
    # Tanpa project_id, redirect ke senarai projek supaya URL sentiasa ada project id
    {:ok,
     socket
     |> put_flash(:info, "Sila pilih projek untuk mengakses Ujian Keselamatan.")
     |> redirect(to: ~p"/projek")}
  end

  def mount(_params, _session, socket) do
    # Tanpa project_id, redirect ke senarai projek supaya URL sentiasa ada project id
    {:ok,
     socket
     |> put_flash(:info, "Sila pilih projek untuk mengakses Ujian Keselamatan.")
     |> redirect(to: ~p"/projek")}
  end

  defp index_path(project_id), do: ~p"/projek/#{project_id}/ujian-keselamatan"

  # Builds one row per module from Analisis dan Rekabentuk. If ujian data exists at same
  # index it is merged; otherwise a row with defaults is used. Rows follow module count.
  defp build_ujian_rows_from_modules(modules_from_analisis, ujian_raw) do
    Enum.with_index(modules_from_analisis, 0)
    |> Enum.map(fn {mod, idx} ->
      ujian = Enum.at(ujian_raw, idx)

      if ujian do
        ujian
        |> Map.put(:nama_modul, mod[:name] || mod.name || "")
      else
        %{
          id: mod[:id] || "module_#{idx}",
          nama_modul: mod[:name] || mod.name || "",
          status: "Menunggu",
          tarikh_ujian: nil,
          tarikh_dijangka_siap: nil,
          penguji: nil,
          hasil: "Belum Selesai",
          catatan: nil,
          disahkan_oleh: nil
        }
      end
    end)
  end

  defp mount_index(socket, project_id) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Get safety tests (ujian keselamatan); optional project scope for future filtering
      ujian_raw = UjianKeselamatan.list_ujian()
      project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)

      project_assigns_and_path =
        if project do
          {[project_id: project_id, project: project], "/projek/#{project_id}/ujian-keselamatan"}
        else
          nil
        end

      if project_assigns_and_path == nil do
        {:ok,
         socket
         |> put_flash(:error, "Projek tidak dijumpai atau anda tidak mempunyai akses.")
         |> redirect(to: ~p"/projek")}
      else
        {project_assigns, current_path} = project_assigns_and_path

        modules_from_analisis =
          AnalisisDanRekabentuk.list_modules_for_project(project_id, socket.assigns.current_scope)

        ujian = build_ujian_rows_from_modules(modules_from_analisis, ujian_raw)

        socket =
          socket
          |> assign(:hide_root_header, true)
          |> assign(:page_title, "Ujian Keselamatan")
          |> assign(:sidebar_open, false)
          |> assign(:notifications_open, false)
          |> assign(:profile_menu_open, false)
          |> assign(:current_path, current_path)
          |> assign(:index_path, index_path(project_id))
          |> assign(project_assigns)
          |> assign(:ujian, ujian)
          |> assign(:show_edit_modal, false)
          |> assign(:show_edit_kes_modal, false)
          |> assign(:selected_ujian, nil)
          |> assign(:selected_kes, nil)
          |> assign(:form, to_form(%{}, as: :ujian))
          |> assign(:kes_form, to_form(%{}, as: :kes))

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

  defp mount_show(ujian_id, socket, project_id) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      back_path = index_path(project_id)
      project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)
      project_assigns = if project, do: [project_id: project_id, project: project], else: nil

      if project_assigns == nil do
        {:ok,
         socket
         |> put_flash(:error, "Projek tidak dijumpai atau anda tidak mempunyai akses.")
         |> redirect(to: ~p"/projek")}
      else
        current_path = "/projek/#{project_id}/ujian-keselamatan"

        socket =
          socket
          |> assign(:hide_root_header, true)
          |> assign(:page_title, "Butiran Ujian Keselamatan")
          |> assign(:sidebar_open, false)
          |> assign(:notifications_open, false)
          |> assign(:profile_menu_open, false)
          |> assign(:current_path, current_path)
          |> assign(:index_path, back_path)
          |> assign(project_assigns)

        if connected?(socket) do
          ujian = get_ujian_by_id(ujian_id)

          if ujian do
            activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
            notifications_count = length(activities)

            {:ok,
             socket
             |> assign(:selected_ujian, ujian)
             |> assign(:ujian, [])
             |> assign(:show_edit_modal, false)
             |> assign(:show_edit_kes_modal, false)
             |> assign(:selected_kes, nil)
             |> assign(:form, to_form(%{}, as: :ujian))
             |> assign(:kes_form, to_form(%{}, as: :kes))
             |> assign(:activities, activities)
             |> assign(:notifications_count, notifications_count)}
          else
            socket =
              socket
              |> Phoenix.LiveView.put_flash(
                :error,
                "Ujian keselamatan tidak dijumpai."
              )
              |> Phoenix.LiveView.redirect(to: back_path)

            {:ok, socket}
          end
        else
          {:ok,
           socket
           |> assign(:selected_ujian, nil)
           |> assign(:ujian, [])
           |> assign(:show_edit_modal, false)
           |> assign(:show_edit_kes_modal, false)
           |> assign(:selected_kes, nil)
           |> assign(:form, to_form(%{}, as: :ujian))
           |> assign(:kes_form, to_form(%{}, as: :kes))
           |> assign(:activities, [])
           |> assign(:notifications_count, 0)}
        end
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

  # Get ujian by id
  defp get_ujian_by_id(ujian_id) do
    UjianKeselamatan.list_ujian()
    |> Enum.find(fn u -> u.id == ujian_id end)
  end

  defp get_project_by_id(project_id, current_scope, user_role) do
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
      project
      |> Projects.format_project_for_display()
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
  def handle_event("open_edit_modal", %{"ujian_id" => ujian_id}, socket) do
    # Try to find ujian from list first, then from selected_ujian
    ujian =
      if socket.assigns[:ujian] && length(socket.assigns.ujian) > 0 do
        Enum.find(socket.assigns.ujian, fn u -> u.id == ujian_id end)
      else
        if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.id == ujian_id do
          socket.assigns.selected_ujian
        else
          get_ujian_by_id(ujian_id)
        end
      end

    if ujian do
      form_data = %{
        "tajuk" => ujian.tajuk,
        "modul" => ujian.modul,
        "tarikh_ujian" => Calendar.strftime(ujian.tarikh_ujian, "%Y-%m-%d"),
        "tarikh_dijangka_siap" => Calendar.strftime(ujian.tarikh_dijangka_siap, "%Y-%m-%d"),
        "status" => ujian.status,
        "penguji" => ujian.penguji || "",
        "hasil" => ujian.hasil || "",
        "catatan" => ujian.catatan || ""
      }

      form = to_form(form_data, as: :ujian)

      {:noreply,
       socket
       |> assign(:show_edit_modal, true)
       |> assign(:editing_ujian, ujian)
       |> assign(:form, form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_edit_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_modal, false)
     |> assign(:editing_ujian, nil)
     |> assign(:form, to_form(%{}, as: :ujian))}
  end

  @impl true
  def handle_event("validate_ujian", %{"ujian" => ujian_params}, socket) do
    form = to_form(ujian_params, as: :ujian)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("update_ujian", %{"ujian" => ujian_params}, socket) do
    # TODO: In the future, this should update the database
    editing_ujian = socket.assigns[:editing_ujian] || socket.assigns[:selected_ujian]

    if editing_ujian do
      ujian_id = editing_ujian.id

      tarikh_ujian =
        if ujian_params["tarikh_ujian"] && ujian_params["tarikh_ujian"] != "" do
          case Date.from_iso8601(ujian_params["tarikh_ujian"]) do
            {:ok, date} -> date
            _ -> editing_ujian.tarikh_ujian
          end
        else
          editing_ujian.tarikh_ujian
        end

      tarikh_dijangka_siap =
        case Date.from_iso8601(ujian_params["tarikh_dijangka_siap"]) do
          {:ok, date} -> date
          _ -> editing_ujian.tarikh_dijangka_siap
        end

      updated_ujian_data = %{
        editing_ujian
        | tajuk: ujian_params["tajuk"] || editing_ujian.tajuk,
          modul: ujian_params["modul"],
          tarikh_ujian: tarikh_ujian,
          tarikh_dijangka_siap: tarikh_dijangka_siap,
          status: ujian_params["status"],
          penguji: ujian_params["penguji"] || "",
          hasil: ujian_params["hasil"] || editing_ujian.hasil,
          catatan: if(ujian_params["catatan"] == "", do: nil, else: ujian_params["catatan"])
      }

      # Update in list if we're on index page
      updated_ujian_list =
        if socket.assigns[:ujian] && length(socket.assigns.ujian) > 0 do
          Enum.map(socket.assigns.ujian, fn ujian ->
            if ujian.id == ujian_id, do: updated_ujian_data, else: ujian
          end)
        else
          []
        end

      # Update selected_ujian if we're on detail page
      updated_socket =
        socket
        |> assign(:ujian, updated_ujian_list)
        |> assign(:show_edit_modal, false)
        |> assign(:editing_ujian, nil)
        |> assign(:form, to_form(%{}, as: :ujian))
        |> put_flash(:info, "Ujian keselamatan berjaya dikemaskini")

      # Only update selected_ujian if we're on detail page
      final_socket =
        if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.id == ujian_id do
          assign(updated_socket, :selected_ujian, updated_ujian_data)
        else
          updated_socket
        end

      {:noreply, final_socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_kes_ujian", %{"kes_id" => kes_id}, socket) do
    if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.senarai_kes_ujian do
      kes = Enum.find(socket.assigns.selected_ujian.senarai_kes_ujian, fn k -> k.id == kes_id end)

      if kes do
        form_data = %{
          "senario" => kes.senario || "",
          "langkah" => kes.langkah || "",
          "keputusan_dijangka" => kes.keputusan_dijangka || "",
          "keputusan_sebenar" => kes.keputusan_sebenar || "",
          "hasil" => kes.hasil || "",
          "penguji" => Map.get(kes, :penguji, "") || "",
          "tarikh_ujian" =>
            if(kes.tarikh_ujian, do: Calendar.strftime(kes.tarikh_ujian, "%Y-%m-%d"), else: ""),
          "disahkan" => if(Map.get(kes, :disahkan, false), do: "true", else: ""),
          "disahkan_oleh" => Map.get(kes, :disahkan_oleh, "") || "",
          "tarikh_pengesahan" =>
            if(kes.tarikh_pengesahan,
              do: Calendar.strftime(kes.tarikh_pengesahan, "%Y-%m-%d"),
              else: ""
            )
        }

        form = to_form(form_data, as: :kes)

        {:noreply,
         socket
         |> assign(:show_edit_kes_modal, true)
         |> assign(:selected_kes, kes)
         |> assign(:kes_form, form)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_edit_kes_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_edit_kes_modal, false)
     |> assign(:selected_kes, nil)
     |> assign(:kes_form, to_form(%{}, as: :kes))}
  end

  @impl true
  def handle_event("validate_kes", %{"kes" => kes_params}, socket) do
    form = to_form(kes_params, as: :kes)
    {:noreply, assign(socket, :kes_form, form)}
  end

  @impl true
  def handle_event("update_kes", %{"kes" => kes_params}, socket) do
    # TODO: In the future, this should update the database
    kes_id = socket.assigns.selected_kes.id

    tarikh_ujian =
      if kes_params["tarikh_ujian"] && kes_params["tarikh_ujian"] != "" do
        case Date.from_iso8601(kes_params["tarikh_ujian"]) do
          {:ok, date} -> date
          _ -> Map.get(socket.assigns.selected_kes, :tarikh_ujian, nil)
        end
      else
        Map.get(socket.assigns.selected_kes, :tarikh_ujian, nil)
      end

    tarikh_pengesahan =
      if kes_params["tarikh_pengesahan"] && kes_params["tarikh_pengesahan"] != "" do
        case Date.from_iso8601(kes_params["tarikh_pengesahan"]) do
          {:ok, date} -> date
          _ -> Map.get(socket.assigns.selected_kes, :tarikh_pengesahan, nil)
        end
      else
        Map.get(socket.assigns.selected_kes, :tarikh_pengesahan, nil)
      end

    updated_kes_data = %{
      socket.assigns.selected_kes
      | senario: kes_params["senario"] || socket.assigns.selected_kes.senario,
        langkah: kes_params["langkah"] || "",
        keputusan_dijangka: kes_params["keputusan_dijangka"] || "",
        keputusan_sebenar:
          if(kes_params["keputusan_sebenar"] == "",
            do: nil,
            else: kes_params["keputusan_sebenar"]
          ),
        hasil: if(kes_params["hasil"] == "", do: nil, else: kes_params["hasil"]),
        penguji: if(kes_params["penguji"] == "", do: nil, else: kes_params["penguji"]),
        tarikh_ujian: tarikh_ujian,
        disahkan: kes_params["disahkan"] == "true",
        disahkan_oleh:
          if(kes_params["disahkan_oleh"] == "",
            do: nil,
            else: kes_params["disahkan_oleh"]
          ),
        tarikh_pengesahan: tarikh_pengesahan
    }

    # Update kes in selected_ujian's senarai_kes_ujian
    updated_senarai_kes_ujian =
      Enum.map(socket.assigns.selected_ujian.senarai_kes_ujian, fn kes ->
        if kes.id == kes_id, do: updated_kes_data, else: kes
      end)

    updated_ujian = %{
      socket.assigns.selected_ujian
      | senarai_kes_ujian: updated_senarai_kes_ujian
    }

    {:noreply,
     socket
     |> assign(:selected_ujian, updated_ujian)
     |> assign(:selected_kes, updated_kes_data)
     |> assign(:show_edit_kes_modal, false)
     |> assign(:kes_form, to_form(%{}, as: :kes))
     |> put_flash(:info, "Kes ujian berjaya dikemaskini")}
  end

  @impl true
  def handle_event("add_new_kes", _params, socket) do
    if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.senarai_kes_ujian do
      # Generate new ID based on existing kes
      existing_ids =
        Enum.map(socket.assigns.selected_ujian.senarai_kes_ujian, fn kes -> kes.id end)

      new_number =
        existing_ids
        |> Enum.map(fn id ->
          case Regex.run(~r/SEC-(\d+)/, id) do
            [_, num_str] -> String.to_integer(num_str)
            _ -> 0
          end
        end)
        |> Enum.max(fn -> 0 end)
        |> Kernel.+(1)

      new_id = "SEC-#{String.pad_leading(Integer.to_string(new_number), 3, "0")}"

      new_kes = %{
        id: new_id,
        senario: "",
        langkah: "",
        keputusan_dijangka: "",
        keputusan_sebenar: nil,
        hasil: nil,
        penguji: nil,
        tarikh_ujian: nil,
        disahkan: false,
        disahkan_oleh: nil,
        tarikh_pengesahan: nil
      }

      updated_senarai_kes_ujian = [new_kes | socket.assigns.selected_ujian.senarai_kes_ujian]

      updated_ujian = %{
        socket.assigns.selected_ujian
        | senarai_kes_ujian: updated_senarai_kes_ujian
      }

      {:noreply,
       socket
       |> assign(:selected_ujian, updated_ujian)
       |> put_flash(:info, "Kes ujian baru berjaya ditambah")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_kes_ujian", %{"kes_id" => kes_id}, socket) do
    if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.senarai_kes_ujian do
      updated_senarai_kes_ujian =
        Enum.reject(socket.assigns.selected_ujian.senarai_kes_ujian, fn kes -> kes.id == kes_id end)

      updated_ujian = %{
        socket.assigns.selected_ujian
        | senarai_kes_ujian: updated_senarai_kes_ujian
      }

      {:noreply,
       socket
       |> assign(:selected_ujian, updated_ujian)
       |> put_flash(:info, "Kes ujian berjaya dipadam")}
    else
      {:noreply, socket}
    end
  end
end
