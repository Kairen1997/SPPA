defmodule SppaWeb.PembangunanLive do
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
    # TODO: In the future, this should update the database
    # For now, we'll update the in-memory list
    module_id = socket.assigns.selected_module.id

    updated_modules =
      Enum.map(socket.assigns.modules, fn module ->
        if module.id == module_id do
          tarikh_mula =
            if module_params["tarikh_mula"] && module_params["tarikh_mula"] != "" do
              case Date.from_iso8601(module_params["tarikh_mula"]) do
                {:ok, date} -> date
                _ -> module.tarikh_mula
              end
            else
              nil
            end

          tarikh_jangka_siap =
            if module_params["tarikh_jangka_siap"] && module_params["tarikh_jangka_siap"] != "" do
              case Date.from_iso8601(module_params["tarikh_jangka_siap"]) do
                {:ok, date} -> date
                _ -> module.tarikh_jangka_siap
              end
            else
              nil
            end

          %{
            module
            | priority: module_params["priority"],
              status: module_params["status"] || "Belum Mula",
              tarikh_mula: tarikh_mula,
              tarikh_jangka_siap: tarikh_jangka_siap,
              catatan: if(module_params["catatan"] == "", do: nil, else: module_params["catatan"])
          }
        else
          module
        end
      end)

    {:noreply,
     socket
     |> assign(:modules, updated_modules)
     |> assign(:show_edit_modal, false)
     |> assign(:selected_module, nil)
     |> assign(:form, to_form(%{}, as: :module))
     |> put_flash(:info, "Modul berjaya dikemaskini")}
  end
end
