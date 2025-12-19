defmodule SppaWeb.PenempatanLive do
  use SppaWeb, :live_view

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
      # Get deployment records (penempatan)
      penempatan = get_penempatan()

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Penempatan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/penempatan")
        |> assign(:penempatan, penempatan)
        |> assign(:show_edit_modal, false)
        |> assign(:show_create_modal, false)
        |> assign(:selected_penempatan, nil)
        |> assign(:form, to_form(%{}, as: :penempatan))

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

  # Get penempatan by id
  defp get_penempatan_by_id(penempatan_id) do
    get_penempatan()
    |> Enum.find(fn p -> p.id == penempatan_id end)
  end

  # Get deployment records (penempatan)
  # TODO: In the future, this should be retrieved from a database or context module
  defp get_penempatan do
    [
      %{
        id: "penempatan_1",
        number: 1,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.0.0",
        lokasi: "Server Produksi - JPKN",
        tarikh_penempatan: ~D[2024-12-15],
        tarikh_dijangka: ~D[2024-12-10],
        status: "Selesai",
        jenis: "Produksi",
        persekitaran: "Produksi",
        url: "https://sppa.jpkn.gov.my",
        catatan: "Penempatan pertama untuk sistem pengurusan permohonan",
        dibina_oleh: "Ahmad bin Abdullah",
        disemak_oleh: "Siti binti Hassan",
        diluluskan_oleh: "Mohd bin Ismail",
        tarikh_dibina: ~D[2024-12-05],
        tarikh_disemak: ~D[2024-12-08],
        tarikh_diluluskan: ~D[2024-12-10]
      },
      %{
        id: "penempatan_2",
        number: 2,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.1.0",
        lokasi: "Server Staging - JPKN",
        tarikh_penempatan: ~D[2024-12-20],
        tarikh_dijangka: ~D[2024-12-18],
        status: "Dalam Proses",
        jenis: "Staging",
        persekitaran: "Staging",
        url: "https://staging-sppa.jpkn.gov.my",
        catatan: "Penempatan untuk ujian staging sebelum produksi",
        dibina_oleh: "Ahmad bin Abdullah",
        disemak_oleh: nil,
        diluluskan_oleh: nil,
        tarikh_dibina: ~D[2024-12-15],
        tarikh_disemak: nil,
        tarikh_diluluskan: nil
      },
      %{
        id: "penempatan_3",
        number: 3,
        nama_sistem: "Sistem Pengurusan Permohonan",
        versi: "1.2.0",
        lokasi: "Server Development - JPKN",
        tarikh_penempatan: ~D[2024-12-25],
        tarikh_dijangka: ~D[2024-12-22],
        status: "Menunggu",
        jenis: "Development",
        persekitaran: "Development",
        url: "https://dev-sppa.jpkn.gov.my",
        catatan: "Penempatan untuk persekitaran pembangunan",
        dibina_oleh: nil,
        disemak_oleh: nil,
        diluluskan_oleh: nil,
        tarikh_dibina: nil,
        tarikh_disemak: nil,
        tarikh_diluluskan: nil
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
    form = to_form(%{}, as: :penempatan)

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
    # Try to find penempatan from list first, then from selected_penempatan
    penempatan =
      if socket.assigns[:penempatan] && length(socket.assigns.penempatan) > 0 do
        Enum.find(socket.assigns.penempatan, fn p -> p.id == penempatan_id end)
      else
        if socket.assigns[:selected_penempatan] && socket.assigns.selected_penempatan.id == penempatan_id do
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
        "tarikh_dijangka" => Calendar.strftime(penempatan.tarikh_dijangka, "%Y-%m-%d"),
        "status" => penempatan.status,
        "jenis" => penempatan.jenis,
        "persekitaran" => penempatan.persekitaran,
        "url" => penempatan.url || "",
        "catatan" => penempatan.catatan || "",
        "dibina_oleh" => penempatan.dibina_oleh || "",
        "disemak_oleh" => Map.get(penempatan, :disemak_oleh, "") || "",
        "diluluskan_oleh" => Map.get(penempatan, :diluluskan_oleh, "") || "",
        "tarikh_dibina" => if(penempatan.tarikh_dibina, do: Calendar.strftime(penempatan.tarikh_dibina, "%Y-%m-%d"), else: ""),
        "tarikh_disemak" => if(Map.get(penempatan, :tarikh_disemak), do: Calendar.strftime(penempatan.tarikh_disemak, "%Y-%m-%d"), else: ""),
        "tarikh_diluluskan" => if(Map.get(penempatan, :tarikh_diluluskan), do: Calendar.strftime(penempatan.tarikh_diluluskan, "%Y-%m-%d"), else: "")
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
    # TODO: In the future, this should save to the database
    new_id = "penempatan_#{length(socket.assigns.penempatan) + 1}"
    new_number = length(socket.assigns.penempatan) + 1

    tarikh_penempatan =
      if penempatan_params["tarikh_penempatan"] && penempatan_params["tarikh_penempatan"] != "" do
        case Date.from_iso8601(penempatan_params["tarikh_penempatan"]) do
          {:ok, date} -> date
          _ -> Date.utc_today()
        end
      else
        Date.utc_today()
      end

    tarikh_dijangka =
      if penempatan_params["tarikh_dijangka"] && penempatan_params["tarikh_dijangka"] != "" do
        case Date.from_iso8601(penempatan_params["tarikh_dijangka"]) do
          {:ok, date} -> date
          _ -> Date.utc_today()
        end
      else
        Date.utc_today()
      end

    tarikh_dibina =
      if penempatan_params["tarikh_dibina"] && penempatan_params["tarikh_dibina"] != "" do
        case Date.from_iso8601(penempatan_params["tarikh_dibina"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    tarikh_disemak =
      if penempatan_params["tarikh_disemak"] && penempatan_params["tarikh_disemak"] != "" do
        case Date.from_iso8601(penempatan_params["tarikh_disemak"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    tarikh_diluluskan =
      if penempatan_params["tarikh_diluluskan"] && penempatan_params["tarikh_diluluskan"] != "" do
        case Date.from_iso8601(penempatan_params["tarikh_diluluskan"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    new_penempatan = %{
      id: new_id,
      number: new_number,
      nama_sistem: penempatan_params["nama_sistem"],
      versi: penempatan_params["versi"] || "",
      lokasi: penempatan_params["lokasi"],
      tarikh_penempatan: tarikh_penempatan,
      tarikh_dijangka: tarikh_dijangka,
      status: penempatan_params["status"] || "Menunggu",
      jenis: penempatan_params["jenis"] || "",
      persekitaran: penempatan_params["persekitaran"] || "",
      url: penempatan_params["url"] || "",
      catatan: if(penempatan_params["catatan"] == "", do: nil, else: penempatan_params["catatan"]),
      dibina_oleh: penempatan_params["dibina_oleh"] || "",
      disemak_oleh: if(penempatan_params["disemak_oleh"] == "", do: nil, else: penempatan_params["disemak_oleh"]),
      diluluskan_oleh: if(penempatan_params["diluluskan_oleh"] == "", do: nil, else: penempatan_params["diluluskan_oleh"]),
      tarikh_dibina: tarikh_dibina,
      tarikh_disemak: tarikh_disemak,
      tarikh_diluluskan: tarikh_diluluskan
    }

    updated_penempatan = [new_penempatan | socket.assigns.penempatan]

    {:noreply,
     socket
     |> assign(:penempatan, updated_penempatan)
     |> assign(:show_create_modal, false)
     |> assign(:form, to_form(%{}, as: :penempatan))
     |> put_flash(:info, "Penempatan berjaya didaftarkan")}
  end

  @impl true
  def handle_event("update_penempatan", %{"penempatan" => penempatan_params}, socket) do
    # TODO: In the future, this should update the database
    editing_penempatan = socket.assigns[:editing_penempatan] || socket.assigns[:selected_penempatan]

    if editing_penempatan do
      penempatan_id = editing_penempatan.id

      tarikh_penempatan =
        if penempatan_params["tarikh_penempatan"] && penempatan_params["tarikh_penempatan"] != "" do
          case Date.from_iso8601(penempatan_params["tarikh_penempatan"]) do
            {:ok, date} -> date
            _ -> editing_penempatan.tarikh_penempatan
          end
        else
          editing_penempatan.tarikh_penempatan
        end

      tarikh_dijangka =
        if penempatan_params["tarikh_dijangka"] && penempatan_params["tarikh_dijangka"] != "" do
          case Date.from_iso8601(penempatan_params["tarikh_dijangka"]) do
            {:ok, date} -> date
            _ -> editing_penempatan.tarikh_dijangka
          end
        else
          editing_penempatan.tarikh_dijangka
        end

      tarikh_dibina =
        if penempatan_params["tarikh_dibina"] && penempatan_params["tarikh_dibina"] != "" do
          case Date.from_iso8601(penempatan_params["tarikh_dibina"]) do
            {:ok, date} -> date
            _ -> Map.get(editing_penempatan, :tarikh_dibina, nil)
          end
        else
          Map.get(editing_penempatan, :tarikh_dibina, nil)
        end

      tarikh_disemak =
        if penempatan_params["tarikh_disemak"] && penempatan_params["tarikh_disemak"] != "" do
          case Date.from_iso8601(penempatan_params["tarikh_disemak"]) do
            {:ok, date} -> date
            _ -> Map.get(editing_penempatan, :tarikh_disemak, nil)
          end
        else
          Map.get(editing_penempatan, :tarikh_disemak, nil)
        end

      tarikh_diluluskan =
        if penempatan_params["tarikh_diluluskan"] && penempatan_params["tarikh_diluluskan"] != "" do
          case Date.from_iso8601(penempatan_params["tarikh_diluluskan"]) do
            {:ok, date} -> date
            _ -> Map.get(editing_penempatan, :tarikh_diluluskan, nil)
          end
        else
          Map.get(editing_penempatan, :tarikh_diluluskan, nil)
        end

      updated_penempatan_data = %{
        editing_penempatan
        | nama_sistem: penempatan_params["nama_sistem"] || editing_penempatan.nama_sistem,
          versi: penempatan_params["versi"] || "",
          lokasi: penempatan_params["lokasi"],
          tarikh_penempatan: tarikh_penempatan,
          tarikh_dijangka: tarikh_dijangka,
          status: penempatan_params["status"],
          jenis: penempatan_params["jenis"],
          persekitaran: penempatan_params["persekitaran"],
          url: penempatan_params["url"] || "",
          catatan: if(penempatan_params["catatan"] == "", do: nil, else: penempatan_params["catatan"]),
          dibina_oleh: penempatan_params["dibina_oleh"] || "",
          disemak_oleh: if(penempatan_params["disemak_oleh"] == "", do: nil, else: penempatan_params["disemak_oleh"]),
          diluluskan_oleh: if(penempatan_params["diluluskan_oleh"] == "", do: nil, else: penempatan_params["diluluskan_oleh"]),
          tarikh_dibina: tarikh_dibina,
          tarikh_disemak: tarikh_disemak,
          tarikh_diluluskan: tarikh_diluluskan
      }

      # Update in list if we're on index page
      updated_penempatan_list =
        if socket.assigns[:penempatan] && length(socket.assigns.penempatan) > 0 do
          Enum.map(socket.assigns.penempatan, fn penempatan ->
            if penempatan.id == penempatan_id, do: updated_penempatan_data, else: penempatan
          end)
        else
          []
        end

      # Update selected_penempatan if we're on detail page
      updated_socket =
        socket
        |> assign(:penempatan, updated_penempatan_list)
        |> assign(:show_edit_modal, false)
        |> assign(:editing_penempatan, nil)
        |> assign(:form, to_form(%{}, as: :penempatan))
        |> put_flash(:info, "Penempatan berjaya dikemaskini")

      # Only update selected_penempatan if we're on detail page
      final_socket =
        if socket.assigns[:selected_penempatan] && socket.assigns.selected_penempatan.id == penempatan_id do
          assign(updated_socket, :selected_penempatan, updated_penempatan_data)
        else
          updated_socket
        end

      {:noreply, final_socket}
    else
      {:noreply, socket}
    end
  end
end
