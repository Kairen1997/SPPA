defmodule SppaWeb.PenyerahanLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"project_id" => project_id, "id" => id}, _session, socket) do
    mount_show(id, socket, String.to_integer(project_id))
  end

  def mount(%{"project_id" => project_id}, _session, socket) do
    mount_index(socket, String.to_integer(project_id))
  end

  def mount(%{"id" => id}, _session, socket) do
    # Handle show action - view penyerahan details (tanpa project scope)
    mount_show(id, socket, nil)
  end

  def mount(_params, _session, socket) do
    # Handle index action - list all penyerahan
    mount_index(socket, nil)
  end

  defp index_path(nil), do: ~p"/penyerahan"
  defp index_path(project_id), do: ~p"/projek/#{project_id}/penyerahan"

  defp mount_index(socket, project_id) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Verify project access when project_id is present
      project_assigns =
        if project_id do
          project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)
          if project do
            [project_id: project_id, project: project]
          else
            nil
          end
        else
          [project_id: nil, project: nil]
        end

      if project_id && project_assigns == nil do
        {:ok,
         socket
         |> put_flash(:error, "Projek tidak dijumpai atau anda tidak mempunyai akses.")
         |> redirect(to: ~p"/projek")}
      else
        # Get submission records (penyerahan)
        # TODO: Filter by project_id when data comes from DB
        penyerahan = get_penyerahan()

        current_path = index_path(project_id) |> to_string()

        socket =
          socket
          |> assign(:hide_root_header, true)
          |> assign(:page_title, "Penyerahan")
          |> assign(:sidebar_open, false)
          |> assign(:notifications_open, false)
          |> assign(:profile_menu_open, false)
          |> assign(:current_path, current_path)
          |> assign(:index_path, index_path(project_id))
          |> assign(project_assigns || [])
          |> assign(:penyerahan, penyerahan)
        |> assign(:show_edit_modal, false)
        |> assign(:editing_penyerahan, nil)
        |> assign(:show_create_modal, false)
        |> assign(:show_upload_modal, false)
        |> assign(:selected_penyerahan, nil)
        |> assign(:uploading_penyerahan_id, nil)
        |> assign(:form, to_form(%{}, as: :penyerahan))
        |> assign(:upload_manual_form, to_form(%{}, as: :upload_manual))
        |> assign(:upload_surat_form, to_form(%{}, as: :upload_surat))
        |> assign(:expanded_catatan, MapSet.new())

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

  defp mount_show(penyerahan_id, socket, project_id) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Verify project access when project_id is present
      project_assigns =
        if project_id do
          project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)
          if project do
            [project_id: project_id, project: project]
          else
            nil
          end
        else
          [project_id: nil, project: nil]
        end

      if project_id && project_assigns == nil do
        {:ok,
         socket
         |> put_flash(:error, "Projek tidak dijumpai atau anda tidak mempunyai akses.")
         |> redirect(to: ~p"/projek")}
      else
        current_path = index_path(project_id) |> to_string()

        socket =
          socket
          |> assign(:hide_root_header, true)
          |> assign(:page_title, "Butiran Penyerahan")
          |> assign(:sidebar_open, false)
          |> assign(:notifications_open, false)
          |> assign(:profile_menu_open, false)
          |> assign(:current_path, current_path)
          |> assign(:index_path, index_path(project_id))
          |> assign(project_assigns || [])

        if connected?(socket) do
          penyerahan = get_penyerahan_by_id(penyerahan_id)

          if penyerahan do
            activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)
            notifications_count = length(activities)

            {:ok,
             socket
             |> assign(:selected_penyerahan, penyerahan)
             |> assign(:penyerahan, [])
             |> assign(:show_edit_modal, false)
             |> assign(:editing_penyerahan, nil)
             |> assign(:show_create_modal, false)
             |> assign(:show_upload_modal, false)
             |> assign(:uploading_penyerahan_id, nil)
             |> assign(:form, to_form(%{}, as: :penyerahan))
             |> assign(:upload_manual_form, to_form(%{}, as: :upload_manual))
             |> assign(:upload_surat_form, to_form(%{}, as: :upload_surat))
             |> assign(:expanded_catatan, MapSet.new())
             |> assign(:activities, activities)
             |> assign(:notifications_count, notifications_count)}
          else
            redirect_to = index_path(project_id)

            {:ok,
             socket
             |> put_flash(:error, "Penyerahan tidak dijumpai.")
             |> redirect(to: redirect_to)}
          end
      else
        {:ok,
         socket
         |> assign(:selected_penyerahan, nil)
         |> assign(:penyerahan, [])
         |> assign(:show_edit_modal, false)
         |> assign(:editing_penyerahan, nil)
         |> assign(:show_create_modal, false)
         |> assign(:show_upload_modal, false)
         |> assign(:uploading_penyerahan_id, nil)
         |> assign(:form, to_form(%{}, as: :penyerahan))
         |> assign(:upload_manual_form, to_form(%{}, as: :upload_manual))
         |> assign(:upload_surat_form, to_form(%{}, as: :upload_surat))
         |> assign(:expanded_catatan, MapSet.new())}
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

  # Get penyerahan by id
  defp get_penyerahan_by_id(penyerahan_id) do
    get_penyerahan()
    |> Enum.find(fn p -> p.id == penyerahan_id end)
  end

  # Get submission records (penyerahan)
  # TODO: In the future, this should be retrieved from a database or context module
  defp get_penyerahan do
    [
      %{
        id: "penyerahan_1",
        number: 1,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.0.0",
        tarikh_penyerahan: ~D[2024-12-20],
        tarikh_dijangka: ~D[2024-12-18],
        status: "Selesai",
        penerima: "Jabatan Teknologi Maklumat",
        pembangun_team: "Team Alpha",
        pengurus_projek: "Siti binti Hassan",
        lokasi: "Pejabat Utama JPKN",
        catatan: "Penyerahan pertama untuk sistem pengurusan permohonan",
        manual_pengguna_bahagian_a: "manual_pengguna_bahagian_a_v1.0.0.pdf",
        surat_akuan_penerimaan: "surat_akuan_penerimaan_v1.0.0.pdf",
        diserahkan_oleh: "Ahmad bin Abdullah",
        diterima_oleh: "Siti binti Hassan",
        tarikh_diserahkan: ~D[2024-12-20],
        tarikh_diterima: ~D[2024-12-20]
      },
      %{
        id: "penyerahan_2",
        number: 2,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.1.0",
        tarikh_penyerahan: ~D[2024-12-25],
        tarikh_dijangka: ~D[2024-12-22],
        status: "Dalam Proses",
        penerima: "Jabatan Teknologi Maklumat",
        pembangun_team: "Team Beta",
        pengurus_projek: "Ahmad bin Abdullah",
        lokasi: "Pejabat Utama JPKN",
        catatan: "Penyerahan untuk versi 1.1.0",
        manual_pengguna_bahagian_a: nil,
        surat_akuan_penerimaan: nil,
        diserahkan_oleh: "Ahmad bin Abdullah",
        diterima_oleh: nil,
        tarikh_diserahkan: ~D[2024-12-25],
        tarikh_diterima: nil
      },
      %{
        id: "penyerahan_3",
        number: 3,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.2.0",
        tarikh_penyerahan: nil,
        tarikh_dijangka: ~D[2024-12-28],
        status: "Menunggu",
        penerima: "Jabatan Teknologi Maklumat",
        pembangun_team: nil,
        pengurus_projek: nil,
        lokasi: "Pejabat Utama JPKN",
        catatan: "Penyerahan untuk versi 1.2.0",
        manual_pengguna_bahagian_a: nil,
        surat_akuan_penerimaan: nil,
        diserahkan_oleh: nil,
        diterima_oleh: nil,
        tarikh_diserahkan: nil,
        tarikh_diterima: nil
      }
    ]
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
    form = to_form(%{}, as: :penyerahan)

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
     |> assign(:form, to_form(%{}, as: :penyerahan))}
  end

  @impl true
  def handle_event("open_edit_modal", %{"penyerahan_id" => penyerahan_id}, socket) do
    penyerahan = get_penyerahan_by_id(penyerahan_id)

    if penyerahan do
      form_data = %{
        "nama_sistem" => penyerahan.nama_sistem,
        "versi" => penyerahan.versi || "",
        "penerima" => penyerahan.penerima,
        "pembangun_team" => penyerahan.pembangun_team || "",
        "pengurus_projek" => penyerahan.pengurus_projek || "",
        "lokasi" => penyerahan.lokasi,
        "status" => penyerahan.status,
        "tarikh_dijangka" =>
          if(penyerahan.tarikh_dijangka,
            do: Calendar.strftime(penyerahan.tarikh_dijangka, "%Y-%m-%d"),
            else: ""
          ),
        "tarikh_penyerahan" =>
          if(penyerahan.tarikh_penyerahan,
            do: Calendar.strftime(penyerahan.tarikh_penyerahan, "%Y-%m-%d"),
            else: ""
          ),
        "diserahkan_oleh" => penyerahan.diserahkan_oleh || "",
        "diterima_oleh" => penyerahan.diterima_oleh || "",
        "catatan" => penyerahan.catatan || ""
      }

      form = to_form(form_data, as: :penyerahan)

      {:noreply,
       socket
       |> assign(:show_edit_modal, true)
       |> assign(:editing_penyerahan, penyerahan)
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
     |> assign(:editing_penyerahan, nil)
     |> assign(:form, to_form(%{}, as: :penyerahan))}
  end

  @impl true
  def handle_event("open_upload_modal", %{"penyerahan_id" => penyerahan_id}, socket) do
    # Try to find penyerahan from list first
    penyerahan =
      if socket.assigns[:penyerahan] && length(socket.assigns.penyerahan) > 0 do
        Enum.find(socket.assigns.penyerahan, fn p -> p.id == penyerahan_id end)
      else
        get_penyerahan_by_id(penyerahan_id)
      end

    if penyerahan do
      {:noreply,
       socket
       |> assign(:show_upload_modal, true)
       |> assign(:uploading_penyerahan_id, penyerahan_id)
       |> assign(:uploading_penyerahan, penyerahan)
       |> assign(:upload_manual_form, to_form(%{}, as: :upload_manual))
       |> assign(:upload_surat_form, to_form(%{}, as: :upload_surat))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_upload_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_modal, false)
     |> assign(:uploading_penyerahan_id, nil)
     |> assign(:uploading_penyerahan, nil)
     |> assign(:upload_manual_form, to_form(%{}, as: :upload_manual))
     |> assign(:upload_surat_form, to_form(%{}, as: :upload_surat))}
  end

  @impl true
  def handle_event("upload_manual", %{"upload_manual" => upload_params}, socket) do
    # Handle file upload for manual pengguna bahagian A
    # TODO: In the future, this should save the file to storage and update the database
    penyerahan_id =
      upload_params["penyerahan_id"] ||
        socket.assigns[:uploading_penyerahan_id] ||
        if socket.assigns[:selected_penyerahan],
          do: socket.assigns[:selected_penyerahan].id,
          else: nil

    if penyerahan_id do
      # Update the penyerahan record with the uploaded file
      updated_penyerahan =
        Enum.map(socket.assigns.penyerahan, fn penyerahan ->
          if penyerahan.id == penyerahan_id do
            %{penyerahan | manual_pengguna_bahagian_a: "manual_pengguna_#{penyerahan_id}.pdf"}
          else
            penyerahan
          end
        end)

      {:noreply,
       socket
       |> assign(:penyerahan, updated_penyerahan)
       |> put_flash(:info, "Manual pengguna bahagian A berjaya dimuat naik")
       |> assign(:upload_manual_form, to_form(%{}, as: :upload_manual))}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Sila pilih penyerahan terlebih dahulu")
       |> assign(:upload_manual_form, to_form(%{}, as: :upload_manual))}
    end
  end

  @impl true
  def handle_event("upload_surat", %{"upload_surat" => upload_params}, socket) do
    # Handle file upload for surat akuan penerimaan
    # TODO: In the future, this should save the file to storage and update the database
    penyerahan_id =
      upload_params["penyerahan_id"] ||
        socket.assigns[:uploading_penyerahan_id] ||
        if socket.assigns[:selected_penyerahan],
          do: socket.assigns[:selected_penyerahan].id,
          else: nil

    if penyerahan_id do
      # Update the penyerahan record with the uploaded file
      updated_penyerahan =
        Enum.map(socket.assigns.penyerahan, fn penyerahan ->
          if penyerahan.id == penyerahan_id do
            %{penyerahan | surat_akuan_penerimaan: "surat_akuan_#{penyerahan_id}.pdf"}
          else
            penyerahan
          end
        end)

      {:noreply,
       socket
       |> assign(:penyerahan, updated_penyerahan)
       |> put_flash(:info, "Surat Akuan Penerimaan Aplikasi berjaya dimuat naik")
       |> assign(:upload_surat_form, to_form(%{}, as: :upload_surat))}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Sila pilih penyerahan terlebih dahulu")
       |> assign(:upload_surat_form, to_form(%{}, as: :upload_surat))}
    end
  end

  @impl true
  def handle_event("validate_upload_manual", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_upload_surat", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_penyerahan", %{"penyerahan" => penyerahan_params}, socket) do
    form = to_form(penyerahan_params, as: :penyerahan)
    {:noreply, assign(socket, :form, form)}
  end

  @impl true
  def handle_event("create_penyerahan", %{"penyerahan" => penyerahan_params}, socket) do
    # TODO: In the future, this should save to the database
    new_id = "penyerahan_#{length(socket.assigns.penyerahan) + 1}"
    new_number = length(socket.assigns.penyerahan) + 1

    tarikh_penyerahan =
      if penyerahan_params["tarikh_penyerahan"] && penyerahan_params["tarikh_penyerahan"] != "" do
        case Date.from_iso8601(penyerahan_params["tarikh_penyerahan"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    tarikh_dijangka =
      if penyerahan_params["tarikh_dijangka"] && penyerahan_params["tarikh_dijangka"] != "" do
        case Date.from_iso8601(penyerahan_params["tarikh_dijangka"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    new_penyerahan = %{
      id: new_id,
      number: new_number,
      nama_sistem: penyerahan_params["nama_sistem"],
      versi: penyerahan_params["versi"] || "",
      tarikh_penyerahan: tarikh_penyerahan,
      tarikh_dijangka: tarikh_dijangka,
      status: penyerahan_params["status"] || "Menunggu",
      penerima: penyerahan_params["penerima"],
      pembangun_team:
        if(penyerahan_params["pembangun_team"] == "",
          do: nil,
          else: penyerahan_params["pembangun_team"]
        ),
      pengurus_projek:
        if(penyerahan_params["pengurus_projek"] == "",
          do: nil,
          else: penyerahan_params["pengurus_projek"]
        ),
      lokasi: penyerahan_params["lokasi"],
      catatan:
        if(penyerahan_params["catatan"] == "", do: nil, else: penyerahan_params["catatan"]),
      manual_pengguna_bahagian_a: nil,
      surat_akuan_penerimaan: nil,
      diserahkan_oleh:
        if(penyerahan_params["diserahkan_oleh"] == "",
          do: nil,
          else: penyerahan_params["diserahkan_oleh"]
        ),
      diterima_oleh:
        if(penyerahan_params["diterima_oleh"] == "",
          do: nil,
          else: penyerahan_params["diterima_oleh"]
        ),
      tarikh_diserahkan: tarikh_penyerahan,
      tarikh_diterima: nil
    }

    updated_penyerahan = [new_penyerahan | socket.assigns.penyerahan]

    {:noreply,
     socket
     |> assign(:penyerahan, updated_penyerahan)
     |> assign(:show_create_modal, false)
     |> assign(:form, to_form(%{}, as: :penyerahan))
     |> put_flash(:info, "Penyerahan berjaya didaftarkan")}
  end

  @impl true
  def handle_event("update_penyerahan", %{"penyerahan" => penyerahan_params}, socket) do
    # TODO: In the future, this should update the database
    editing_penyerahan = socket.assigns[:editing_penyerahan]

    if editing_penyerahan do
      penyerahan_id = editing_penyerahan.id

      tarikh_penyerahan =
        if penyerahan_params["tarikh_penyerahan"] && penyerahan_params["tarikh_penyerahan"] != "" do
          case Date.from_iso8601(penyerahan_params["tarikh_penyerahan"]) do
            {:ok, date} -> date
            _ -> editing_penyerahan.tarikh_penyerahan
          end
        else
          editing_penyerahan.tarikh_penyerahan
        end

      tarikh_dijangka =
        if penyerahan_params["tarikh_dijangka"] && penyerahan_params["tarikh_dijangka"] != "" do
          case Date.from_iso8601(penyerahan_params["tarikh_dijangka"]) do
            {:ok, date} -> date
            _ -> editing_penyerahan.tarikh_dijangka
          end
        else
          editing_penyerahan.tarikh_dijangka
        end

      updated_penyerahan_data = %{
        editing_penyerahan
        | nama_sistem: penyerahan_params["nama_sistem"] || editing_penyerahan.nama_sistem,
          versi: penyerahan_params["versi"] || "",
          penerima: penyerahan_params["penerima"] || editing_penyerahan.penerima,
          pembangun_team:
            if(penyerahan_params["pembangun_team"] == "",
              do: nil,
              else: penyerahan_params["pembangun_team"]
            ),
          pengurus_projek:
            if(penyerahan_params["pengurus_projek"] == "",
              do: nil,
              else: penyerahan_params["pengurus_projek"]
            ),
          lokasi: penyerahan_params["lokasi"] || editing_penyerahan.lokasi,
          status: penyerahan_params["status"] || editing_penyerahan.status,
          tarikh_penyerahan: tarikh_penyerahan,
          tarikh_dijangka: tarikh_dijangka,
          catatan:
            if(penyerahan_params["catatan"] == "", do: nil, else: penyerahan_params["catatan"]),
          diserahkan_oleh:
            if(penyerahan_params["diserahkan_oleh"] == "",
              do: nil,
              else: penyerahan_params["diserahkan_oleh"]
            ),
          diterima_oleh:
            if(penyerahan_params["diterima_oleh"] == "",
              do: nil,
              else: penyerahan_params["diterima_oleh"]
            )
      }

      # Update in list
      updated_penyerahan_list =
        Enum.map(socket.assigns.penyerahan, fn penyerahan ->
          if penyerahan.id == penyerahan_id, do: updated_penyerahan_data, else: penyerahan
        end)

      # Update selected_penyerahan if we're on detail page
      updated_socket =
        socket
        |> assign(:penyerahan, updated_penyerahan_list)
        |> assign(:show_edit_modal, false)
        |> assign(:editing_penyerahan, nil)
        |> assign(:form, to_form(%{}, as: :penyerahan))
        |> put_flash(:info, "Penyerahan berjaya dikemaskini")

      # Only update selected_penyerahan if we're on detail page
      final_socket =
        if socket.assigns[:selected_penyerahan] &&
             socket.assigns.selected_penyerahan.id == penyerahan_id do
          assign(updated_socket, :selected_penyerahan, updated_penyerahan_data)
        else
          updated_socket
        end

      {:noreply, final_socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_catatan", %{"penyerahan_id" => penyerahan_id}, socket) do
    expanded = socket.assigns.expanded_catatan || MapSet.new()

    expanded =
      if MapSet.member?(expanded, penyerahan_id) do
        MapSet.delete(expanded, penyerahan_id)
      else
        MapSet.put(expanded, penyerahan_id)
      end

    {:noreply, assign(socket, :expanded_catatan, expanded)}
  end
end
