defmodule SppaWeb.ProjekTabNavigationLive do
  use SppaWeb, :live_view

  alias Sppa.AnalisisDanRekabentuk
  alias Sppa.Projects
  alias Sppa.SoalSelidiks

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @tab_slug_to_label %{
    "soal-selidik" => "Soal Selidik",
    "analisis-dan-rekabentuk" => "Analisis dan Rekabentuk",
    "jadual-projek" => "Jadual Projek",
    "pengaturcaraan" => "Pengaturcaraan",
    "pengurus-perubahan" => "Pengurus Perubahan",
    "uat" => "UAT",
    "ujian-keselamatan" => "Ujian Keselamatan",
    "penempatan" => "Penempatan",
    "penyerahan" => "Penyerahan",
    "maklumbalas-pelanggan" => "Maklumbalas Pelanggan"
  }

  @impl true
  def mount(params_or_uri, session, socket) do
    params = ensure_params_map(params_or_uri)
    do_mount(params, session, socket)
  end

  defp ensure_params_map(%{} = params), do: params

  defp ensure_params_map(uri_string) when is_binary(uri_string) do
    # Some code paths pass the request URL as the first argument; extract id from path
    case Regex.run(~r{/projek/(\d+)(?:/|$)}, uri_string) do
      [_, id] -> %{"id" => id}
      _ -> %{}
    end
  end

  defp do_mount(%{"id" => id}, _session, socket) when is_binary(id) do
    project_id = String.to_integer(id)

    # Verify user has required role
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Load project
      project = get_project_by_id(project_id, socket.assigns.current_scope, user_role)

      if project do
        # Load soal selidik data for this project
        # Untuk paparan di tab projek, kita mahu tunjukkan apa sahaja
        # soal selidik yang telah diisi untuk projek ini (tidak kira siapa
        # yang mengisi), selagi pengguna yang melihat mempunyai peranan yang
        # dibenarkan untuk projek tersebut.
        #
        # Fungsi context akan cuba:
        # 1. Cari berdasarkan project_id
        # 2. Jika tiada, padankan berdasarkan nama sistem (nama projek) – ini
        #    meliputi rekod lama yang belum mempunyai project_id.
        soal_selidik =
          SoalSelidiks.get_soal_selidik_for_project_or_by_name(
            project,
            socket.assigns.current_scope
          )

        # Debug logging
        require Logger
        Logger.info("=== PROJEK TAB NAVIGATION DEBUG ===")
        Logger.info("Project ID: #{project.id}")
        Logger.info("Project Nama: #{project.nama}")

        soal_selidik_status =
          if soal_selidik do
            "YES - ID: #{soal_selidik.id}"
          else
            "NO"
          end
        Logger.info("Soal Selidik found: #{soal_selidik_status}")

        soal_selidik_pdf_data =
          if soal_selidik do
            data = SoalSelidiks.to_liveview_format(soal_selidik)
            Logger.info("PDF Data prepared: nama_sistem=#{data.nama_sistem}")
            Logger.info("fr_categories count: #{length(data.fr_categories)}")
            Logger.info("nfr_categories count: #{length(data.nfr_categories)}")
            data
          else
            Logger.info("No soal selidik found for project")
            nil
          end

        Logger.info("================================")

        activities =
          if connected?(socket) do
            Projects.list_recent_activities(socket.assigns.current_scope, 10)
          else
            []
          end

        notifications_count = length(activities)

        analisis_pdf_data =
          AnalisisDanRekabentuk.pdf_data(nama_projek: project.nama || "Projek")

        {:ok,
         socket
         |> assign(:hide_root_header, true)
         |> assign(:page_title, "Butiran Projek")
         |> assign(:sidebar_open, false)
         |> assign(:notifications_open, false)
         |> assign(:profile_menu_open, false)
         |> assign(:project, project)
         |> assign(:soal_selidik_pdf_data, soal_selidik_pdf_data)
         |> assign(:analisis_pdf_data, analisis_pdf_data)
         |> assign(:current_tab, "Soal Selidik")
         |> assign(:activities, activities)
         |> assign(:notifications_count, notifications_count)}
      else
        socket =
          socket
          |> Phoenix.LiveView.put_flash(
            :error,
            "Projek tidak ditemui atau anda tidak mempunyai kebenaran untuk melihat projek ini."
          )
          |> Phoenix.LiveView.redirect(to: ~p"/projek")

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

  defp do_mount(_params, _session, socket) do
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:error, "Projek tidak ditemui.")
      |> Phoenix.LiveView.redirect(to: ~p"/projek")

    {:ok, socket}
  end

  @impl true
  def handle_params(params, uri, socket) do
    # Phoenix may pass uri as a string; ensure we have (params_map, uri_string)
    {params_map, uri_string} = normalize_params_uri(params, uri)
    current_tab = tab_from_params(params_map, uri_string)
    {:noreply,
     socket
     |> assign(:current_tab, current_tab)
     |> assign(:page_title, "Butiran Projek - #{current_tab}")}
  end

  defp normalize_params_uri(params, uri) when is_map(params) do
    {params, to_string(uri)}
  end

  defp normalize_params_uri(uri, params) when is_binary(uri) and is_map(params) do
    # Some code paths pass (uri, params) instead of (params, uri)
    {params, uri}
  end

  defp tab_from_params(params, uri_string) do
    slug =
      params["tab"] ||
        extract_tab_from_uri(uri_string)

    cond do
      slug && slug != "" ->
        Map.get(@tab_slug_to_label, slug, "Soal Selidik")
      String.ends_with?(uri_string, "/soal-selidik") ->
        "Soal Selidik"
      true ->
        "Soal Selidik"
    end
  end

  defp extract_tab_from_uri(uri_string) when is_binary(uri_string) do
    case URI.parse(uri_string) do
      %{query: nil} -> nil
      %{query: query} -> URI.decode_query(query)["tab"]
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

  # Get a single project by ID from database
  defp get_project_by_id(project_id, current_scope, user_role) do
    current_user_id = current_scope.user.id

    # Fetch project from database based on user role
    project =
      case user_role do
        "ketua penolong pengarah" ->
          # Directors/Admins can view any project
          Projects.get_project_by_id(project_id)

        "pembangun sistem" ->
          # Developers can only view projects where they are assigned as developer
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.developer_id == current_user_id, do: p, else: nil
          end

        "pengurus projek" ->
          # Project managers can only view projects where they are assigned as project manager
          case Projects.get_project_by_id(project_id) do
            nil -> nil
            p -> if p.project_manager_id == current_user_id, do: p, else: nil
          end

        _ ->
          nil
      end

    # Format project for display if found
    if project do
      project
      |> Projects.format_project_for_display()
    else
      nil
    end
  end
end
