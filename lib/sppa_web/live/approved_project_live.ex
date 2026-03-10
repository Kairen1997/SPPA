defmodule SppaWeb.ApprovedProjectLive do
  use SppaWeb, :live_view

  alias Sppa.ApprovedProjects
  alias Sppa.Projects
  alias Sppa.Accounts
  alias Sppa.ActivityLogs

  @allowed_roles ["pengurus projek", "ketua penolong pengarah", "ketua unit"]

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: current_scope}} = socket) do
    user_role = current_scope && current_scope.user && current_scope.user.role

    if user_role in @allowed_roles do
      {sidebar_dashboard_path, sidebar_list_path, back_list_path} =
        if user_role == "ketua unit" do
          {~p"/dashboard-kk", "/penyerahan-projek", ~p"/penyerahan-projek"}
        else
          {~p"/dashboard-pp", "/senarai-projek-diluluskan", ~p"/senarai-projek-diluluskan"}
        end

      # Only ketua unit can assign pengurus projek.
      can_assign_pm = user_role == "ketua unit"

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Butiran Projek Diluluskan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:show_settings_modal, false)
        |> assign(:notifications_count, 0)
        |> assign(:activities, [])
        |> assign(:sidebar_dashboard_path, sidebar_dashboard_path)
        |> assign(:sidebar_list_path, sidebar_list_path)
        |> assign(:back_list_path, back_list_path)
        |> assign(:can_assign_pm, can_assign_pm)

      case Integer.parse(id) do
        {approved_id, _} ->
          # Load the approved project and all supporting data immediately,
          # so the page renders full information even before the LV socket connects.
          approved_project =
            ApprovedProjects.get_approved_project!(approved_id)
            |> Sppa.Repo.preload([project: [:project_manager, :approved_project]])

          # Parse pengurus projek and pembangun sistem lists
          stored_pm_names = parse_pengurus_projek(approved_project.pengurus_projek)
          stored_dev_names = parse_pembangun_sistem(approved_project.pembangun_sistem)

          # For pengurus projek, verify they are assigned to this specific project
          # They can be assigned either as pengurus_projek OR as pembangun_sistem
          # (since assigned pengurus projek are automatically added to pembangun_sistem)
          if user_role == "pengurus projek" do
            user_no_kp = current_scope.user.no_kp

            # Check if user is in either pengurus_projek or pembangun_sistem list
            has_access = user_no_kp in stored_pm_names || user_no_kp in stored_dev_names

            if not has_access do
              list_path = ~p"/senarai-projek-diluluskan"

              {:ok,
               socket
               |> put_flash(:error, "Anda tidak mempunyai kebenaran untuk mengakses halaman ini.")
               |> push_navigate(to: list_path)}
            else
              # User is assigned, continue with normal flow
              load_approved_project_data(
                socket,
                approved_project,
                stored_pm_names,
                user_role,
                current_scope
              )
            end
          else
            # Not a pengurus projek, continue with normal flow
            load_approved_project_data(
              socket,
              approved_project,
              stored_pm_names,
              user_role,
              current_scope
            )
          end

        :error ->
          list_path =
            if user_role == "ketua unit",
              do: ~p"/penyerahan-projek",
              else: ~p"/senarai-projek-diluluskan"

          {:ok,
           socket
           |> put_flash(:error, "ID projek diluluskan tidak sah.")
           |> push_navigate(to: list_path)}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "Anda tidak mempunyai kebenaran untuk mengakses halaman ini.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:sidebar_dashboard_path, ~p"/dashboard-pp")
     |> assign(:sidebar_list_path, "/senarai-projek-diluluskan")
     |> assign(:back_list_path, ~p"/senarai-projek-diluluskan")
     |> put_flash(:error, "Akses tidak sah.")
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp load_approved_project_data(
         socket,
         approved_project,
         selected_project_managers,
         user_role,
         current_scope
       ) do
    all_users = Accounts.list_users()
    base_developers = Enum.filter(all_users, fn user -> user.role == "pembangun sistem" end)

    # Benarkan pengurus projek melantik diri sendiri sebagai pembangun:
    # tambah pengguna semasa ke dalam senarai pembangun jika belum ada.
    all_developers =
      if user_role == "pengurus projek" do
        current_user = current_scope.user

        if current_user && !Enum.any?(base_developers, fn dev -> dev.id == current_user.id end) do
          [current_user | base_developers]
        else
          base_developers
        end
      else
        base_developers
      end

    all_project_managers =
      Enum.filter(all_users, fn user -> user.role == "pengurus projek" end)

    stored_names = parse_pembangun_sistem(approved_project.pembangun_sistem)
    selected_developers = stored_names

    available_developers =
      all_developers
      |> Enum.filter(fn dev -> dev.no_kp not in selected_developers end)

    available_project_managers =
      all_project_managers
      |> Enum.filter(fn pm -> pm.no_kp not in selected_project_managers end)

    {:ok,
     socket
     |> assign(:approved_project, approved_project)
     |> assign(:developers, all_developers)
     |> assign(:available_developers, available_developers)
     |> assign(:selected_developers, selected_developers)
     |> assign(:project_managers, all_project_managers)
     |> assign(:available_project_managers, available_project_managers)
     |> assign(:selected_project_managers, selected_project_managers)
     # Pengurus projek can assign pembangun sistem only when they are
     # already assigned as pengurus projek for this system.
     |> assign(
       :can_assign_devs,
       user_role == "pengurus projek" &&
         current_scope.user.no_kp in selected_project_managers
     )
     |> assign(
       :form_pembangun,
       to_form(%{"pembangun_sistem" => selected_developers}, as: :project)
     )}
  end

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")

  # Status untuk halaman butiran projek diluluskan.
  # - Jika TIADA pembangun dilantik -> "Belum Lantik Pembangun"
  # - Jika ada pembangun tapi TIADA pengurus -> "Belum Lantik Pengurus"
  # - Jika kedua-dua dilantik -> guna status projek (contoh: "Dalam Pembangunan", "Selesai")
  def status_display_approved_project(approved_project) do
    pembangun_dilantik? =
      (approved_project.project && approved_project.project.developer_id) ||
        (approved_project.pembangun_sistem && approved_project.pembangun_sistem != "")

    pengurus_dilantik? =
      (approved_project.project && approved_project.project.project_manager_id) ||
        (approved_project.pengurus_projek && approved_project.pengurus_projek != "")

    cond do
      !pembangun_dilantik? ->
        "Belum Lantik Pembangun"

      !pengurus_dilantik? ->
        "Belum Lantik Pengurus"

      approved_project.project && approved_project.project.status &&
          approved_project.project.status != "" ->
        approved_project.project.status

      true ->
        "Dalam Pembangunan"
    end
  end

  defp external_api_base_url do
    full_url =
      Application.get_env(:sppa, :system_permohonan_aplikasi, [])[:base_url] ||
        "http://10.71.69.25:4000/api/requests?status=Diluluskan"

    # Extract base URL (remove path and query string)
    case URI.parse(full_url) do
      %URI{scheme: scheme, host: host, port: port} when not is_nil(host) ->
        port_str = if port, do: ":#{port}", else: ""
        "#{scheme}://#{host}#{port_str}"

      _ ->
        "http://10.71.69.25:4000"
    end
  end

  defp ensure_full_url(nil), do: nil

  defp ensure_full_url(url) when is_binary(url) do
    url = String.trim(url)

    # Base URL for the external System Permohonan Aplikasi
    external_base_url = external_api_base_url()
    # Extract host from base URL for normalization
    %URI{host: host, port: port} = URI.parse(external_base_url)
    external_host = if port, do: "#{host}:#{port}", else: host

    # Normalize localhost references to the new external host
    normalized_url =
      url
      |> String.replace("localhost:4000", external_host)
      |> String.replace("127.0.0.1:4000", external_host)

    cond do
      # Already a full URL with http:// or https:// – use as is
      String.starts_with?(normalized_url, ["http://", "https://"]) ->
        normalized_url

      # Starts with the bare host (e.g. "10.71.67.222:4000/uploads/...")
      String.starts_with?(normalized_url, external_host) ->
        "http://" <> normalized_url

      # If it's just a number or ID, construct the file download URL
      Regex.match?(~r/^\d+$/, normalized_url) ->
        "#{external_base_url}/api/files/#{normalized_url}"

      # If it's a relative path starting with /
      String.starts_with?(normalized_url, "/") ->
        external_base_url <> normalized_url

      # If it looks like a file path without leading slash
      String.contains?(normalized_url, ["/", ".pdf", ".PDF"]) ->
        external_base_url <> "/" <> normalized_url

      # Default: treat as relative path segment
      true ->
        external_base_url <> "/" <> normalized_url
    end
  end

  defp ensure_full_url(_), do: nil

  defp parse_pembangun_sistem(nil), do: []
  defp parse_pembangun_sistem(""), do: []

  defp parse_pembangun_sistem(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_pembangun_sistem(_), do: []

  defp format_pembangun_sistem([]), do: nil

  defp format_pembangun_sistem(list) when is_list(list) do
    list
    |> Enum.filter(&(&1 != ""))
    |> Enum.join(", ")
  end

  defp parse_pengurus_projek(nil), do: []
  defp parse_pengurus_projek(""), do: []

  defp parse_pengurus_projek(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_pengurus_projek(_), do: []

  defp format_pengurus_projek([]), do: nil

  defp format_pengurus_projek(list) when is_list(list) do
    list
    |> Enum.filter(&(&1 != ""))
    |> Enum.join(", ")
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
  def handle_event("open_settings_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_settings_modal, true)
     |> assign(:profile_menu_open, false)}
  end

  @impl true
  def handle_event("add_pembangun_sistem", %{"developer_id" => developer_id_str}, socket) do
    case {socket.assigns.current_scope.user.role, socket.assigns.can_assign_devs} do
      {"pengurus projek", true} ->
        do_add_pembangun_sistem(developer_id_str, socket)

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Hanya pengurus projek yang terlibat boleh menetapkan pembangun sistem."
         )}
    end
  end

  @impl true
  def handle_event("add_pengurus_projek", %{"project_manager_id" => pm_id_str}, socket) do
    unless socket.assigns.current_scope.user.role == "ketua unit" do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Hanya ketua unit boleh menetapkan pembangun sistem dan pengurus projek."
       )}
    else
      do_add_pengurus_projek(pm_id_str, socket)
    end
  end

  @impl true
  def handle_event("remove_pengurus_projek", %{"no_kp" => no_kp}, socket) do
    unless socket.assigns.current_scope.user.role == "ketua unit" do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Hanya ketua unit boleh menetapkan pembangun sistem dan pengurus projek."
       )}
    else
      do_remove_pengurus_projek(no_kp, socket)
    end
  end

  @impl true
  def handle_event("remove_pembangun_sistem", %{"no_kp" => no_kp}, socket) do
    case {socket.assigns.current_scope.user.role, socket.assigns.can_assign_devs} do
      {"pengurus projek", true} ->
        do_remove_pembangun_sistem(no_kp, socket)

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Hanya pengurus projek yang terlibat boleh menetapkan pembangun sistem."
         )}
    end
  end

  @impl true
  def handle_event("update_tarikh_jangkaan_siap", %{"tarikh_jangkaan_siap" => date_str}, socket) do
    # Only allow update if project has been registered (daftar projek)
    if socket.assigns.approved_project.project do
      date_value =
        if date_str == "" or date_str == nil do
          nil
        else
          case Date.from_iso8601(date_str) do
            {:ok, date} -> date
            {:error, _} -> nil
          end
        end

      case ApprovedProjects.update_approved_project(socket.assigns.approved_project, %{
             "tarikh_jangkaan_siap" => date_value
           }) do
        {:ok, updated_project} ->
          {:noreply,
           socket
           |> assign(:approved_project, updated_project)
           |> put_flash(:info, "Tarikh jangkaan siap telah dikemaskini.")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Gagal mengemaskini tarikh jangkaan siap.")}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "Sila daftar projek terlebih dahulu sebelum menetapkan tarikh jangkaan siap."
       )}
    end
  end

  defp do_add_pembangun_sistem(developer_id_str, socket) do
    case Integer.parse(developer_id_str) do
      {developer_id, _} ->
        # Find the developer
        developer = Enum.find(socket.assigns.developers, fn dev -> dev.id == developer_id end)

        if developer && developer.no_kp not in socket.assigns.selected_developers do
          # Add to selected list
          new_selected = socket.assigns.selected_developers ++ [developer.no_kp]

          # Format as comma-separated string
          pembangun_sistem_str = format_pembangun_sistem(new_selected)

          # Update the approved project
          case ApprovedProjects.update_approved_project(socket.assigns.approved_project, %{
                 "pembangun_sistem" => pembangun_sistem_str
               }) do
            {:ok, updated_project} ->
              # Ensure there's an internal project linked to this approved project
              # This is necessary for the project to appear in pembangun sistem's project list
              # Reload the approved_project to ensure we have the latest data from database
              reloaded_approved_project =
                ApprovedProjects.get_approved_project!(updated_project.id)
                |> Sppa.Repo.preload([project: [:project_manager, :approved_project]])

              # Create or get the internal project - this ensures the project exists and is linked
              project_for_log =
                case Projects.ensure_internal_project_for_approved(reloaded_approved_project) do
                  {:ok, project} ->
                    project

                  {:error, changeset} ->
                    require Logger
                    Logger.error("Failed to ensure internal project: #{inspect(changeset.errors)}")
                    nil
                end

              # Log activity so pembangun sistem receives notification when appointed
              if developer do
                display_name =
                  developer.name || developer.email || developer.no_kp || "Pembangun sistem"

                if project_for_log do
                  ActivityLogs.log_activity(%{
                    actor_id: socket.assigns.current_scope.user.id,
                    action: "pembangun_sistem_dilantik",
                    resource_type: "project",
                    resource_id: project_for_log.id,
                    resource_name: project_for_log.nama,
                    details:
                      "Anda telah dilantik sebagai pembangun sistem bagi projek ini (#{display_name}).",
                    target_user_id: developer.id
                  })
                else
                  ActivityLogs.log_activity(%{
                    actor_id: socket.assigns.current_scope.user.id,
                    action: "pembangun_sistem_dilantik",
                    resource_type: "approved_project",
                    resource_id: reloaded_approved_project.id,
                    resource_name: reloaded_approved_project.nama_projek || "Projek",
                    details:
                      "Anda telah dilantik sebagai pembangun sistem bagi projek ini (#{display_name}).",
                    target_user_id: developer.id
                  })
                end
              end

              # Update available developers (exclude selected ones)
              available_developers =
                socket.assigns.developers
                |> Enum.filter(fn dev -> dev.no_kp not in new_selected end)

              {:noreply,
               socket
               |> assign(:approved_project, reloaded_approved_project)
               |> assign(:selected_developers, new_selected)
               |> assign(:available_developers, available_developers)
               |> put_flash(:info, "Pembangun sistem telah ditambah.")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Gagal menambah pembangun sistem.")}
          end
        else
          {:noreply, socket}
        end

      :error ->
        {:noreply, socket}
    end
  end

  defp do_add_pengurus_projek(pm_id_str, socket) do
    case Integer.parse(pm_id_str) do
      {pm_id, _} ->
        # Find the project manager
        project_manager = Enum.find(socket.assigns.project_managers, fn pm -> pm.id == pm_id end)

        if project_manager &&
             project_manager.no_kp not in socket.assigns.selected_project_managers do
          pm_display_name =
            project_manager.name || project_manager.email || project_manager.no_kp || "Unknown"

          # Add to selected pengurus projek list
          new_selected_pms = socket.assigns.selected_project_managers ++ [project_manager.no_kp]

          pengurus_projek_str = format_pengurus_projek(new_selected_pms)

          # Update the approved project
          case ApprovedProjects.update_approved_project(socket.assigns.approved_project, %{
                 "pengurus_projek" => pengurus_projek_str
               }) do
            {:ok, updated_project} ->
              # Ensure there's an internal project linked to this approved project
              # This is necessary for the project to appear in project lists
              # Reload the approved_project to ensure we have the latest data
              reloaded_approved_project =
                ApprovedProjects.get_approved_project!(updated_project.id)
                |> Sppa.Repo.preload([project: [:project_manager, :approved_project]])

              project_for_log =
                case Projects.ensure_internal_project_for_approved(reloaded_approved_project) do
                  {:ok, project} ->
                    project

                  {:error, changeset} ->
                    require Logger
                    Logger.error(
                      "Failed to ensure internal project: #{inspect(changeset.errors)}"
                    )

                    nil
                end

              # Update available project managers (exclude selected ones)
              available_project_managers =
                socket.assigns.project_managers
                |> Enum.filter(fn pm -> pm.no_kp not in new_selected_pms end)

              # Log activity so pengurus projek receives notification (dashboard PP)
              if project_for_log do
                ActivityLogs.log_activity(%{
                  actor_id: socket.assigns.current_scope.user.id,
                  action: "pengurus_projek_dilantik",
                  resource_type: "project",
                  resource_id: project_for_log.id,
                  resource_name: project_for_log.nama,
                  details: "Ketua unit telah menugaskan projek ini kepada anda.",
                  target_user_id: project_manager.id
                })

                # Separate log entry for ketua unit dashboard (no target_user; includes pengurus name)
                ActivityLogs.log_activity(%{
                  actor_id: socket.assigns.current_scope.user.id,
                  action: "pengurus_projek_dilantik",
                  resource_type: "project",
                  resource_id: project_for_log.id,
                  resource_name: project_for_log.nama,
                  details: "Pengurus projek: #{pm_display_name}"
                })
              else
                ActivityLogs.log_activity(%{
                  actor_id: socket.assigns.current_scope.user.id,
                  action: "pengurus_projek_dilantik",
                  resource_type: "approved_project",
                  resource_id: reloaded_approved_project.id,
                  resource_name: reloaded_approved_project.nama_projek || "Projek",
                  details: "Ketua unit telah menugaskan projek ini kepada anda.",
                  target_user_id: project_manager.id
                })

                ActivityLogs.log_activity(%{
                  actor_id: socket.assigns.current_scope.user.id,
                  action: "pengurus_projek_dilantik",
                  resource_type: "approved_project",
                  resource_id: reloaded_approved_project.id,
                  resource_name: reloaded_approved_project.nama_projek || "Projek",
                  details: "Pengurus projek: #{pm_display_name}"
                })
              end

              {:noreply,
               socket
               |> assign(:approved_project, updated_project)
               |> assign(:selected_project_managers, new_selected_pms)
               |> assign(:available_project_managers, available_project_managers)
               |> put_flash(:info, "Pengurus projek telah ditambah.")}

            {:error, _changeset} ->
              {:noreply, put_flash(socket, :error, "Gagal menambah pengurus projek.")}
          end
        else
          {:noreply, socket}
        end

      :error ->
        {:noreply, socket}
    end
  end

  defp do_remove_pengurus_projek(no_kp, socket) do
    # Remove from selected pengurus projek list
    new_selected_pms = List.delete(socket.assigns.selected_project_managers, no_kp)

    # Also remove from pembangun_sistem so that removing pengurus projek
    # revokes their automatic developer-style access for this system.
    new_selected_devs = List.delete(socket.assigns.selected_developers, no_kp)

    pengurus_projek_str =
      if new_selected_pms == [], do: nil, else: format_pengurus_projek(new_selected_pms)

    pembangun_sistem_str =
      if new_selected_devs == [], do: nil, else: format_pembangun_sistem(new_selected_devs)

    case ApprovedProjects.update_approved_project(socket.assigns.approved_project, %{
           "pengurus_projek" => pengurus_projek_str,
           "pembangun_sistem" => pembangun_sistem_str
         }) do
      {:ok, updated_project} ->
        # Log activity for dashboard "Aktiviti Terkini Unit" (ketua unit)
        removed_user = Accounts.get_user_by_no_kp(no_kp)
        pm_display_name =
          if removed_user do
            removed_user.name || removed_user.email || removed_user.no_kp || no_kp
          else
            no_kp
          end

        ap_with_project =
          ApprovedProjects.get_approved_project!(updated_project.id)
          |> Sppa.Repo.preload(:project)

        if ap_with_project.project do
          ActivityLogs.log_activity(%{
            actor_id: socket.assigns.current_scope.user.id,
            action: "pengurus_projek_dikeluarkan",
            resource_type: "project",
            resource_id: ap_with_project.project.id,
            resource_name: ap_with_project.project.nama,
            details: "Pengurus projek dikeluarkan: #{pm_display_name}"
          })
        else
          ActivityLogs.log_activity(%{
            actor_id: socket.assigns.current_scope.user.id,
            action: "pengurus_projek_dikeluarkan",
            resource_type: "approved_project",
            resource_id: ap_with_project.id,
            resource_name: ap_with_project.nama_projek,
            details: "Pengurus projek dikeluarkan: #{pm_display_name}"
          })
        end

        # Update available project managers
        available_project_managers =
          socket.assigns.project_managers
          |> Enum.filter(fn pm -> pm.no_kp not in new_selected_pms end)

        # Update available developers (exclude selected ones)
        available_developers =
          socket.assigns.developers
          |> Enum.filter(fn dev -> dev.no_kp not in new_selected_devs end)

        {:noreply,
         socket
         |> assign(:approved_project, updated_project)
         |> assign(:selected_project_managers, new_selected_pms)
         |> assign(:available_project_managers, available_project_managers)
         |> assign(:selected_developers, new_selected_devs)
         |> assign(:available_developers, available_developers)
         |> put_flash(:info, "Pengurus projek telah dikeluarkan.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Gagal mengeluarkan pengurus projek.")}
    end
  end

  defp do_remove_pembangun_sistem(no_kp, socket) do
    # Remove from selected list
    new_selected = List.delete(socket.assigns.selected_developers, no_kp)

    # Format as comma-separated string (or nil if empty)
    pembangun_sistem_str =
      if new_selected == [], do: nil, else: format_pembangun_sistem(new_selected)

    # Update the approved project
    case ApprovedProjects.update_approved_project(socket.assigns.approved_project, %{
           "pembangun_sistem" => pembangun_sistem_str
         }) do
      {:ok, updated_project} ->
        # Update available developers (exclude selected ones)
        available_developers =
          socket.assigns.developers
          |> Enum.filter(fn dev -> dev.no_kp not in new_selected end)

        {:noreply,
         socket
         |> assign(:approved_project, updated_project)
         |> assign(:selected_developers, new_selected)
         |> assign(:available_developers, available_developers)
         |> put_flash(:info, "Pembangun sistem telah dikeluarkan.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Gagal mengeluarkan pembangun sistem.")}
    end
  end

  # Note: update_tarikh_mula handler removed - tarikh_mula is read-only and comes from external link

  @impl true
  def handle_info(:close_settings_modal, socket) do
    {:noreply, assign(socket, :show_settings_modal, false)}
  end

  @impl true
  def render(%{approved_project: nil} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <%= if @show_settings_modal do %>
        <.live_component
          module={SppaWeb.Components.SettingsModalLive}
          id="settings-modal"
          current_scope={@current_scope}
        />
      <% end %>

      <div class="fixed inset-0 flex h-screen bg-gradient-to-br from-gray-50 to-gray-100 z-50">
        <%!-- Overlay --%>
        <div
          class={[
            "fixed inset-0 bg-blue-900/60 z-40 transition-opacity duration-300",
            if(@sidebar_open, do: "opacity-100", else: "opacity-0 pointer-events-none")
          ]}
          phx-click="close_sidebar"
        >
        </div>
         <%!-- Sidebar --%>
        <.dashboard_sidebar
          sidebar_open={@sidebar_open}
          dashboard_path={@sidebar_dashboard_path}
          logo_src={~p"/images/logojpkn.png"}
          current_scope={@current_scope}
          current_path={@sidebar_list_path}
        /> <%!-- Main Content --%>
        <div class="flex-1 flex flex-col overflow-hidden">
          <%!-- Header --%>
          <header class="bg-gradient-to-r from-blue-600 to-blue-700 border-b border-blue-700 px-6 py-4 flex items-center justify-between shadow-md relative">
            <.system_title />
            <div class="flex items-center gap-4">
              <button
                phx-click="toggle_sidebar"
                class="text-white hover:text-blue-100 hover:bg-blue-500/40 p-2 rounded-lg transition-all duration-200"
              >
                <.icon name="hero-bars-3" class="w-6 h-6" />
              </button> <.header_logos height_class="h-12 sm:h-14 md:h-16" />
            </div>

            <.header_actions
              notifications_open={@notifications_open}
              notifications_count={@notifications_count}
              activities={@activities}
              profile_menu_open={@profile_menu_open}
              current_scope={@current_scope}
            />
          </header>
           <%!-- Content --%>
          <main class="flex-1 flex items-center justify-center bg-gradient-to-br from-gray-50 to-white p-6 md:p-8">
            <div class="text-center text-gray-600 space-y-2">
              <p class="text-base font-medium">Memuatkan maklumat projek yang diluluskan...</p>

              <p class="text-xs text-gray-400">Sila tunggu sebentar.</p>
            </div>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <%= if @show_settings_modal do %>
        <.live_component
          module={SppaWeb.Components.SettingsModalLive}
          id="settings-modal"
          current_scope={@current_scope}
        />
      <% end %>

      <div class="fixed inset-0 flex h-screen bg-gradient-to-br from-gray-50 to-gray-100 z-50">
        <%!-- Overlay --%>
        <div
          class={[
            "fixed inset-0 bg-blue-900/60 z-40 transition-opacity duration-300",
            if(@sidebar_open, do: "opacity-100", else: "opacity-0 pointer-events-none")
          ]}
          phx-click="close_sidebar"
        >
        </div>
         <%!-- Sidebar --%>
        <.dashboard_sidebar
          sidebar_open={@sidebar_open}
          dashboard_path={@sidebar_dashboard_path}
          logo_src={~p"/images/logojpkn.png"}
          current_scope={@current_scope}
          current_path={@sidebar_list_path}
        /> <%!-- Main Content --%>
        <div class="flex-1 flex flex-col overflow-hidden">
          <%!-- Header --%>
          <header class="bg-gradient-to-r from-blue-600 to-blue-700 border-b border-blue-700 px-6 py-4 flex items-center justify-between shadow-md relative">
            <.system_title />
            <div class="flex items-center gap-4">
              <button
                phx-click="toggle_sidebar"
                class="text-white hover:text-blue-100 hover:bg-blue-500/40 p-2 rounded-lg transition-all duration-200"
              >
                <.icon name="hero-bars-3" class="w-6 h-6" />
              </button> <.header_logos height_class="h-12 sm:h-14 md:h-16" />
            </div>

            <.header_actions
              notifications_open={@notifications_open}
              notifications_count={@notifications_count}
              activities={@activities}
              profile_menu_open={@profile_menu_open}
              current_scope={@current_scope}
            />
          </header>
           <%!-- Content --%>
          <main class="flex-1 overflow-y-auto bg-gradient-to-br from-gray-50 via-gray-50 to-gray-100 p-6 md:p-8 lg:p-10">
            <div class="max-w-6xl mx-auto space-y-8">
              <%!-- Page Header --%>
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div class="space-y-1">
                  <h1 class="text-3xl md:text-4xl font-bold text-gray-900 tracking-tight">
                    Butiran Projek Diluluskan
                  </h1>

                  <p class="text-base text-gray-600">
                    Maklumat penuh permohonan projek yang telah diluluskan
                  </p>
                </div>

                <div class="flex items-center gap-3">
                  <%= if @approved_project.project do %>
                    <.link
                      navigate={~p"/projek/#{@approved_project.project.id}/modul"}
                      class="inline-flex items-center gap-2 rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-blue-700 transition-all duration-200"
                    >
                      <.icon name="hero-cog-6-tooth" class="w-4 h-4" /> <span>Modul Projek</span>
                    </.link>
                  <% end %>

                  <.link
                    navigate={@back_list_path}
                    class="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm font-semibold text-gray-700 shadow-sm hover:bg-gray-50 hover:border-gray-400 transition-all duration-200"
                  >
                    <.icon name="hero-arrow-left" class="w-4 h-4" /> <span>Kembali ke Senarai</span>
                  </.link>
                </div>
              </div>
               <%!-- Main Project Card --%>
              <div class="bg-white rounded-2xl shadow-lg border border-gray-200/80 overflow-hidden">
                <div class="bg-gradient-to-r from-blue-50 to-indigo-50 border-b border-gray-200 px-6 md:px-8 py-5">
                  <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
                    <div class="space-y-2 flex-1">
                      <div class="flex items-center gap-2">
                        <span class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-green-100 text-green-800 text-xs font-bold uppercase tracking-wide">
                          <.icon name="hero-check-circle" class="w-4 h-4" /> Diluluskan
                        </span>
                        <span class="text-xs font-medium text-gray-500 uppercase tracking-wide">
                          Projek Diluluskan
                        </span>
                      </div>

                      <h2 class="text-2xl md:text-3xl font-bold text-gray-900 leading-tight">
                        {@approved_project.nama_projek}
                      </h2>

                      <p class="text-base text-gray-600 font-medium">
                        {@approved_project.jabatan || "Tiada maklumat jabatan"}
                      </p>
                    </div>

                    <div class="flex flex-col items-start md:items-end gap-3 md:pl-6 md:border-l md:border-gray-300">
                      <div class="space-y-1.5 text-sm">
                        <div class="flex items-center gap-2 text-gray-600">
                          <.icon name="hero-calendar" class="w-4 h-4 text-gray-400" />
                          <span class="font-medium">Tarikh Permohonan:</span>
                          <span class="text-gray-900">
                            {format_date(@approved_project.tarikh_mula)}
                          </span>
                        </div>

                        <div class="flex items-center gap-2 text-gray-600">
                          <.icon name="hero-clock" class="w-4 h-4 text-gray-400" />
                          <span class="font-medium">Tarikh Jangkaan Siap:</span>
                          <span class="text-gray-900">
                            {format_date(@approved_project.tarikh_jangkaan_siap)}
                          </span>
                        </div>

                        <div class="flex items-center gap-2 text-gray-600 pt-1">
                          <span class="font-medium">Status:</span>
                          <% status_label = status_display_approved_project(@approved_project) %>
                          <span class={[
                            "inline-flex px-2 py-0.5 rounded-full text-xs font-medium",
                            if(status_label == "Selesai",
                              do: "bg-green-100 text-green-800",
                              else:
                                if(status_label == "Belum Lantik Pengurus",
                                  do: "bg-gray-100 text-gray-700",
                                  else: "bg-amber-100 text-amber-800"
                                )
                            )
                          ]}>
                            {status_label}
                          </span>
                        </div>

                        <div class="flex items-center gap-2 text-gray-600">
                          <span class="font-medium">Pengurus Projek:</span>
                          <% pengurus = if @approved_project.project, do: Projects.project_pengurus_projek_display(@approved_project.project), else: Projects.approved_project_pengurus_display(@approved_project) %>
                          <%= if pengurus && pengurus != "" && pengurus != "-" do %>
                            <span class="text-gray-900">{pengurus}</span>
                          <% else %>
                            <span class="text-gray-400 italic">Belum dilantik</span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
               <%!-- Information Cards Grid --%>
              <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <%!-- Maklumat Pemohon --%>
                <section class="bg-white rounded-xl shadow-md border border-gray-200 overflow-hidden">
                  <div class="bg-gradient-to-r from-blue-50 to-blue-100 px-6 py-4 border-b border-gray-200">
                    <h2 class="text-lg font-bold text-gray-900 flex items-center gap-2.5">
                      <span class="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-blue-600 text-white shadow-sm">
                        <.icon name="hero-user" class="w-5 h-5" />
                      </span>
                      Maklumat Pemohon
                    </h2>
                  </div>

                  <div class="p-6">
                    <dl class="space-y-4">
                      <div class="pb-4 border-b border-gray-100 last:border-0 last:pb-0">
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">
                          Emel
                        </dt>

                        <dd class="text-base text-gray-900 break-all">
                          <%= if @approved_project.pengurus_email do %>
                            {@approved_project.pengurus_email}
                          <% else %>
                            <span class="text-gray-400 italic">Tiada maklumat</span>
                          <% end %>
                        </dd>
                      </div>

                      <div>
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">
                          Kementerian / Jabatan
                        </dt>

                        <dd class="text-base text-gray-900">
                          <%= if @approved_project.jabatan do %>
                            {@approved_project.jabatan}
                          <% else %>
                            <span class="text-gray-400 italic">Tiada maklumat</span>
                          <% end %>
                        </dd>
                      </div>
                    </dl>
                  </div>
                </section>
                 <%!-- Maklumat Sistem --%>
                <section class="bg-white rounded-xl shadow-md border border-gray-200 overflow-hidden">
                  <div class="bg-gradient-to-r from-indigo-50 to-purple-50 px-6 py-4 border-b border-gray-200">
                    <h2 class="text-lg font-bold text-gray-900 flex items-center gap-2.5">
                      <span class="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-indigo-600 text-white shadow-sm">
                        <.icon name="hero-computer-desktop" class="w-5 h-5" />
                      </span>
                      Maklumat Sistem
                    </h2>
                  </div>

                  <div class="p-6">
                    <dl class="space-y-4">
                      <div class="pb-4 border-b border-gray-100 last:border-0 last:pb-0">
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-1.5">
                          Nama Sistem
                        </dt>

                        <dd class="text-base font-semibold text-gray-900">
                          {@approved_project.nama_projek}
                        </dd>
                      </div>

                      <div class="pb-4 border-b border-gray-100 last:border-0 last:pb-0">
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                          Pembangun Sistem
                        </dt>

                        <dd>
                          <div class="space-y-3">
                            <%= if @can_assign_devs do %>
                              <%!-- Ketua unit only: Dropdown to add pembangun sistem --%>
                              <%= if @available_developers != [] do %>
                                <.form
                                  for={%{}}
                                  phx-submit="add_pembangun_sistem"
                                  id="add-pembangun-form"
                                  class="space-y-2"
                                >
                                  <select
                                    name="developer_id"
                                    class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 shadow-sm outline-none transition focus:border-indigo-400 focus:ring-2 focus:ring-indigo-200"
                                    required
                                  >
                                    <option value="">Pilih Pembangun</option>

                                    <%= for developer <- @available_developers do %>
                                      <option value={developer.id}>
                                        {developer.name || developer.email || developer.no_kp ||
                                          "Unknown"}
                                      </option>
                                    <% end %>
                                  </select>
                                  <button
                                    type="submit"
                                    class="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700 transition-all duration-200"
                                  >
                                    <.icon name="hero-plus" class="w-4 h-4" /> <span>Tambah</span>
                                  </button>
                                </.form>
                              <% else %>
                                <p class="text-sm text-gray-500 italic">
                                  Semua pembangun sistem telah dipilih
                                </p>
                              <% end %>
                            <% end %>

                            <%!-- Display selected pembangun sistem (with remove button only for ketua unit) --%>
                            <%= if @selected_developers != [] do %>
                              <div class="mt-4 space-y-2">
                                <p class="text-xs font-semibold text-gray-700 uppercase tracking-wide">
                                  Pembangun Dipilih:
                                </p>

                                <div class="flex flex-wrap gap-2">
                                  <%= for no_kp <- @selected_developers do %>
                                    <% developer =
                                      Enum.find(@developers, fn dev -> dev.no_kp == no_kp end) %> <% display_name =
                                      cond do
                                        developer && developer.name && developer.name != "" ->
                                          developer.name

                                        developer && developer.email && developer.email != "" ->
                                          developer.email

                                        developer ->
                                          developer.no_kp || "Unknown"

                                        true ->
                                          # Fallback: try to find by no_kp from all users if not in developers list
                                          all_users = Accounts.list_users()

                                          found_user =
                                            Enum.find(all_users, fn u -> u.no_kp == no_kp end)

                                          if found_user do
                                            found_user.name || found_user.email || found_user.no_kp ||
                                              "Unknown"
                                          else
                                            no_kp
                                          end
                                      end %>
                                    <div class="inline-flex items-center gap-2 rounded-full bg-indigo-100 px-3 py-1.5 text-sm text-indigo-800">
                                      <span>{display_name}</span>
                                      <%= if @can_assign_devs do %>
                                        <button
                                          type="button"
                                          phx-click="remove_pembangun_sistem"
                                          phx-value-no_kp={no_kp}
                                          class="ml-1 rounded-full p-0.5 hover:bg-indigo-200 transition-colors"
                                          title="Keluarkan"
                                        >
                                          <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                                        </button>
                                      <% end %>
                                    </div>
                                  <% end %>
                                </div>
                              </div>
                            <% else %>
                              <p class="text-sm text-gray-400 italic mt-2">
                                Tiada pembangun sistem dipilih
                              </p>
                            <% end %>
                          </div>
                        </dd>
                      </div>

                      <div class="pb-4 border-b border-gray-100 last:border-0 last:pb-0">
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                          Pengurus Projek
                        </dt>

                        <dd>
                          <div class="space-y-3">
                            <%= if @can_assign_pm do %>
                              <%!-- Ketua unit only: Dropdown to add pengurus projek --%>
                              <%= if @available_project_managers != [] do %>
                                <.form
                                  for={%{}}
                                  phx-submit="add_pengurus_projek"
                                  id="add-pengurus-form"
                                  class="space-y-2"
                                >
                                  <select
                                    name="project_manager_id"
                                    class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 shadow-sm outline-none transition focus:border-indigo-400 focus:ring-2 focus:ring-indigo-200"
                                    required
                                  >
                                    <option value="">Pilih Pengurus Projek</option>

                                    <%= for project_manager <- @available_project_managers do %>
                                      <option value={project_manager.id}>
                                        {project_manager.name || project_manager.email ||
                                          project_manager.no_kp || "Unknown"}
                                      </option>
                                    <% end %>
                                  </select>
                                  <button
                                    type="submit"
                                    class="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-700 transition-all duration-200"
                                  >
                                    <.icon name="hero-plus" class="w-4 h-4" /> <span>Tambah</span>
                                  </button>
                                </.form>
                              <% else %>
                                <p class="text-sm text-gray-500 italic">
                                  Semua pengurus projek telah dipilih
                                </p>
                              <% end %>
                            <% end %>

                            <%!-- Display selected pengurus projek (with remove button only for ketua unit) --%>
                            <%= if @selected_project_managers != [] do %>
                              <div class="mt-4 space-y-2">
                                <p class="text-xs font-semibold text-gray-700 uppercase tracking-wide">
                                  Pengurus Projek Dipilih:
                                </p>

                                <div class="flex flex-wrap gap-2">
                                  <%= for no_kp <- @selected_project_managers do %>
                                    <% project_manager =
                                      Enum.find(@project_managers, fn pm -> pm.no_kp == no_kp end) %> <% display_name =
                                      cond do
                                        project_manager && project_manager.name &&
                                            project_manager.name != "" ->
                                          project_manager.name

                                        project_manager && project_manager.email &&
                                            project_manager.email != "" ->
                                          project_manager.email

                                        project_manager ->
                                          project_manager.no_kp || "Unknown"

                                        true ->
                                          # Fallback: try to find by no_kp from all users if not in project_managers list
                                          all_users = Accounts.list_users()

                                          found_user =
                                            Enum.find(all_users, fn u -> u.no_kp == no_kp end)

                                          if found_user do
                                            found_user.name || found_user.email || found_user.no_kp ||
                                              "Unknown"
                                          else
                                            no_kp
                                          end
                                      end %>
                                    <div class="inline-flex items-center gap-2 rounded-full bg-purple-100 px-3 py-1.5 text-sm text-purple-800">
                                      <span>{display_name}</span>
                                      <%= if @can_assign_pm do %>
                                        <button
                                          type="button"
                                          phx-click="remove_pengurus_projek"
                                          phx-value-no_kp={no_kp}
                                          class="ml-1 rounded-full p-0.5 hover:bg-purple-200 transition-colors"
                                          title="Keluarkan"
                                        >
                                          <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                                        </button>
                                      <% end %>
                                    </div>
                                  <% end %>
                                </div>
                              </div>
                            <% else %>
                              <p class="text-sm text-gray-400 italic mt-2">
                                Tiada pengurus projek dipilih
                              </p>
                            <% end %>
                          </div>
                        </dd>
                      </div>

                      <div class="pb-4 border-b border-gray-100 last:border-0 last:pb-0">
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                          Tarikh Mula
                        </dt>

                        <dd>
                          <div class="w-full rounded-lg border border-gray-300 bg-gray-50 px-3 py-2 text-sm text-gray-700">
                            <%= if @approved_project.tarikh_mula do %>
                              {format_date(@approved_project.tarikh_mula)}
                            <% else %>
                              <span class="text-gray-400 italic">Tiada tarikh mula</span>
                            <% end %>
                          </div>

                          <p class="mt-1 text-xs text-gray-500 italic">
                            Tarikh mula ditetapkan dari sistem luaran dan tidak boleh diubah
                          </p>
                        </dd>
                      </div>

                      <div>
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                          Tarikh Jangkaan Siap
                        </dt>

                        <dd>
                          <%= if @approved_project.project do %>
                            <%!-- Editable if project has been registered --%>
                            <.form
                              for={%{}}
                              phx-change="update_tarikh_jangkaan_siap"
                              id="tarikh-jangkaan-siap-form"
                            >
                              <input
                                type="date"
                                name="tarikh_jangkaan_siap"
                                value={
                                  if @approved_project.tarikh_jangkaan_siap,
                                    do: Date.to_iso8601(@approved_project.tarikh_jangkaan_siap),
                                    else: ""
                                }
                                class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 shadow-sm outline-none transition focus:border-indigo-400 focus:ring-2 focus:ring-indigo-200"
                              />
                            </.form>
                          <% else %>
                            <%!-- Read-only if project has not been registered --%>
                            <div class="w-full rounded-lg border border-gray-300 bg-gray-50 px-3 py-2 text-sm text-gray-700">
                              <%= if @approved_project.tarikh_jangkaan_siap do %>
                                {format_date(@approved_project.tarikh_jangkaan_siap)}
                              <% else %>
                                <span class="text-gray-400 italic">Tiada tarikh jangkaan siap</span>
                              <% end %>
                            </div>

                            <p class="mt-1 text-xs text-gray-500 italic">
                              Sila daftar projek terlebih dahulu untuk menetapkan tarikh jangkaan siap
                            </p>
                          <% end %>
                        </dd>
                      </div>
                    </dl>
                  </div>
                </section>
              </div>
               <%!-- Maklumat Terperinci --%>
              <section class="bg-white rounded-xl shadow-md border border-gray-200 overflow-hidden">
                <div class="bg-gradient-to-r from-gray-50 to-gray-100 px-6 py-4 border-b border-gray-200">
                  <h2 class="text-lg font-bold text-gray-900 flex items-center gap-2.5">
                    <span class="inline-flex h-9 w-9 items-center justify-center rounded-lg bg-gray-700 text-white shadow-sm">
                      <.icon name="hero-document-text" class="w-5 h-5" />
                    </span>
                    Maklumat Terperinci
                  </h2>
                </div>

                <div class="p-6 md:p-8">
                  <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
                    <div class="space-y-6">
                      <div>
                        <h3 class="text-sm font-bold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                          <.icon name="hero-information-circle" class="w-4 h-4 text-blue-600" />
                          Latar Belakang Sistem
                        </h3>

                        <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                          <p class="text-sm leading-relaxed text-gray-700 whitespace-pre-line">
                            <%= if @approved_project.latar_belakang do %>
                              {@approved_project.latar_belakang}
                            <% else %>
                              <span class="text-gray-400 italic">Tiada maklumat</span>
                            <% end %>
                          </p>
                        </div>
                      </div>

                      <div>
                        <h3 class="text-sm font-bold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                          <.icon name="hero-flag" class="w-4 h-4 text-green-600" /> Objektif Sistem
                        </h3>

                        <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                          <p class="text-sm leading-relaxed text-gray-700 whitespace-pre-line">
                            <%= if @approved_project.objektif do %>
                              {@approved_project.objektif}
                            <% else %>
                              <span class="text-gray-400 italic">Tiada maklumat</span>
                            <% end %>
                          </p>
                        </div>
                      </div>

                      <div>
                        <h3 class="text-sm font-bold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                          <.icon name="hero-globe-alt" class="w-4 h-4 text-purple-600" /> Skop Sistem
                        </h3>

                        <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                          <p class="text-sm leading-relaxed text-gray-700 whitespace-pre-line">
                            <%= if @approved_project.skop do %>
                              {@approved_project.skop}
                            <% else %>
                              <span class="text-gray-400 italic">Tiada maklumat</span>
                            <% end %>
                          </p>
                        </div>
                      </div>
                    </div>

                    <div class="space-y-6">
                      <div>
                        <h3 class="text-sm font-bold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                          <.icon name="hero-user-group" class="w-4 h-4 text-orange-600" />
                          Kumpulan Pengguna
                        </h3>

                        <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                          <p class="text-sm leading-relaxed text-gray-700 whitespace-pre-line">
                            <%= if @approved_project.kumpulan_pengguna do %>
                              {@approved_project.kumpulan_pengguna}
                            <% else %>
                              <span class="text-gray-400 italic">Tiada maklumat</span>
                            <% end %>
                          </p>
                        </div>
                      </div>

                      <div>
                        <h3 class="text-sm font-bold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                          <.icon name="hero-exclamation-triangle" class="w-4 h-4 text-amber-600" />
                          Implikasi
                        </h3>

                        <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                          <p class="text-sm leading-relaxed text-gray-700 whitespace-pre-line">
                            <%= if @approved_project.implikasi do %>
                              {@approved_project.implikasi}
                            <% else %>
                              <span class="text-gray-400 italic">Tiada maklumat</span>
                            <% end %>
                          </p>
                        </div>
                      </div>

                      <div>
                        <h3 class="text-sm font-bold text-gray-700 uppercase tracking-wide mb-3 flex items-center gap-2">
                          <.icon name="hero-document-arrow-down" class="w-4 h-4 text-red-600" />
                          Dokumen Kertas Kerja
                        </h3>

                        <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                          <%= if @approved_project.kertas_kerja_path do %>
                            <% full_url = ensure_full_url(@approved_project.kertas_kerja_path) %>
                            <%= if full_url do %>
                              <div class="space-y-2">
                                <a
                                  href={full_url}
                                  class="inline-flex items-center gap-2 px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-lg shadow-sm hover:shadow-md transition-all duration-200"
                                  target="_blank"
                                  rel="noopener noreferrer"
                                >
                                  <.icon name="hero-document-arrow-down" class="w-4 h-4" />
                                  <span>Muat Turun Kertas Kerja</span>
                                </a>
                                <p class="text-xs text-gray-500 break-all">
                                  <span class="font-medium">URL:</span> {full_url}
                                </p>
                              </div>
                            <% else %>
                              <p class="text-sm text-gray-400 italic">URL dokumen tidak sah</p>

                              <p class="text-xs text-gray-500 mt-1">
                                Nilai tersimpan: {@approved_project.kertas_kerja_path}
                              </p>
                            <% end %>
                          <% else %>
                            <p class="text-sm text-gray-400 italic">
                              Tiada dokumen kertas kerja tersedia
                            </p>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </section>
            </div>
          </main>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
