defmodule SppaWeb.PenempatanLive do
  use SppaWeb, :live_view

  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.Penempatans
  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Handle show action - view penempatan details
    mount_show(id, socket)
  end

  def mount(_params, _session, socket) do
    # Handle index action - list all penempatan
    mount_index(socket)
  end

  defp mount_index(socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Get deployment records (penempatan) with projek_id for linking to tab penempatan
      penempatan = get_penempatan(socket.assigns.current_scope)
      project_ids = get_project_ids_for_scope(socket.assigns.current_scope)

      # url_projek_id akan dikemas kini dalam handle_params (supaya dipaparkan pada URL)
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Penempatan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/penempatan")
        |> assign(:penempatan, penempatan)
        |> assign(:penempatan_display, penempatan)
        |> assign(:show_edit_modal, false)
        |> assign(:show_create_modal, false)
        |> assign(:selected_penempatan, nil)
        |> assign(:form, to_form(%{}, as: :penempatan))
        |> assign(:url_projek_id, nil)
        |> assign(:project_ids, project_ids)

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

  defp parse_projek_id_from_params(%{"projek_id" => id}) when is_binary(id) do
    case Integer.parse(id) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_projek_id_from_params(_params), do: nil

  defp maybe_patch_url_with_projek_id(socket, nil, first_project_id)
       when not is_nil(first_project_id) do
    # URL tiada projek_id tetapi pengguna ada projek - patch supaya projek id dipaparkan pada URL
    Phoenix.LiveView.push_patch(socket, to: ~p"/penempatan?projek_id=#{first_project_id}")
  end

  defp maybe_patch_url_with_projek_id(socket, _url_projek_id, _first_project_id), do: socket

  defp mount_show(penempatan_id, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Butiran Penempatan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/penempatan")

      if connected?(socket) do
        penempatan = get_penempatan_by_id(penempatan_id)
        activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
        notifications_count = length(activities)

        if penempatan do
          {:ok,
           socket
           |> assign(:selected_penempatan, penempatan)
           |> assign(:penempatan, [])
           |> assign(:show_edit_modal, false)
           |> assign(:show_create_modal, false)
           |> assign(:form, to_form(%{}, as: :penempatan))
           |> assign(:activities, activities)
           |> assign(:notifications_count, notifications_count)}
        else
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              "Penempatan tidak dijumpai."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/penempatan")
            |> assign(:activities, [])
            |> assign(:notifications_count, 0)

          {:ok, socket}
        end
      else
        {:ok,
         socket
         |> assign(:selected_penempatan, nil)
         |> assign(:penempatan, [])
         |> assign(:show_edit_modal, false)
         |> assign(:show_create_modal, false)
         |> assign(:form, to_form(%{}, as: :penempatan))
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

  # Get penempatan by id (from database). Returns display map or nil.
  defp get_penempatan_by_id(penempatan_id) do
    id = parse_penempatan_id(penempatan_id)
    if id, do: penempatan_struct_to_display_map(Penempatans.get_penempatan(id)), else: nil
  end

  # Returns list of project IDs the current user can access (for linking penempatan to projek tab)
  defp get_project_ids_for_scope(current_scope) do
    projects =
      case current_scope.user.role do
        "ketua penolong pengarah" -> Projects.list_all_projects()
        "pengurus projek" -> Projects.list_projects_for_pengurus_projek(current_scope)
        "pembangun sistem" -> Projects.list_projects_for_pembangun_sistem(current_scope)
        _ -> Projects.list_projects(current_scope)
      end

    projects
    |> Enum.map(fn p -> if is_map(p), do: p.id, else: p.id end)
    |> Enum.take(10)
  end

  defp parse_penempatan_id(id) when is_integer(id), do: id

  defp parse_penempatan_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {num, _} -> num
      :error -> nil
    end
  end

  defp parse_penempatan_id(_), do: nil

  # Convert Penempatan struct to the display map shape expected by templates.
  defp penempatan_struct_to_display_map(nil), do: nil

  defp penempatan_struct_to_display_map(p) do
    %{
      id: p.id,
      nama_sistem: p.nama_sistem,
      versi: p.versi,
      lokasi: p.lokasi,
      tarikh_penempatan: p.tarikh_penempatan,
      tarikh_dijangka: p.tarikh_dijangka,
      status: p.status,
      jenis: p.jenis,
      persekitaran: p.persekitaran,
      url: p.url,
      catatan: p.catatan,
      dibina_oleh: p.dibina_oleh,
      disemak_oleh: p.disemak_oleh,
      diluluskan_oleh: p.diluluskan_oleh,
      tarikh_dibina: p.tarikh_dibina,
      tarikh_disemak: p.tarikh_disemak,
      tarikh_diluluskan: p.tarikh_diluluskan,
      projek_id: p.project_id
    }
  end

  # Get deployment records from database with projek_id and optional project nama/versi for display.
  defp get_penempatan(current_scope) do
    project_ids = get_project_ids_for_scope(current_scope)

    list =
      if project_ids == [] do
        Penempatans.list_all_penempatans()
      else
        Penempatans.list_penempatans_by_project_ids(project_ids)
      end

    ids_used = list |> Enum.map(& &1.project_id) |> Enum.uniq() |> Enum.reject(&is_nil/1)
    project_nama_by_id = Projects.get_project_nama_by_ids(ids_used)
    versi_by_project_id = AnalisisDanRekabentuk.get_versi_by_project_ids(ids_used)

    Enum.map(list, fn p ->
      nama_sistem = p.nama_sistem || Map.get(project_nama_by_id, p.project_id)
      versi = p.versi || Map.get(versi_by_project_id, p.project_id, p.versi)

      penempatan_struct_to_display_map(p)
      |> Map.put(:nama_sistem, nama_sistem || p.nama_sistem)
      |> Map.put(:versi, versi || p.versi)
      |> Map.put(:projek_id, p.project_id)
    end)
  end

  # Reload penempatan assigns after create/update (keeps url_projek_id filter).
  defp reload_penempatan_assigns(socket) do
    penempatan = get_penempatan(socket.assigns.current_scope)
    url_projek_id = socket.assigns[:url_projek_id]

    penempatan_display =
      if url_projek_id do
        Enum.filter(penempatan, &(&1.projek_id == url_projek_id))
      else
        penempatan
      end

    socket
    |> assign(:penempatan, penempatan)
    |> assign(:penempatan_display, penempatan_display)
  end

  @impl true
  def handle_params(params, _uri, socket) do
    # Halaman senarai penempatan: pastikan projek_id dipaparkan pada URL dan filter mengikut projek
    if Map.has_key?(socket.assigns, :project_ids) do
      url_projek_id = parse_projek_id_from_params(params)
      first_project_id = List.first(socket.assigns.project_ids || [])

      # Bila projek_id dalam URL, hanya papar penempatan untuk projek tersebut (satu sistem)
      penempatan_display =
        if url_projek_id do
          socket.assigns.penempatan
          |> Enum.filter(&(&1.projek_id == url_projek_id))
        else
          socket.assigns.penempatan
        end

      socket =
        socket
        |> assign(:url_projek_id, url_projek_id)
        |> assign(:penempatan_display, penempatan_display)
        |> maybe_patch_url_with_projek_id(url_projek_id, first_project_id)

      {:noreply, socket}
    else
      {:noreply, socket}
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
  def handle_event("open_create_modal", _params, socket) do
    # Isi default versi (dan nama sistem) dari Analisis dan Rekabentuk bila projek dipilih
    initial_params =
      case socket.assigns[:url_projek_id] do
        nil ->
          %{}
        projek_id ->
          versi_map = AnalisisDanRekabentuk.get_versi_by_project_ids([projek_id])
          nama_map = Projects.get_project_nama_by_ids([projek_id])
          %{
            "versi" => Map.get(versi_map, projek_id, "1.0.0"),
            "nama_sistem" => Map.get(nama_map, projek_id, "")
          }
      end

    form = to_form(initial_params, as: :penempatan)

    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:form, form)}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> assign(:form, to_form(%{}, as: :penempatan))}
  end

  @impl true
  def handle_event("open_edit_modal", %{"penempatan_id" => penempatan_id}, socket) do
    id_parsed = parse_penempatan_id(penempatan_id)
    # Try to find penempatan from list first, then from selected_penempatan
    penempatan =
      if socket.assigns[:penempatan] && length(socket.assigns.penempatan) > 0 do
        Enum.find(socket.assigns.penempatan, fn p -> p.id == id_parsed end)
      else
        if socket.assigns[:selected_penempatan] &&
             socket.assigns.selected_penempatan.id == id_parsed do
          socket.assigns.selected_penempatan
        else
          get_penempatan_by_id(penempatan_id)
        end
      end

    if penempatan do
      form_data = %{
        "nama_sistem" => penempatan.nama_sistem,
        "versi" => penempatan.versi,
        "lokasi" => penempatan.lokasi,
        "tarikh_penempatan" => Calendar.strftime(penempatan.tarikh_penempatan, "%Y-%m-%d"),
        "tarikh_dijangka" =>
          if(penempatan.tarikh_dijangka,
            do: Calendar.strftime(penempatan.tarikh_dijangka, "%Y-%m-%d"),
            else: ""
          ),
        "status" => penempatan.status,
        "jenis" => penempatan.jenis,
        "persekitaran" => penempatan.persekitaran,
        "url" => penempatan.url || "",
        "catatan" => penempatan.catatan || "",
        "dibina_oleh" => penempatan.dibina_oleh || "",
        "disemak_oleh" => Map.get(penempatan, :disemak_oleh, "") || "",
        "diluluskan_oleh" => Map.get(penempatan, :diluluskan_oleh, "") || "",
        "tarikh_dibina" =>
          if(penempatan.tarikh_dibina,
            do: Calendar.strftime(penempatan.tarikh_dibina, "%Y-%m-%d"),
            else: ""
          ),
        "tarikh_disemak" =>
          if(Map.get(penempatan, :tarikh_disemak),
            do: Calendar.strftime(penempatan.tarikh_disemak, "%Y-%m-%d"),
            else: ""
          ),
        "tarikh_diluluskan" =>
          if(Map.get(penempatan, :tarikh_diluluskan),
            do: Calendar.strftime(penempatan.tarikh_diluluskan, "%Y-%m-%d"),
            else: ""
          )
      }

      form = to_form(form_data, as: :penempatan)

      {:noreply,
       socket
       |> assign(:show_edit_modal, true)
       |> assign(:editing_penempatan, penempatan)
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
     |> assign(:editing_penempatan, nil)
     |> assign(:form, to_form(%{}, as: :penempatan))}
  end

  @impl true
  def handle_event("validate_penempatan", %{"penempatan" => penempatan_params}, socket) do
    form = to_form(penempatan_params, as: :penempatan)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("create_penempatan", %{"penempatan" => penempatan_params}, socket) do
    attrs = build_penempatan_attrs_from_params(penempatan_params)
    attrs = maybe_put_project_id(attrs, socket.assigns[:url_projek_id])

    case Penempatans.create_penempatan(attrs) do
      {:ok, _penempatan} ->
        {:noreply,
         socket
         |> reload_penempatan_assigns()
         |> assign(:show_create_modal, false)
         |> assign(:form, to_form(%{}, as: :penempatan))
         |> put_flash(:info, "Penempatan berjaya didaftarkan")}

      {:error, changeset} ->
        form = to_form(changeset, as: :penempatan)

        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Gagal mendaftar penempatan. Sila semak maklumat.")}
    end
  end

  @impl true
  def handle_event("update_penempatan", %{"penempatan" => penempatan_params}, socket) do
    editing_penempatan =
      socket.assigns[:editing_penempatan] || socket.assigns[:selected_penempatan]

    if editing_penempatan do
      penempatan_struct = Penempatans.get_penempatan(editing_penempatan.id)
      attrs = build_penempatan_attrs_from_params(penempatan_params)

      if penempatan_struct do
        case Penempatans.update_penempatan(penempatan_struct, attrs) do
          {:ok, updated} ->
            display_map = penempatan_struct_to_display_map(updated)

            updated_socket =
              socket
              |> reload_penempatan_assigns()
              |> assign(:show_edit_modal, false)
              |> assign(:editing_penempatan, nil)
              |> assign(:form, to_form(%{}, as: :penempatan))
              |> put_flash(:info, "Penempatan berjaya dikemaskini")

            final_socket =
              if socket.assigns[:selected_penempatan] &&
                   socket.assigns.selected_penempatan.id == editing_penempatan.id do
                assign(updated_socket, :selected_penempatan, display_map)
              else
                updated_socket
              end

            {:noreply, final_socket}

          {:error, changeset} ->
            form = to_form(changeset, as: :penempatan)

            {:noreply,
             socket
             |> assign(:form, form)
             |> put_flash(:error, "Gagal mengemaskini penempatan. Sila semak maklumat.")}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  defp maybe_put_project_id(attrs, nil), do: attrs
  defp maybe_put_project_id(attrs, project_id), do: Map.put(attrs, :project_id, project_id)

  defp build_penempatan_attrs_from_params(params) do
    %{
      nama_sistem: params["nama_sistem"] || "",
      versi: params["versi"] || "1.0.0",
      lokasi: params["lokasi"] || "",
      jenis: params["jenis"] || "Produksi",
      status: params["status"] || "Menunggu",
      persekitaran: params["persekitaran"] || "",
      tarikh_penempatan: parse_date_param(params["tarikh_penempatan"]) || Date.utc_today(),
      tarikh_dijangka: parse_date_param(params["tarikh_dijangka"]),
      url: blank_to_nil(params["url"]),
      catatan: blank_to_nil(params["catatan"]),
      dibina_oleh: blank_to_nil(params["dibina_oleh"]),
      disemak_oleh: blank_to_nil(params["disemak_oleh"]),
      diluluskan_oleh: blank_to_nil(params["diluluskan_oleh"]),
      tarikh_dibina: parse_date_param(params["tarikh_dibina"]),
      tarikh_disemak: parse_date_param(params["tarikh_disemak"]),
      tarikh_diluluskan: parse_date_param(params["tarikh_diluluskan"])
    }
  end

  defp parse_date_param(""), do: nil
  defp parse_date_param(nil), do: nil

  defp parse_date_param(str) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(s), do: s
end
