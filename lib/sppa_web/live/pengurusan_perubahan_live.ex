defmodule SppaWeb.PengurusanPerubahanLive do
  use SppaWeb, :live_view

  alias Sppa.PermohonanPerubahan
  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      project_id =
        case Map.get(params, "project_id") do
          nil -> nil
          id when is_binary(id) ->
            case Integer.parse(id) do
              {int, _rest} -> int
              :error -> nil
            end
        end

      perubahan = load_perubahan(project_id)
      per_page = 5
      total = length(perubahan)
      total_pages = total_pages(total, per_page)
      page = 1
      paginated_perubahan = paginate(perubahan, page, per_page)

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Pengurusan Perubahan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/pengurusan-perubahan")
        |> assign(:project_id, project_id)
        |> assign(:perubahan, perubahan)
        |> assign(:paginated_perubahan, paginated_perubahan)
        |> assign(:perubahan_total, total)
        |> assign(:page, page)
        |> assign(:per_page, per_page)
        |> assign(:total_pages, total_pages)
        |> assign(:show_view_modal, false)
        |> assign(:show_edit_modal, false)
        |> assign(:show_create_modal, false)
        |> assign(:selected_perubahan, nil)
        |> assign(:form, to_form(%{}, as: :perubahan))

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
  def handle_params(params, _uri, socket) do
    # Sentiasa baca project_id dari URL dan muat semula dari DB sahaja
    project_id =
      case Map.get(params, "project_id") do
        nil -> nil
        id when is_binary(id) ->
          case Integer.parse(id) do
            {int, _rest} -> int
            :error -> nil
          end
      end

    perubahan = load_perubahan(project_id)
    per_page = socket.assigns[:per_page] || 5
    total = length(perubahan)
    total_pages = total_pages(total, per_page)
    page = 1
    paginated_perubahan = paginate(perubahan, page, per_page)

    {:noreply,
     socket
     |> assign(:project_id, project_id)
     |> assign(:perubahan, perubahan)
     |> assign(:paginated_perubahan, paginated_perubahan)
     |> assign(:perubahan_total, total)
     |> assign(:page, page)
     |> assign(:total_pages, total_pages)}
  end

  # Hanya data dari pangkalan data – tiada data statik atau hardcoded
  defp load_perubahan(project_id) do
    if project_id do
      PermohonanPerubahan.list_by_project(project_id)
    else
      []
    end
  end

  defp parse_perubahan_id(perubahan_id) when is_binary(perubahan_id) do
    case Integer.parse(perubahan_id) do
      {int, _rest} -> int
      :error -> nil
    end
  end

  defp parse_perubahan_id(perubahan_id) when is_integer(perubahan_id), do: perubahan_id
  defp parse_perubahan_id(_), do: nil

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    %{page: page, total_pages: total_pages, per_page: per_page, perubahan: perubahan} =
      socket.assigns

    new_page = min(page + 1, total_pages)
    paginated = paginate(perubahan, new_page, per_page)

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:paginated_perubahan, paginated)}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    %{page: page, per_page: per_page, perubahan: perubahan} = socket.assigns

    new_page = max(page - 1, 1)
    paginated = paginate(perubahan, new_page, per_page)

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:paginated_perubahan, paginated)}
  end

  @impl true
  def handle_event("go_to_page", %{"page" => page_param}, socket) do
    %{total_pages: total_pages, per_page: per_page, perubahan: perubahan} = socket.assigns

    new_page =
      case Integer.parse(page_param) do
        {int, _} when int >= 1 and int <= total_pages -> int
        _ -> socket.assigns.page
      end

    paginated = paginate(perubahan, new_page, per_page)

    {:noreply,
     socket
     |> assign(:page, new_page)
     |> assign(:paginated_perubahan, paginated)}
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
  def handle_event("open_view_modal", %{"perubahan_id" => perubahan_id}, socket) do
    id = parse_perubahan_id(perubahan_id)
    perubahan = id && Enum.find(socket.assigns.perubahan, fn p -> p.id == id end)

    if perubahan do
      {:noreply,
       socket
       |> assign(:show_view_modal, true)
       |> assign(:selected_perubahan, perubahan)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_view_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_view_modal, false)
     |> assign(:selected_perubahan, nil)}
  end

  @impl true
  def handle_event("open_create_modal", _params, socket) do
    form = to_form(%{}, as: :perubahan)

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
     |> assign(:form, to_form(%{}, as: :perubahan))}
  end

  @impl true
  def handle_event("open_edit_modal", %{"perubahan_id" => perubahan_id}, socket) do
    id = parse_perubahan_id(perubahan_id)
    perubahan = id && Enum.find(socket.assigns.perubahan, fn p -> p.id == id end)

    if perubahan do
      tarikh_dijangka_siap_str =
        if perubahan.tarikh_dijangka_siap do
          Calendar.strftime(perubahan.tarikh_dijangka_siap, "%Y-%m-%d")
        else
          ""
        end

      form_data = %{
        "tajuk" => perubahan.tajuk,
        "jenis" => perubahan.jenis,
        "modul_terlibat" => perubahan.modul_terlibat,
        "tarikh_dibuat" => Calendar.strftime(perubahan.tarikh_dibuat, "%Y-%m-%d"),
        "tarikh_dijangka_siap" => tarikh_dijangka_siap_str,
        "status" => perubahan.status,
        "keutamaan" => perubahan.keutamaan || "",
        "justifikasi" => perubahan.justifikasi || "",
        "kesan" => perubahan.kesan || "",
        "catatan" => perubahan.catatan || ""
      }

      form = to_form(form_data, as: :perubahan)

      {:noreply,
       socket
       |> assign(:show_view_modal, false)
       |> assign(:show_edit_modal, true)
       |> assign(:selected_perubahan, perubahan)
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
     |> assign(:selected_perubahan, nil)
     |> assign(:form, to_form(%{}, as: :perubahan))}
  end

  @impl true
  def handle_event("validate_perubahan", %{"perubahan" => perubahan_params}, socket) do
    form = to_form(perubahan_params, as: :perubahan)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("create_perubahan", %{"perubahan" => perubahan_params}, socket) do
    project_id = socket.assigns.project_id

    if is_nil(project_id) do
      {:noreply,
       socket
       |> put_flash(:error, "Sila pilih projek terlebih dahulu (akses melalui halaman projek).")
       |> assign(:show_create_modal, false)}
    else
      tarikh_dibuat =
        if perubahan_params["tarikh_dibuat"] && perubahan_params["tarikh_dibuat"] != "" do
          case Date.from_iso8601(perubahan_params["tarikh_dibuat"]) do
            {:ok, date} -> date
            _ -> Date.utc_today()
          end
        else
          Date.utc_today()
        end

      tarikh_dijangka_siap =
        if perubahan_params["tarikh_dijangka_siap"] && perubahan_params["tarikh_dijangka_siap"] != "" do
          case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
            {:ok, date} -> date
            _ -> nil
          end
        else
          nil
        end

      attrs = %{
        project_id: project_id,
        tajuk: perubahan_params["tajuk"],
        jenis: perubahan_params["jenis"],
        modul_terlibat: perubahan_params["modul_terlibat"],
        tarikh_dibuat: tarikh_dibuat,
        tarikh_dijangka_siap: tarikh_dijangka_siap,
        status: perubahan_params["status"] || "Dalam Semakan",
        keutamaan: empty_to_nil(perubahan_params["keutamaan"]),
        justifikasi: empty_to_nil(perubahan_params["justifikasi"]),
        kesan: empty_to_nil(perubahan_params["kesan"]),
        catatan: empty_to_nil(perubahan_params["catatan"])
      }

      case PermohonanPerubahan.create_permohonan_perubahan(attrs) do
        {:ok, _perubahan} ->
          perubahan = load_perubahan(project_id)
          per_page = socket.assigns.per_page
          total = length(perubahan)
          total_pages = total_pages(total, per_page)
          page = 1
          paginated_perubahan = paginate(perubahan, page, per_page)

          {:noreply,
           socket
           |> assign(:perubahan, perubahan)
           |> assign(:paginated_perubahan, paginated_perubahan)
           |> assign(:perubahan_total, total)
           |> assign(:page, page)
           |> assign(:total_pages, total_pages)
           |> assign(:show_create_modal, false)
           |> assign(:form, to_form(%{}, as: :perubahan))
           |> put_flash(:info, "Permohonan perubahan berjaya didaftarkan")}

        {:error, changeset} ->
          form = to_form(changeset, as: :perubahan)
          {:noreply,
           socket
           |> assign(:form, form)
           |> put_flash(:error, "Gagal mendaftar. Sila semak maklumat.")}
      end
    end
  end

  @impl true
  def handle_event("update_perubahan", %{"perubahan" => perubahan_params}, socket) do
    selected = socket.assigns.selected_perubahan
    project_id = socket.assigns.project_id

    tarikh_dibuat =
      if perubahan_params["tarikh_dibuat"] && perubahan_params["tarikh_dibuat"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dibuat"]) do
          {:ok, date} -> date
          _ -> selected.tarikh_dibuat
        end
      else
        selected.tarikh_dibuat
      end

    tarikh_dijangka_siap =
      if perubahan_params["tarikh_dijangka_siap"] && perubahan_params["tarikh_dijangka_siap"] != "" do
        case Date.from_iso8601(perubahan_params["tarikh_dijangka_siap"]) do
          {:ok, date} -> date
          _ -> selected.tarikh_dijangka_siap
        end
      else
        nil
      end

    attrs = %{
      tajuk: perubahan_params["tajuk"],
      jenis: perubahan_params["jenis"],
      modul_terlibat: perubahan_params["modul_terlibat"],
      tarikh_dibuat: tarikh_dibuat,
      tarikh_dijangka_siap: tarikh_dijangka_siap,
      status: perubahan_params["status"],
      keutamaan: empty_to_nil(perubahan_params["keutamaan"]),
      justifikasi: empty_to_nil(perubahan_params["justifikasi"]),
      kesan: empty_to_nil(perubahan_params["kesan"]),
      catatan: empty_to_nil(perubahan_params["catatan"])
    }

    case PermohonanPerubahan.update_permohonan_perubahan(selected, attrs) do
      {:ok, _updated} ->
        perubahan = load_perubahan(project_id)
        per_page = socket.assigns.per_page
        total = length(perubahan)
        total_pages = total_pages(total, per_page)
        page = min(socket.assigns.page, total_pages)
        paginated_perubahan = paginate(perubahan, page, per_page)

        {:noreply,
         socket
         |> assign(:perubahan, perubahan)
         |> assign(:paginated_perubahan, paginated_perubahan)
         |> assign(:perubahan_total, total)
         |> assign(:page, page)
         |> assign(:total_pages, total_pages)
         |> assign(:show_edit_modal, false)
         |> assign(:selected_perubahan, nil)
         |> assign(:form, to_form(%{}, as: :perubahan))
         |> put_flash(:info, "Perubahan berjaya dikemaskini")}

      {:error, changeset} ->
        form = to_form(changeset, as: :perubahan)
        {:noreply,
         socket
         |> assign(:form, form)
         |> put_flash(:error, "Gagal mengemaskini. Sila semak maklumat.")}
    end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(s) when is_binary(s), do: s
  defp empty_to_nil(other), do: other

  defp paginate(perubahan, page, per_page) do
    start_index = (page - 1) * per_page
    Enum.slice(perubahan, start_index, per_page)
  end

  defp total_pages(0, _per_page), do: 1

  defp total_pages(total, per_page) do
    pages = div(total, per_page)
    if rem(total, per_page) == 0, do: pages, else: pages + 1
  end
end
