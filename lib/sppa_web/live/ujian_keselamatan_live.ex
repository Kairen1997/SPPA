defmodule SppaWeb.UjianKeselamatanLive do
  use SppaWeb, :live_view

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

  defp mount_index(socket, project_id) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
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

        ujian =
          UjianKeselamatan.list_ujian_rows_for_project(project_id, socket.assigns.current_scope)

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

  # Get ujian by id (supports integer or string id)
  defp get_ujian_by_id(ujian_id) when is_integer(ujian_id) do
    UjianKeselamatan.get_ujian_formatted(ujian_id)
  end

  defp get_ujian_by_id(ujian_id) when is_binary(ujian_id) do
    case Integer.parse(ujian_id) do
      {id, _} -> UjianKeselamatan.get_ujian_formatted(id)
      :error -> nil
    end
  end

  defp get_ujian_by_id(_), do: nil

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
  def handle_event("open_edit_modal", %{"ujian_id" => ujian_id_str}, socket) do
    ujian_id = parse_ujian_id(ujian_id_str)

    ujian =
      if is_integer(ujian_id) do
        get_ujian_by_id(ujian_id)
      else
        # Placeholder row (module_123) - find in list for form defaults
        if socket.assigns[:ujian] && length(socket.assigns.ujian) > 0 do
          Enum.find(socket.assigns.ujian, fn u -> u.id == ujian_id_str end)
        else
          nil
        end
      end

    if ujian do
      form_data = %{
        "tajuk" => ujian[:tajuk] || "",
        "modul" => ujian[:modul] || ujian[:nama_modul] || "",
        "tarikh_ujian" => format_date_for_form(ujian[:tarikh_ujian]),
        "tarikh_dijangka_siap" => format_date_for_form(ujian[:tarikh_dijangka_siap]),
        "status" => ujian[:status] || "Menunggu",
        "penguji" => ujian[:penguji] || "",
        "hasil" => ujian[:hasil] || "Belum Selesai",
        "disahkan_oleh" => ujian[:disahkan_oleh] || "",
        "catatan" => ujian[:catatan] || ""
      }

      form = to_form(form_data, as: :ujian)

      {:noreply,
       socket
       |> assign(:show_edit_modal, true)
       |> assign(:editing_ujian, ujian)
       |> assign(:editing_ujian_raw_id, ujian_id_str)
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
     |> assign(:editing_ujian_raw_id, nil)
     |> assign(:form, to_form(%{}, as: :ujian))}
  end

  @impl true
  def handle_event("validate_ujian", %{"ujian" => ujian_params}, socket) do
    form = to_form(ujian_params, as: :ujian)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("update_ujian", %{"ujian" => ujian_params}, socket) do
    editing_ujian = socket.assigns[:editing_ujian] || socket.assigns[:selected_ujian]
    raw_id = socket.assigns[:editing_ujian_raw_id] || (editing_ujian && editing_ujian.id)
    project_id = socket.assigns.project_id

    if editing_ujian && project_id do
      tarikh_ujian = parse_date_param(ujian_params["tarikh_ujian"])
      tarikh_dijangka_siap = parse_date_param(ujian_params["tarikh_dijangka_siap"])

      attrs = %{
        modul: ujian_params["modul"] || editing_ujian[:modul],
        tajuk:
          ujian_params["tajuk"] || editing_ujian[:tajuk] ||
            "Ujian Keselamatan - #{ujian_params["modul"]}",
        tarikh_ujian: tarikh_ujian,
        tarikh_dijangka_siap: tarikh_dijangka_siap,
        status: ujian_params["status"] || "Menunggu",
        penguji: if(ujian_params["penguji"] == "", do: nil, else: ujian_params["penguji"]),
        hasil: ujian_params["hasil"] || "Belum Selesai",
        disahkan_oleh:
          if(ujian_params["disahkan_oleh"] == "", do: nil, else: ujian_params["disahkan_oleh"]),
        catatan: if(ujian_params["catatan"] == "", do: nil, else: ujian_params["catatan"])
      }

      result =
        cond do
          # Create new ujian for placeholder row (module_123)
          is_binary(raw_id) && String.starts_with?(raw_id, "module_") ->
            module_id = parse_module_id_from_placeholder(raw_id)

            attrs =
              attrs
              |> Map.put(:project_id, project_id)
              |> Map.put(:analisis_dan_rekabentuk_module_id, module_id)

            UjianKeselamatan.create_ujian(attrs)

          # Update existing ujian
          is_integer(raw_id) ->
            case UjianKeselamatan.get_ujian(raw_id) do
              nil -> {:error, :not_found}
              ujian -> UjianKeselamatan.update_ujian(ujian, attrs)
            end

          true ->
            {:error, :invalid_id}
        end

      case result do
        {:ok, _ujian} ->
          ujian =
            UjianKeselamatan.list_ujian_rows_for_project(project_id, socket.assigns.current_scope)

          {:noreply,
           socket
           |> assign(:ujian, ujian)
           |> assign(:show_edit_modal, false)
           |> assign(:editing_ujian, nil)
           |> assign(:editing_ujian_raw_id, nil)
           |> assign(:form, to_form(%{}, as: :ujian))
           |> put_flash(:info, "Ujian keselamatan berjaya dikemaskini")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Gagal menyimpan ujian keselamatan. Sila semak data dan cuba lagi."
           )}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_kes_ujian", %{"kes_id" => kes_id_str}, socket) do
    kes_id = parse_kes_id(kes_id_str)

    if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.senarai_kes_ujian do
      kes =
        Enum.find(socket.assigns.selected_ujian.senarai_kes_ujian, fn k ->
          k.id == kes_id || k.id == kes_id_str
        end)

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
    kes_id = socket.assigns.selected_kes.id
    kes = UjianKeselamatan.get_kes(kes_id)

    if kes && is_integer(kes_id) do
      tarikh_ujian = parse_date_param(kes_params["tarikh_ujian"])
      tarikh_pengesahan = parse_date_param(kes_params["tarikh_pengesahan"])

      attrs = %{
        senario: kes_params["senario"] || kes.senario,
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
          if(kes_params["disahkan_oleh"] == "", do: nil, else: kes_params["disahkan_oleh"]),
        tarikh_pengesahan: tarikh_pengesahan
      }

      case UjianKeselamatan.update_kes(kes, attrs) do
        {:ok, _} ->
          ujian_id = socket.assigns.selected_ujian.id
          updated = UjianKeselamatan.get_ujian_formatted(ujian_id)

          {:noreply,
           socket
           |> assign(:selected_ujian, updated)
           |> assign(:selected_kes, nil)
           |> assign(:show_edit_kes_modal, false)
           |> assign(:kes_form, to_form(%{}, as: :kes))
           |> put_flash(:info, "Kes ujian berjaya dikemaskini")}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal menyimpan kes ujian. Sila semak data dan cuba lagi.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_new_kes", _params, socket) do
    try do
      selected = socket.assigns[:selected_ujian]
      ujian_id = selected && (Map.get(selected, :id) || Map.get(selected, "id"))

      if selected && is_integer(ujian_id) do
        senarai =
          Map.get(selected, :senarai_kes_ujian, []) || Map.get(selected, "senarai_kes_ujian", [])

        existing_kods =
          Enum.map(senarai, fn k ->
            Map.get(k, :kod) || Map.get(k, "kod")
          end)

        new_number =
          existing_kods
          |> Enum.map(fn kod ->
            case kod && Regex.run(~r/SEC-(\d+)/, to_string(kod)) do
              [_, num_str] -> String.to_integer(num_str)
              _ -> 0
            end
          end)
          |> (fn list -> if list == [], do: [0], else: list end).()
          |> Enum.max()
          |> Kernel.+(1)

        kod = "SEC-#{String.pad_leading(Integer.to_string(new_number), 3, "0")}"

        attrs = %{
          ujian_keselamatan_id: ujian_id,
          kod: kod,
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

        case UjianKeselamatan.create_kes(attrs) do
          {:ok, _} ->
            updated = UjianKeselamatan.get_ujian_formatted(ujian_id)

            if updated do
              {:noreply,
               socket
               |> assign(:selected_ujian, updated)
               |> put_flash(:info, "Kes ujian baru berjaya ditambah")}
            else
              {:noreply,
               socket
               |> put_flash(
                 :error,
                 "Kes ujian ditambah tetapi data tidak dapat dimuat semula. Sila refresh halaman."
               )}
            end

          {:error, changeset} ->
            errors =
              try do
                Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
                |> Enum.flat_map(fn {_field, msgs} -> msgs end)
                |> Enum.join(", ")
              rescue
                _e -> ""
              end

            msg =
              if errors != "" do
                "Gagal menambah kes ujian: #{errors}"
              else
                "Gagal menambah kes ujian. Sila cuba lagi."
              end

            {:noreply,
             socket
             |> put_flash(:error, msg)}
        end
      else
        {:noreply,
         socket
         |> put_flash(:error, "Ujian tidak dijumpai. Sila kembali ke senarai dan cuba lagi.")}
      end
    rescue
      e ->
        require Logger
        Logger.error("add_new_kes crashed: #{inspect(e)}")
        Logger.error(Exception.format(:error, e, __STACKTRACE__))

        err_msg = Exception.message(e)

        flash_msg =
          if String.length(err_msg) < 120 do
            "Ralat menambah kes ujian: #{err_msg}"
          else
            "Ralat menambah kes ujian. Sila cuba lagi atau hubungi pentadbir."
          end

        {:noreply,
         socket
         |> put_flash(:error, flash_msg)}
    end
  end

  @impl true
  def handle_event("delete_kes_ujian", %{"kes_id" => kes_id_str}, socket) do
    kes_id = parse_kes_id(kes_id_str)
    kes = is_integer(kes_id) && UjianKeselamatan.get_kes(kes_id)

    if kes do
      case UjianKeselamatan.delete_kes(kes) do
        {:ok, _} ->
          ujian_id = socket.assigns.selected_ujian.id
          updated = UjianKeselamatan.get_ujian_formatted(ujian_id)

          {:noreply,
           socket
           |> assign(:selected_ujian, updated)
           |> put_flash(:info, "Kes ujian berjaya dipadam")}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Gagal memadam kes ujian. Sila cuba lagi.")}
      end
    else
      {:noreply, socket}
    end
  end

  defp parse_ujian_id(id) when is_integer(id), do: id

  defp parse_ujian_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, _} -> int_id
      :error -> id
    end
  end

  defp parse_ujian_id(_), do: nil

  defp format_date_for_form(nil), do: ""
  defp format_date_for_form(%Date{} = d), do: Calendar.strftime(d, "%Y-%m-%d")
  defp format_date_for_form(_), do: ""

  defp parse_date_param(""), do: nil
  defp parse_date_param(nil), do: nil

  defp parse_date_param(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_module_id_from_placeholder("module_" <> rest) do
    case Integer.parse(rest) do
      {id, _} -> id
      :error -> nil
    end
  end

  defp parse_kes_id(kes_id) when is_integer(kes_id), do: kes_id

  defp parse_kes_id(kes_id) when is_binary(kes_id) do
    case Integer.parse(kes_id) do
      {int_id, _} -> int_id
      :error -> kes_id
    end
  end
end
