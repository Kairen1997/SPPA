defmodule SppaWeb.PembangunanLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.ModulPengaturcaraan

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Get modules (nama modul, versi, fungsi modul) from Analisis dan Rekabentuk database
      modules = AnalisisDanRekabentuk.list_modules_for_pembangunan(socket.assigns.current_scope)

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Pengaturcaraan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/pengaturcaraan")
        |> assign(:modules, modules)
        |> assign(:view_mode, "table")
        |> assign(:show_view_modal, false)
        |> assign(:show_edit_modal, false)
        |> assign(:selected_module, nil)
        |> assign(:form, to_form(%{}, as: :module))
        |> assign(:activities, [])
        |> assign(:notifications_count, 0)

      if connected?(socket) do
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
        notifications_count = length(activities)

        {:ok,
         socket
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        {:ok, socket}
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
  def handle_event("change_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :view_mode, view)}
  end

  @impl true
  def handle_event("open_view_modal", %{"module_id" => module_id}, socket) do
    module = Enum.find(socket.assigns.modules, fn m -> m.id == module_id end)

    if module do
      {:noreply,
       socket
       |> assign(:show_view_modal, true)
       |> assign(:selected_module, module)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_view_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_view_modal, false)
     |> assign(:selected_module, nil)}
  end

  @impl true
  def handle_event("open_edit_modal", %{"module_id" => module_id}, socket) do
    module = Enum.find(socket.assigns.modules, fn m -> m.id == module_id end)

    if module do
      form_data = %{
        "priority" => module.priority || "",
        "status" => module.status || "Belum Mula",
        "tarikh_mula" =>
          if(module.tarikh_mula, do: Calendar.strftime(module.tarikh_mula, "%Y-%m-%d"), else: ""),
        "tarikh_jangka_siap" =>
          if(module.tarikh_jangka_siap,
            do: Calendar.strftime(module.tarikh_jangka_siap, "%Y-%m-%d"),
            else: ""
          ),
        "catatan" => module.catatan || ""
      }

      form = to_form(form_data, as: :module)

      {:noreply,
       socket
       |> assign(:show_view_modal, false)
       |> assign(:show_edit_modal, true)
       |> assign(:selected_module, module)
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
     |> assign(:selected_module, nil)
     |> assign(:form, to_form(%{}, as: :module))}
  end

  @impl true
  def handle_event("validate_module", %{"module" => module_params}, socket) do
    form = to_form(module_params, as: :module)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("update_module", %{"module" => module_params}, socket) do
    selected = socket.assigns.selected_module
    module_id_str = selected.id
    project_id = selected.project_id

    analisis_module_id =
      case module_id_str do
        "module_" <> id_str -> String.to_integer(id_str)
        _ -> nil
      end

    if is_nil(project_id) or is_nil(analisis_module_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Projek atau modul tidak sah.")
       |> assign(:show_edit_modal, false)
       |> assign(:selected_module, nil)}
    else
      tarikh_mula =
        if module_params["tarikh_mula"] && module_params["tarikh_mula"] != "" do
          case Date.from_iso8601(module_params["tarikh_mula"]) do
            {:ok, date} -> date
            _ -> nil
          end
        else
          nil
        end

      tarikh_jangka_siap =
        if module_params["tarikh_jangka_siap"] && module_params["tarikh_jangka_siap"] != "" do
          case Date.from_iso8601(module_params["tarikh_jangka_siap"]) do
            {:ok, date} -> date
            _ -> nil
          end
        else
          nil
        end

      attrs = %{
        keutamaan: module_params["priority"] || nil,
        status: module_params["status"] || "Belum Mula",
        tarikh_mula: tarikh_mula,
        tarikh_jangka_siap: tarikh_jangka_siap,
        catatan: if(module_params["catatan"] == "", do: nil, else: module_params["catatan"])
      }

      case ModulPengaturcaraan.upsert(project_id, analisis_module_id, attrs) do
        {:ok, _} ->
          modules = AnalisisDanRekabentuk.list_modules_for_pembangunan(socket.assigns.current_scope)

          {:noreply,
           socket
           |> assign(:modules, modules)
           |> assign(:show_edit_modal, false)
           |> assign(:selected_module, nil)
           |> assign(:form, to_form(%{}, as: :module))
           |> put_flash(:info, "Modul berjaya dikemaskini")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal mengemaskini modul. Sila cuba lagi.")}
      end
    end
  end
end
