defmodule SppaWeb.UjianKeselamatanLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Handle show action - view ujian details
    mount_show(id, socket)
  end

  def mount(_params, _session, socket) do
    # Handle index action - list all ujian
    mount_index(socket)
  end

  defp mount_index(socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Get safety tests (ujian keselamatan)
      ujian = get_ujian()

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Ujian Keselamatan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:current_path, "/ujian-keselamatan")
        |> assign(:ujian, ujian)
        |> assign(:show_edit_modal, false)
        |> assign(:show_create_modal, false)
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

  defp mount_show(ujian_id, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Butiran Ujian Keselamatan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:current_path, "/ujian-keselamatan")

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
           |> assign(:show_create_modal, false)
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
            |> Phoenix.LiveView.redirect(to: ~p"/ujian-keselamatan")

          {:ok, socket}
        end
      else
        {:ok,
         socket
         |> assign(:selected_ujian, nil)
         |> assign(:ujian, [])
         |> assign(:show_edit_modal, false)
         |> assign(:show_create_modal, false)
         |> assign(:show_edit_kes_modal, false)
         |> assign(:selected_kes, nil)
         |> assign(:form, to_form(%{}, as: :ujian))
         |> assign(:kes_form, to_form(%{}, as: :kes))}
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
    get_ujian()
    |> Enum.find(fn u -> u.id == ujian_id end)
  end

  # Get safety tests (ujian keselamatan)
  # TODO: In the future, this should be retrieved from a database or context module
  defp get_ujian do
    [
      %{
        id: "ujian_keselamatan_1",
        number: 1,
        tajuk: "Ujian Keselamatan Autentikasi",
        modul: "Modul Autentikasi",
        tarikh_ujian: ~D[2024-12-01],
        tarikh_dijangka_siap: ~D[2024-12-15],
        status: "Dalam Proses",
        penguji: "Ahmad bin Abdullah",
        hasil: "Belum Selesai",
        catatan: "Ujian keselamatan untuk autentikasi pengguna",
        senarai_kes_ujian: [
          %{
            id: "SEC-001",
            senario: "Ujian kekuatan kata laluan",
            langkah: "1. Layari halaman pendaftaran\n2. Cuba daftar dengan kata laluan lemah",
            keputusan_dijangka: "Sistem menolak kata laluan lemah dan memaparkan mesej ralat",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-002",
            senario: "Ujian perlindungan terhadap serangan brute force",
            langkah: "1. Cuba log masuk dengan kata laluan salah berkali-kali\n2. Perhatikan tindakan sistem",
            keputusan_dijangka: "Sistem mengunci akaun selepas beberapa percubaan gagal",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-003",
            senario: "Ujian perlindungan terhadap SQL injection",
            langkah: "1. Cuba masukkan kod SQL dalam medan input\n2. Perhatikan respons sistem",
            keputusan_dijangka: "Sistem menapis input dan tidak membenarkan kod SQL dilaksanakan",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-004",
            senario: "Ujian perlindungan terhadap XSS (Cross-Site Scripting)",
            langkah: "1. Cuba masukkan skrip JavaScript dalam medan input\n2. Perhatikan respons sistem",
            keputusan_dijangka: "Sistem menapis atau melarikan skrip JavaScript",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          },
          %{
            id: "SEC-005",
            senario: "Ujian pengurusan sesi",
            langkah: "1. Log masuk ke sistem\n2. Tutup pelayar tanpa log keluar\n3. Buka semula dan cuba akses",
            keputusan_dijangka: "Sesi tamat tempoh dan pengguna perlu log masuk semula",
            keputusan_sebenar: nil,
            hasil: nil,
            penguji: nil,
            tarikh_ujian: nil,
            disahkan: false,
            tarikh_pengesahan: nil
          }
        ]
      },
      %{
        id: "ujian_keselamatan_2",
        number: 2,
        tajuk: "Ujian Keselamatan Data",
        modul: "Modul Pengurusan Data",
        tarikh_ujian: ~D[2024-12-05],
        tarikh_dijangka_siap: ~D[2024-12-20],
        status: "Selesai",
        penguji: "Siti binti Hassan",
        hasil: "Lulus",
        catatan: "Semua ujian keselamatan data berjaya diluluskan",
        senarai_ujian: [],
        senarai_kes_ujian: []
      },
      %{
        id: "ujian_keselamatan_3",
        number: 3,
        tajuk: "Ujian Keselamatan Rangkaian",
        modul: "Modul Rangkaian",
        tarikh_ujian: ~D[2024-12-10],
        tarikh_dijangka_siap: ~D[2024-12-25],
        status: "Menunggu",
        penguji: "Mohd bin Ismail",
        hasil: "Belum Selesai",
        catatan: "Menunggu untuk memulakan ujian",
        senarai_ujian: [],
        senarai_kes_ujian: []
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
    {:noreply, update(socket, :notifications_open, &(!&1))}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
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
  def handle_event("create_ujian", %{"ujian" => ujian_params}, socket) do
    # TODO: In the future, this should save to the database
    new_id = "ujian_keselamatan_#{length(socket.assigns.ujian) + 1}"
    new_number = length(socket.assigns.ujian) + 1

    tarikh_ujian =
      if ujian_params["tarikh_ujian"] && ujian_params["tarikh_ujian"] != "" do
        case Date.from_iso8601(ujian_params["tarikh_ujian"]) do
          {:ok, date} -> date
          _ -> Date.utc_today()
        end
      else
        Date.utc_today()
      end

    tarikh_dijangka_siap =
      case Date.from_iso8601(ujian_params["tarikh_dijangka_siap"]) do
        {:ok, date} -> date
        _ -> Date.utc_today()
      end

    new_ujian = %{
      id: new_id,
      number: new_number,
      tajuk: ujian_params["tajuk"],
      modul: ujian_params["modul"],
      tarikh_ujian: tarikh_ujian,
      tarikh_dijangka_siap: tarikh_dijangka_siap,
      status: ujian_params["status"] || "Menunggu",
      penguji: ujian_params["penguji"] || "",
      hasil: ujian_params["hasil"] || "Belum Selesai",
      catatan: if(ujian_params["catatan"] == "", do: nil, else: ujian_params["catatan"]),
      senarai_ujian: [],
      senarai_kes_ujian: []
    }

    updated_ujian = [new_ujian | socket.assigns.ujian]

    {:noreply,
     socket
     |> assign(:ujian, updated_ujian)
     |> assign(:show_create_modal, false)
     |> assign(:form, to_form(%{}, as: :ujian))
     |> put_flash(:info, "Ujian keselamatan berjaya didaftarkan")}
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
          catatan:
            if(ujian_params["catatan"] == "", do: nil, else: ujian_params["catatan"])
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
          "tarikh_ujian" => if(kes.tarikh_ujian, do: Calendar.strftime(kes.tarikh_ujian, "%Y-%m-%d"), else: ""),
          "disahkan" => if(Map.get(kes, :disahkan, false), do: "true", else: ""),
          "tarikh_pengesahan" => if(kes.tarikh_pengesahan, do: Calendar.strftime(kes.tarikh_pengesahan, "%Y-%m-%d"), else: "")
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
        keputusan_sebenar: if(kes_params["keputusan_sebenar"] == "", do: nil, else: kes_params["keputusan_sebenar"]),
        hasil: if(kes_params["hasil"] == "", do: nil, else: kes_params["hasil"]),
        penguji: if(kes_params["penguji"] == "", do: nil, else: kes_params["penguji"]),
        tarikh_ujian: tarikh_ujian,
        disahkan: kes_params["disahkan"] == "true",
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
      existing_ids = Enum.map(socket.assigns.selected_ujian.senarai_kes_ujian, fn kes -> kes.id end)

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
end
