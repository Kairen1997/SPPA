defmodule SppaWeb.UjianPenerimaanPenggunaLive do
  use SppaWeb, :live_view

  alias Sppa.Projects
  alias Sppa.UjianPenerimaanPengguna
  alias Sppa.AnalisisDanRekabentuk

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    # Handle show action - view ujian details (project_id from query preserved)
    mount_show(id, params, socket)
  end

  def mount(params, _session, socket) do
    # Handle index action - list ujian (optionally filtered by project_id)
    mount_index(params, socket)
  end

  defp mount_index(params, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      project_id = parse_project_id(params)
      ujian = UjianPenerimaanPengguna.list_ujian_for_project(project_id)

      project =
        if project_id do
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> Projects.format_project_for_display(p)
          end
        else
          nil
        end

      per_page = 10
      total = length(ujian)
      total_pages = total_pages(total, per_page)
      page = 1
      paginated_ujian = paginate(ujian, page, per_page)

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Ujian Penerimaan Pengguna")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/ujian-penerimaan-pengguna")
        |> assign(:project_id, project_id)
        |> assign(:project, project)
        |> assign(:ujian, ujian)
        |> assign(:paginated_ujian, paginated_ujian)
        |> assign(:ujian_total, total)
        |> assign(:page, page)
        |> assign(:per_page, per_page)
        |> assign(:total_pages, total_pages)
        |> assign(:show_edit_modal, false)
        |> assign(:show_create_modal, false)
        |> assign(:show_edit_kes_modal, false)
        |> assign(:show_add_kes_modal, false)
        |> assign(:selected_ujian, nil)
        |> assign(:selected_kes, nil)
        |> assign(:form, to_form(%{}, as: :ujian))
        |> assign(:kes_form, to_form(%{}, as: :kes))
        |> assign(
          :senarai_nama_modul,
          AnalisisDanRekabentuk.list_module_names(socket.assigns.current_scope)
        )
        |> assign(
          :senarai_nama_modul_ordered,
          socket.assigns.current_scope
          |> AnalisisDanRekabentuk.list_modules_id_name()
          |> Enum.map(& &1.name)
        )

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

  defp mount_show(ujian_id, params, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Butiran Ujian Penerimaan Pengguna")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/ujian-penerimaan-pengguna")

      project_id = parse_project_id(params)

      project =
        if project_id do
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> Projects.format_project_for_display(p)
          end
        else
          nil
        end

      socket = socket |> assign(:project_id, project_id) |> assign(:project, project)

      if connected?(socket) do
        ujian = UjianPenerimaanPengguna.get_ujian(ujian_id)

        if ujian do
          selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian)
          activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
          notifications_count = length(activities)

          {:ok,
           socket
           |> assign(:selected_ujian, selected)
           |> assign(:ujian, [])
           |> assign(:show_edit_modal, false)
           |> assign(:show_create_modal, false)
           |> assign(:show_edit_kes_modal, false)
           |> assign(:show_add_kes_modal, false)
           |> assign(:selected_kes, nil)
           |> assign(:form, to_form(%{}, as: :ujian))
           |> assign(:kes_form, to_form(%{}, as: :kes))
           |> assign(
             :senarai_nama_modul,
             AnalisisDanRekabentuk.list_module_names(socket.assigns.current_scope)
           )
           |> assign(:activities, activities)
           |> assign(:notifications_count, notifications_count)}
        else
          socket =
            socket
            |> Phoenix.LiveView.put_flash(
              :error,
              "Ujian penerimaan pengguna tidak dijumpai."
            )
            |> Phoenix.LiveView.redirect(to: ~p"/ujian-penerimaan-pengguna")

          {:ok, socket}
        end
      else
        ujian = UjianPenerimaanPengguna.get_ujian(ujian_id)

        selected =
          if ujian, do: UjianPenerimaanPengguna.format_ujian_for_display(ujian), else: nil

        {:ok,
         socket
         |> assign(:selected_ujian, selected)
         |> assign(:ujian, [])
         |> assign(:show_edit_modal, false)
         |> assign(:show_create_modal, false)
         |> assign(:show_edit_kes_modal, false)
         |> assign(:show_add_kes_modal, false)
         |> assign(:selected_kes, nil)
         |> assign(:form, to_form(%{}, as: :ujian))
         |> assign(:kes_form, to_form(%{}, as: :kes))
         |> assign(
           :senarai_nama_modul,
           AnalisisDanRekabentuk.list_module_names(socket.assigns.current_scope)
         )
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
  def handle_params(params, _uri, socket) do
    project_id = parse_project_id(params)

    project =
      if project_id do
        case Projects.get_project_by_id(project_id) do
          nil -> nil
          p -> Projects.format_project_for_display(p)
        end
      else
        nil
      end

    socket =
      socket
      |> assign(:project_id, project_id)
      |> assign(:project, project)

    # For index: refresh ujian list and pagination when project_id changes
    socket =
      if is_nil(Map.get(socket.assigns, :selected_ujian)) do
        ujian = UjianPenerimaanPengguna.list_ujian_for_project(project_id)
        per_page = socket.assigns[:per_page] || 10
        total = length(ujian)
        total_pages = total_pages(total, per_page)
        page = 1
        paginated_ujian = paginate(ujian, page, per_page)

        socket
        |> assign(:ujian, ujian)
        |> assign(:paginated_ujian, paginated_ujian)
        |> assign(:ujian_total, total)
        |> assign(:page, page)
        |> assign(:total_pages, total_pages)
      else
        socket
      end

    {:noreply, socket}
  end

  defp parse_project_id(params) when is_map(params) do
    case Map.get(params, "project_id") do
      nil ->
        nil

      id when is_binary(id) ->
        case Integer.parse(id) do
          {int, _rest} -> int
          :error -> nil
        end
    end
  end

  defp parse_project_id(_), do: nil

  defp parse_ujian_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> id
    end
  end

  defp parse_ujian_id(id) when is_integer(id), do: id
  defp parse_ujian_id(_), do: nil

  defp parse_kes_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, _} -> int
      :error -> id
    end
  end

  defp parse_kes_id(id) when is_integer(id), do: id
  defp parse_kes_id(_), do: nil

  defp parse_date(nil, default), do: default
  defp parse_date("", default), do: default

  defp parse_date(str, default) when is_binary(str) do
    case Date.from_iso8601(str) do
      {:ok, date} -> date
      _ -> default
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(s) when is_binary(s), do: if(String.trim(s) == "", do: nil, else: s)
  defp empty_to_nil(other), do: other

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
  def handle_event("next_page", _params, socket) do
    %{page: page, total_pages: total_pages, per_page: per_page, ujian: ujian} = socket.assigns

    new_page = min(page + 1, total_pages)
    paginated = paginate(ujian, new_page, per_page)

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:paginated_ujian, paginated)}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    %{page: page, per_page: per_page, ujian: ujian} = socket.assigns

    new_page = max(page - 1, 1)
    paginated = paginate(ujian, new_page, per_page)

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:paginated_ujian, paginated)}
  end

  @impl true
  def handle_event("go_to_page", %{"page" => page_param}, socket) do
    %{total_pages: total_pages, per_page: per_page, ujian: ujian} = socket.assigns

    new_page =
      case Integer.parse(page_param) do
        {int, _} when int >= 1 and int <= total_pages -> int
        _ -> socket.assigns.page
      end

    paginated = paginate(ujian, new_page, per_page)

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:paginated_ujian, paginated)}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    form = to_form(%{}, as: :ujian)

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
     |> assign(:form, to_form(%{}, as: :ujian))}
  end

  @impl true
  def handle_event("open_edit_modal", %{"ujian_id" => ujian_id}, socket) do
    ujian_id_int = parse_ujian_id(ujian_id)

    ujian =
      if socket.assigns[:ujian] && length(socket.assigns.ujian) > 0 do
        Enum.find(socket.assigns.ujian, fn u -> u.id == ujian_id_int end)
      else
        UjianPenerimaanPengguna.get_ujian(ujian_id_int)
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
  def handle_event("create_ujian", %{"ujian" => ujian_params}, socket) do
    project_id = socket.assigns[:project_id]

    if is_nil(project_id) do
      {:noreply,
       socket
       |> put_flash(
         :error,
         "Sila pilih projek terlebih dahulu (akses halaman dari tab UAT projek)."
       )
       |> assign(:form, to_form(ujian_params, as: :ujian))}
    else
      attrs = %{
        project_id: project_id,
        tajuk: ujian_params["tajuk"],
        modul: ujian_params["modul"],
        tarikh_ujian: parse_date(ujian_params["tarikh_ujian"], Date.utc_today()),
        tarikh_dijangka_siap: parse_date(ujian_params["tarikh_dijangka_siap"], Date.utc_today()),
        status: ujian_params["status"] || "Menunggu",
        penguji: empty_to_nil(ujian_params["penguji"]),
        hasil: ujian_params["hasil"] || "Belum Selesai",
        catatan: empty_to_nil(ujian_params["catatan"])
      }

      case UjianPenerimaanPengguna.create_ujian(attrs) do
        {:ok, _ujian} ->
          ujian = UjianPenerimaanPengguna.list_ujian_for_project(project_id)
          per_page = socket.assigns.per_page
          total = length(ujian)
          total_pages_val = total_pages(total, per_page)
          page = 1
          paginated_ujian = paginate(ujian, page, per_page)

          {:noreply,
           socket
           |> assign(:ujian, ujian)
           |> assign(:paginated_ujian, paginated_ujian)
           |> assign(:ujian_total, total)
           |> assign(:page, page)
           |> assign(:total_pages, total_pages_val)
           |> assign(:show_create_modal, false)
           |> assign(:form, to_form(%{}, as: :ujian))
           |> put_flash(:info, "Ujian penerimaan pengguna berjaya didaftarkan")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:form, to_form(changeset, as: :ujian))
           |> put_flash(:error, "Gagal mendaftar. Sila semak maklumat.")}
      end
    end
  end

  @impl true
  def handle_event("update_ujian", %{"ujian" => ujian_params}, socket) do
    editing_ujian = socket.assigns[:editing_ujian]

    if editing_ujian do
      attrs = %{
        tajuk: ujian_params["tajuk"],
        modul: ujian_params["modul"],
        tarikh_ujian: parse_date(ujian_params["tarikh_ujian"], editing_ujian.tarikh_ujian),
        tarikh_dijangka_siap:
          parse_date(ujian_params["tarikh_dijangka_siap"], editing_ujian.tarikh_dijangka_siap),
        status: ujian_params["status"],
        penguji: empty_to_nil(ujian_params["penguji"]),
        hasil: ujian_params["hasil"],
        catatan: empty_to_nil(ujian_params["catatan"])
      }

      case UjianPenerimaanPengguna.update_ujian(editing_ujian, attrs) do
        {:ok, _} ->
          ujian_id = editing_ujian.id
          project_id = socket.assigns[:project_id]

          updated_ujian_list =
            if project_id do
              UjianPenerimaanPengguna.list_ujian_for_project(project_id)
            else
              UjianPenerimaanPengguna.list_ujian()
            end

          {paginated_ujian, ujian_total, page, total_pages_val} =
            if socket.assigns[:per_page] do
              per_page = socket.assigns.per_page
              total = length(updated_ujian_list)
              tp = total_pages(total, per_page)
              p = min(socket.assigns[:page] || 1, max(tp, 1))
              {paginate(updated_ujian_list, p, per_page), total, p, tp}
            else
              {updated_ujian_list, length(updated_ujian_list), 1, 1}
            end

          updated_socket =
            socket
            |> assign(:ujian, updated_ujian_list)
            |> assign(:paginated_ujian, paginated_ujian)
            |> assign(:ujian_total, ujian_total)
            |> assign(:page, page)
            |> assign(:total_pages, total_pages_val)
            |> assign(:show_edit_modal, false)
            |> assign(:editing_ujian, nil)
            |> assign(:form, to_form(%{}, as: :ujian))
            |> put_flash(:info, "Ujian penerimaan pengguna berjaya dikemaskini")

          final_socket =
            if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.id == ujian_id do
              ujian = UjianPenerimaanPengguna.get_ujian(ujian_id)

              assign(
                updated_socket,
                :selected_ujian,
                UjianPenerimaanPengguna.format_ujian_for_display(ujian)
              )
            else
              updated_socket
            end

          {:noreply, final_socket}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:form, to_form(changeset, as: :ujian))
           |> put_flash(:error, "Gagal mengemaskini. Sila semak maklumat.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_kes_ujian", %{"kes_id" => kes_id}, socket) do
    kes_id_parsed = parse_kes_id(kes_id)

    if socket.assigns[:selected_ujian] && socket.assigns.selected_ujian.senarai_kes_ujian do
      kes =
        Enum.find(socket.assigns.selected_ujian.senarai_kes_ujian, fn k ->
          k.id == kes_id_parsed
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
    kes_struct = UjianPenerimaanPengguna.get_kes(kes_id)

    if kes_struct do
      attrs = %{
        senario: kes_params["senario"],
        langkah: empty_to_nil(kes_params["langkah"]),
        keputusan_dijangka: empty_to_nil(kes_params["keputusan_dijangka"]),
        keputusan_sebenar: empty_to_nil(kes_params["keputusan_sebenar"]),
        hasil: empty_to_nil(kes_params["hasil"]),
        penguji: empty_to_nil(kes_params["penguji"]),
        tarikh_ujian: parse_date(kes_params["tarikh_ujian"], nil),
        disahkan_oleh: empty_to_nil(kes_params["disahkan_oleh"]),
        tarikh_pengesahan: parse_date(kes_params["tarikh_pengesahan"], nil)
      }

      case UjianPenerimaanPengguna.update_kes(kes_struct, attrs) do
        {:ok, _} ->
          ujian = UjianPenerimaanPengguna.get_ujian(socket.assigns.selected_ujian.id)
          selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

          {:noreply,
           socket
           |> assign(:selected_ujian, selected)
           |> assign(:selected_kes, nil)
           |> assign(:show_edit_kes_modal, false)
           |> assign(:kes_form, to_form(%{}, as: :kes))
           |> put_flash(:info, "Kes ujian berjaya dikemaskini")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:kes_form, to_form(changeset, as: :kes))
           |> put_flash(:error, "Gagal mengemaskini kes. Sila semak maklumat.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_kes_ujian", %{"kes_id" => kes_id}, socket) do
    kes_struct = UjianPenerimaanPengguna.get_kes(parse_kes_id(kes_id))

    if kes_struct && socket.assigns[:selected_ujian] do
      case UjianPenerimaanPengguna.delete_kes(kes_struct) do
        {:ok, _} ->
          ujian = UjianPenerimaanPengguna.get_ujian(socket.assigns.selected_ujian.id)
          selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

          {:noreply,
           socket
           |> assign(:selected_ujian, selected)
           |> assign(:selected_kes, nil)
           |> assign(:show_edit_kes_modal, false)
           |> put_flash(:info, "Kes ujian berjaya dipadam")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Gagal memadam kes ujian.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_add_kes_modal", _params, socket) do
    default_kes = %{
      "senario" => "",
      "langkah" => "",
      "keputusan_dijangka" => "",
      "keputusan_sebenar" => "",
      "hasil" => "",
      "penguji" => "",
      "tarikh_ujian" => "",
      "disahkan_oleh" => "",
      "tarikh_pengesahan" => ""
    }

    {:noreply,
     socket
     |> assign(:show_add_kes_modal, true)
     |> assign(:kes_form, to_form(default_kes, as: :kes))}
  end

  @impl true
  def handle_event("close_add_kes_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_kes_modal, false)
     |> assign(:kes_form, to_form(%{}, as: :kes))}
  end

  @impl true
  def handle_event("validate_add_kes", %{"kes" => kes_params}, socket) do
    form = to_form(kes_params, as: :kes)
    {:noreply, assign(socket, :kes_form, form)}
  end

  @impl true
  def handle_event("create_kes", %{"kes" => kes_params}, socket) do
    if socket.assigns[:selected_ujian] do
      senarai = socket.assigns.selected_ujian.senarai_kes_ujian || []

      new_number =
        senarai
        |> Enum.map(fn k ->
          kod = Map.get(k, :kod, k.id)
          kod_str = if is_binary(kod), do: kod, else: to_string(kod)

          case Regex.run(~r/REG-(\d+)/, kod_str) do
            [_, num_str] -> String.to_integer(num_str)
            _ -> 0
          end
        end)
        |> (fn list -> if list == [], do: [0], else: list end).()
        |> Enum.max()
        |> Kernel.+(1)

      kod = "REG-#{String.pad_leading(Integer.to_string(new_number), 3, "0")}"

      attrs = %{
        ujian_penerimaan_pengguna_id: socket.assigns.selected_ujian.id,
        kod: kod,
        senario: kes_params["senario"] || "",
        langkah: empty_to_nil(kes_params["langkah"]),
        keputusan_dijangka: empty_to_nil(kes_params["keputusan_dijangka"]),
        keputusan_sebenar: empty_to_nil(kes_params["keputusan_sebenar"]),
        hasil: empty_to_nil(kes_params["hasil"]),
        penguji: empty_to_nil(kes_params["penguji"]),
        tarikh_ujian: parse_date(kes_params["tarikh_ujian"], nil),
        disahkan_oleh: empty_to_nil(kes_params["disahkan_oleh"]),
        tarikh_pengesahan: parse_date(kes_params["tarikh_pengesahan"], nil)
      }

      case UjianPenerimaanPengguna.create_kes(attrs) do
        {:ok, _} ->
          ujian = UjianPenerimaanPengguna.get_ujian(socket.assigns.selected_ujian.id)
          selected = UjianPenerimaanPengguna.format_ujian_for_display(ujian)

          {:noreply,
           socket
           |> assign(:selected_ujian, selected)
           |> assign(:show_add_kes_modal, false)
           |> assign(:kes_form, to_form(%{}, as: :kes))
           |> put_flash(:info, "Kes ujian berjaya ditambah")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:kes_form, to_form(changeset, as: :kes))
           |> put_flash(:error, "Gagal menambah kes. Sila semak maklumat.")}
      end
    else
      {:noreply, socket}
    end
  end

  defp paginate(ujian, page, per_page) do
    start_index = (page - 1) * per_page
    Enum.slice(ujian, start_index, per_page)
  end

  defp total_pages(0, _per_page), do: 1

  defp total_pages(total, per_page) do
    pages = div(total, per_page)
    if rem(total, per_page) == 0, do: pages, else: pages + 1
  end
end
