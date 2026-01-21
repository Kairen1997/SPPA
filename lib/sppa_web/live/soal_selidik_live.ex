defmodule SppaWeb.SoalSelidikLive do
  use SppaWeb, :live_view

  alias Sppa.Projects

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  # Functional Requirements Categories
  @fr_categories [
    %{
      key: "pendaftaran_login",
      title: "Pendaftaran & Login",
      questions: []
    },
    %{
      key: "pengurusan_data",
      title: "Pengurusan Data",
      questions: []
    },
    %{
      key: "proses_kerja",
      title: "Proses Kerja",
      questions: []
    },
    %{
      key: "laporan",
      title: "Laporan",
      questions: []
    },
    %{
      key: "integrasi",
      title: "Integrasi",
      questions: []
    },
    %{
      key: "role_akses",
      title: "Role & Akses",
      questions: []
    },
    %{
      key: "peraturan_polisi",
      title: "Peraturan / Polisi",
      questions: []
    },
    %{
      key: "lain_lain_ciri",
      title: "Lain-lain Ciri Fungsian",
      questions: []
    }
  ]

  # Non-Functional Requirements Categories
  @nfr_categories [
    %{
      key: "keselamatan",
      title: "Keselamatan",
      questions: []
    },
    %{
      key: "akses_capaian",
      title: "Akses / Capaian",
      questions: []
    },
    %{
      key: "usability",
      title: "Usability",
      questions: []
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Initialize default tabs
      default_tabs = [
        %{id: "fr", label: "Functional Requirement", type: :default, removable: false},
        %{id: "nfr", label: "Non-Functional Requirement", type: :default, removable: false},
        %{id: "disediakan_oleh", label: "Disediakan Oleh", type: :default, removable: false}
      ]

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Soal Selidik")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:current_path, "/soal-selidik")
        |> assign(:document_id, "JPKN-BPA-01/B1")
        |> assign(:system_name, "")
        |> assign(:active_tab, "fr")
        |> assign(:tabs, default_tabs)
        |> assign(:fr_categories, @fr_categories)
        |> assign(:nfr_categories, @nfr_categories)
        |> assign(:form, to_form(%{}, as: :soal_selidik))
        |> assign(:show_pdf_modal, false)
        |> assign(:pdf_data, nil)
        |> assign(:show_add_tab_modal, false)
        |> assign(:new_tab_form, to_form(%{}, as: :new_tab))

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
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("show_add_tab_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_tab_modal, true)}
  end

  @impl true
  def handle_event("close_add_tab_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_tab_modal, false)
     |> assign(:new_tab_form, to_form(%{}, as: :new_tab))}
  end

  @impl true
  def handle_event("add_tab", %{"new_tab" => new_tab_params}, socket) do
    label = Map.get(new_tab_params, "label", "") |> String.trim()
    id = Map.get(new_tab_params, "id", "") |> String.trim()

    # Generate ID from label if not provided
    tab_id = if id == "", do: generate_tab_id(label), else: id

    # Validate that label is not empty
    if label == "" do
      form = to_form(new_tab_params, as: :new_tab)
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Label tab tidak boleh kosong.")
       |> assign(:show_add_tab_modal, true)
       |> assign(:new_tab_form, form)}
    else
      # Validate that ID is unique
      existing_ids = Enum.map(socket.assigns.tabs, & &1.id)

      if tab_id in existing_ids do
        form = to_form(new_tab_params, as: :new_tab)
        {:noreply,
         socket
         |> Phoenix.LiveView.put_flash(:error, "ID tab sudah wujud. Sila gunakan ID lain.")
         |> assign(:show_add_tab_modal, true)
         |> assign(:new_tab_form, form)}
      else
        new_tab = %{
          id: tab_id,
          label: label,
          type: :custom,
          removable: true
        }

        updated_tabs = socket.assigns.tabs ++ [new_tab]

        {:noreply,
         socket
         |> assign(:tabs, updated_tabs)
         |> assign(:active_tab, tab_id)
         |> assign(:show_add_tab_modal, false)
         |> assign(:new_tab_form, to_form(%{}, as: :new_tab))
         |> Phoenix.LiveView.put_flash(:info, "Tab baru telah ditambah.")}
      end
    end
  end

  @impl true
  def handle_event("remove_tab", %{"tab_id" => tab_id}, socket) do
    # Prevent removing default tabs
    tab = Enum.find(socket.assigns.tabs, &(&1.id == tab_id))

    if tab && tab.removable do
      updated_tabs = Enum.reject(socket.assigns.tabs, &(&1.id == tab_id))

      # If we removed the active tab, switch to the first tab
      new_active_tab =
        if socket.assigns.active_tab == tab_id do
          case List.first(updated_tabs) do
            nil -> "fr"
            first_tab -> first_tab.id
          end
        else
          socket.assigns.active_tab
        end

      {:noreply,
       socket
       |> assign(:tabs, updated_tabs)
       |> assign(:active_tab, new_active_tab)
       |> Phoenix.LiveView.put_flash(:info, "Tab telah dibuang.")}
    else
      {:noreply,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Tab ini tidak boleh dibuang.")}
    end
  end

  @impl true
  def handle_event("validate_new_tab", %{"new_tab" => new_tab_params}, socket) do
    form = to_form(new_tab_params, as: :new_tab)
    {:noreply, assign(socket, :new_tab_form, form)}
  end

  @impl true
  def handle_event("validate", %{"soal_selidik" => params}, socket) do
    form = to_form(params, as: :soal_selidik)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"soal_selidik" => params}, socket) do
    # For now, just show a success message
    # Later, this will save to the database
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:info, "Soal selidik telah disimpan dengan jayanya.")
      |> assign(:form, to_form(params, as: :soal_selidik))

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_pdf", _params, socket) do
    nama_sistem =
      Phoenix.HTML.Form.input_value(socket.assigns.form, :nama_sistem) ||
        socket.assigns.system_name ||
        "Sistem Pengurusan Projek Aplikasi (SPPA)"

    dummy_data = Sppa.SoalSelidik.pdf_data(nama_sistem: nama_sistem)

    {:noreply,
      socket
     |> assign(:show_pdf_modal, true)
     |> assign(:pdf_data, dummy_data)}
  end

  @impl true
  def handle_event("close_pdf_modal", _params, socket) do
    {:noreply,
      socket
     |> assign(:show_pdf_modal, false)
     |> assign(:pdf_data, nil)}
  end

  defp generate_tab_id(label) do
    label
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s]/, "")
    |> String.replace(~r/\s+/, "_")
    |> then(fn id ->
      # Ensure it's not empty and add prefix if needed
      if id == "", do: "custom_tab_#{System.unique_integer([:positive])}", else: id
    end)
  end

end
