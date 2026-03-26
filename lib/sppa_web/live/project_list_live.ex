defmodule SppaWeb.ProjectListLive do
  use SppaWeb, :live_view

  alias Sppa.ActivityLogs
  alias Sppa.Projects
  alias Sppa.Accounts
  alias Sppa.ApprovedProjects
  alias Sppa.Repo
  import Ecto.Query
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Senarai Projek Diluluskan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:show_settings_modal, false)
        |> assign(:status_filter, "")
        |> assign(:phase_filter, "")
        |> assign(:search_query, "")
        |> assign(:page, 1)
        |> assign(:per_page, 10)
        |> assign(:show_modal, false)
        |> assign(:form, to_form(%{}, as: :project))

      # Muat aktiviti untuk notifikasi header – ikut logik Dashboard Pengurus Projek
      project_activities = Projects.list_recent_activities(socket.assigns.current_scope, 10)

      assignment_activities =
        ActivityLogs.list_recent_assignment_activities_for_pengurus_projek(
          socket.assigns.current_scope,
          10
        )

      notification_activities =
        merge_activities_for_notifications(project_activities, assignment_activities, 10)

      notifications_count = length(notification_activities)

      # Always load projects and users so the page is populated immediately,
      # even before the LiveView JS socket connects.
      projects = list_projects(socket)
      total_pages = calculate_total_pages(socket)
      users = Accounts.list_users()

      {:ok,
       socket
       |> assign(:projects, projects)
       |> assign(:total_pages, total_pages)
       |> assign(:users, users)
       |> assign(:activities, notification_activities)
       |> assign(:notifications_count, notifications_count)}
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
    {:noreply, Phoenix.Component.update(socket, :sidebar_open, &(!&1))}
  end

  @impl true
  def handle_event("close_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, false)}
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply, Phoenix.Component.update(socket, :notifications_open, &(!&1))}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
  end

  @impl true
  def handle_event("toggle_profile_menu", _params, socket) do
    {:noreply, Phoenix.Component.update(socket, :profile_menu_open, &(!&1))}
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
  def handle_event("filter", %{"status" => status, "search" => search}, socket) do
    socket =
      socket
      |> assign(:status_filter, status)
      |> assign(:search_query, search)
      |> assign(:page, 1)

    projects = list_projects(socket)
    total_pages = calculate_total_pages(socket)

    {:noreply,
     socket
     |> assign(:projects, projects)
     |> assign(:total_pages, total_pages)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    socket = assign(socket, :page, page)

    projects = list_projects(socket)

    {:noreply, assign(socket, :projects, projects)}
  end

  @impl true
  def handle_event("open_new_project_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  @impl true
  def handle_event("validate", %{"project" => _project_params}, socket) do
    # For now, just keep the form as is since we're not saving to database
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"project" => _project_params}, socket) do
    # For now, just close the modal since we're not saving to database
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> put_flash(:info, "Projek akan disimpan selepas penambahan medan pangkalan data")}
  end

  @impl true
  def handle_event("sync_external_data", _params, socket) do
    try do
      # Run sync immediately in this process so the user
      # sees updated data without relying on background workers.
      _ = Sppa.Workers.ExternalSyncWorker.perform(%{})

      projects = list_projects(socket)
      total_pages = calculate_total_pages(socket)

      {:noreply,
       socket
       |> assign(:projects, projects)
       |> assign(:total_pages, total_pages)
       |> put_flash(:info, "Sinkronisasi data telah selesai.")}
    rescue
      e ->
        Logger.error("Exception during sync: #{inspect(e)}")

        {:noreply,
         socket
         |> put_flash(:error, "Ralat: #{Exception.message(e)}. Pastikan Oban sedang berjalan.")}
    end
  end

  @impl true
  def handle_event("create_project", %{"id" => approved_project_id}, socket) do
    approved_project_id = String.to_integer(approved_project_id)

    case ApprovedProjects.get_approved_project!(approved_project_id) do
      approved_project ->
        # Create project from approved project data
        project_attrs = %{
          "nama" => approved_project.nama_projek || "",
          "jabatan" => approved_project.jabatan || "",
          "status" => "Dalam Pembangunan",
          "fasa" => "Analisis dan Rekabentuk",
          "tarikh_mula" => approved_project.tarikh_mula,
          "approved_project_id" => approved_project.id
        }

        case Projects.create_project(project_attrs, socket.assigns.current_scope) do
          {:ok, _project} ->
            # Reload projects
            projects = list_projects(socket)
            total_pages = calculate_total_pages(socket)

            {:noreply,
             socket
             |> assign(:projects, projects)
             |> assign(:total_pages, total_pages)
             |> put_flash(:info, "Projek berjaya didaftarkan")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Terdapat ralat semasa mendaftarkan projek")}
        end
    end
  end

  @impl true
  def handle_info(:close_settings_modal, socket) do
    {:noreply, assign(socket, :show_settings_modal, false)}
  end

  @impl true
  def handle_info(:reload_projects, socket) do
    projects = list_projects(socket)
    total_pages = calculate_total_pages(socket)

    {:noreply,
     socket
     |> assign(:projects, projects)
     |> assign(:total_pages, total_pages)
     |> put_flash(:info, "Data telah dikemaskini")}
  end

  defp list_projects(socket) do
    all_projects = list_all_approved_projects_for_current_pm(socket)

    start = (socket.assigns.page - 1) * socket.assigns.per_page
    Enum.slice(all_projects, start, socket.assigns.per_page)
  end

  defp calculate_total_pages(socket) do
    total = socket |> list_all_approved_projects_for_current_pm() |> length()
    ceil(total / socket.assigns.per_page)
  end

  # Sama seperti di Dashboard Pengurus Projek: gabungkan aktiviti projek
  # dan aktiviti penugasan untuk dropdown notifikasi.
  defp merge_activities_for_notifications(project_activities, assignment_activities, limit) do
    project_items =
      Enum.map(project_activities, fn p ->
        sort_at = p.last_updated || Map.get(p, :updated_at) || DateTime.utc_now()
        %{nama: p.nama, status: p.status, last_updated: p.last_updated, sort_at: sort_at}
      end)

    assignment_items =
      Enum.map(assignment_activities, fn a ->
        sort_at = a.inserted_at || DateTime.utc_now()

        %{
          resource_name: a.resource_name,
          action_label: a.action_label,
          details: a.details,
          inserted_at: a.inserted_at,
          sort_at: sort_at
        }
      end)

    (project_items ++ assignment_items)
    |> Enum.sort_by(& &1.sort_at, {:desc, DateTime})
    |> Enum.take(limit)
    |> Enum.map(&Map.delete(&1, :sort_at))
  end

  # Returns all approved projects visible to the current pengurus projek,
  # before pagination. Visibility is based on ketua unit assignments in
  # approved_project.pengurus_projek (by no_kp). If no assignments exist yet,
  # the project is hidden from the pengurus projek list.
  defp list_all_approved_projects_for_current_pm(socket) do
    current_scope = socket.assigns.current_scope
    user_role = current_scope.user.role
    user_no_kp = current_scope.user.no_kp

    base_query =
      from ap in Sppa.ApprovedProjects.ApprovedProject,
        left_join: p in assoc(ap, :project),
        preload: [project: p]

    # Apply search filter
    base_query =
      if socket.assigns.search_query != "" do
        search_term = "%#{socket.assigns.search_query}%"
        where(base_query, [ap, _p], ilike(ap.nama_projek, ^search_term))
      else
        base_query
      end

    # Apply status filter: "Pembangun belum di lantik" / "Dalam Pembangunan" by pembangun_sistem; "Selesai" by project status
    base_query =
      case socket.assigns.status_filter do
        "Pembangun belum di lantik" ->
          where(base_query, [ap, _p], is_nil(ap.pembangun_sistem) or ap.pembangun_sistem == "")

        "Dalam Pembangunan" ->
          where(
            base_query,
            [ap, _p],
            not is_nil(ap.pembangun_sistem) and ap.pembangun_sistem != ""
          )

        "Selesai" ->
          where(base_query, [_ap, p], p.status == "Selesai")

        _ ->
          base_query
      end

    approved_projects =
      base_query
      |> order_by([ap, _p], desc: ap.external_updated_at)
      |> Repo.all()

    approved_projects
    |> Enum.filter(fn approved_project ->
      case user_role do
        "pengurus projek" ->
          has_pm_assignment?(approved_project, user_no_kp)

        _other ->
          # In practice only pengurus projek should hit this LiveView, but keep
          # behaviour permissive for any future roles.
          true
      end
    end)
    |> Enum.map(&ensure_project_loaded/1)
  end

  # Ensure there is an internal project struct on the approved_project so the
  # Modul button can work for all systems. If no project exists yet, this will
  # create one using Projects.ensure_internal_project_for_approved/1.
  defp ensure_project_loaded(%Sppa.ApprovedProjects.ApprovedProject{} = approved_project) do
    project =
      case approved_project.project do
        %Sppa.Projects.Project{} = p ->
          p

        _ ->
          case Projects.ensure_internal_project_for_approved(approved_project) do
            {:ok, p} -> p
            _ -> nil
          end
      end

    Map.put(approved_project, :project, project)
  end

  # Status lajur: "Pembangun belum di lantik" jika tiada pembangun; "Dalam Pembangunan" jika pembangun sudah dilantik; "Selesai" jika projek selesai.
  def status_display(approved_project) do
    internal_status = approved_project.project && approved_project.project.status

    has_pembangun =
      approved_project.pembangun_sistem && String.trim(approved_project.pembangun_sistem) != ""

    cond do
      internal_status == "Selesai" -> "Selesai"
      has_pembangun -> "Dalam Pembangunan"
      true -> "Pembangun belum di lantik"
    end
  end

  defp has_pm_assignment?(approved_project, user_no_kp) when is_binary(user_no_kp) do
    pengurus = approved_project.pengurus_projek

    if is_binary(pengurus) and pengurus != "" do
      pengurus
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.any?(&(&1 == user_no_kp))
    else
      false
    end
  end

  @impl true
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
          dashboard_path={~p"/dashboard-pp"}
          logo_src={~p"/images/logojpkn.png"}
          current_scope={@current_scope}
          current_path="/senarai-projek-diluluskan"
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
              </button>
               <.header_logos height_class="h-12 sm:h-14 md:h-16" />
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
          <main class="flex-1 overflow-y-auto bg-gradient-to-br from-gray-50 to-white p-6 md:p-8 print:overflow-visible print:p-0 print:bg-white">
            <%!-- Projek List Content --%>
            <div class="max-w-7xl mx-auto print:max-w-none print:mx-0">
              <div class="mb-8 flex items-center justify-between print:mb-4">
                <div class="print:w-full">
                  <h1 class="text-3xl font-bold text-gray-900 mb-2 print:text-2xl print:mb-1 print:text-black">
                    Senarai Projek Diluluskan
                  </h1>

                  <p class="text-gray-600 print:text-gray-800 print:text-sm">
                    Senarai lengkap semua projek yang diluluskan
                  </p>
                </div>
                <%!-- Print Button --%>
                <div class="print:hidden">
                  <.link
                    href={~p"/senarai-projek-diluluskan/pdf"}
                    target="_blank"
                    class="inline-flex items-center gap-2 px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white font-medium rounded-lg transition-colors duration-200 shadow-md hover:shadow-lg"
                  >
                    <.icon name="hero-printer" class="w-5 h-5" /> <span>Cetak Dokumen</span>
                  </.link>
                </div>
              </div>
              <%!-- Filter section --%>
              <div class="rounded-xl bg-white p-6 shadow-sm print:hidden">
                <.form
                  for={%{}}
                  phx-change="filter"
                  id="filter-form"
                  class="flex flex-wrap items-end gap-4"
                >
                  <%!-- Search input (moved first) --%>
                  <div class="flex-1 min-w-[200px]">
                    <label class="mb-2 block text-sm font-medium text-gray-700">Carian</label>
                    <input
                      type="text"
                      name="search"
                      placeholder="Carian projek..."
                      class="w-full rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm text-gray-700 shadow-sm outline-none transition focus:border-blue-400 focus:ring-2 focus:ring-blue-200"
                    />
                  </div>
                  <%!-- Status Projek dropdown (now second) --%>
                  <div class="flex-1 min-w-[200px]">
                    <label class="mb-2 block text-sm font-medium text-gray-700">Status Projek</label>
                    <select
                      name="status"
                      class="w-full rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm text-gray-700 shadow-sm outline-none transition focus:border-blue-400 focus:ring-2 focus:ring-blue-200"
                    >
                      <option value="">Semua</option>

                      <option value="Pembangun belum di lantik">Pembangun belum di lantik</option>

                      <option value="Dalam Pembangunan">Dalam Pembangunan</option>

                      <option value="Selesai">Selesai</option>
                    </select>
                  </div>
                  <%!-- Tiada butang Projek Baru di Senarai Projek Diluluskan (pengurus projek) --%>
                </.form>
              </div>
              <%!-- Projects table (main printable content) --%>
              <div
                id="senarai-projek-document"
                class="mt-6 overflow-hidden rounded-xl bg-white shadow-sm print:shadow-none print:border-0 print:overflow-visible"
              >
                <table class="w-full print-table">
                  <thead class="bg-gray-50 print-table-header">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Nama Sistem
                      </th>

                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Emel
                      </th>

                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Kementerian/Jabatan
                      </th>

                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Status
                      </th>

                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Tarikh
                      </th>

                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500 print:hidden">
                        Tindakan
                      </th>
                    </tr>
                  </thead>

                  <tbody class="divide-y divide-gray-200 bg-white print-table-body">
                    <tr :for={project <- @projects} class="hover:bg-gray-50 print-table-row">
                      <td class="whitespace-nowrap px-6 py-4 text-sm font-medium text-gray-900">
                        {project.nama_projek}
                      </td>

                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        {project.pengurus_email || "-"}
                      </td>

                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        {project.jabatan || "-"}
                      </td>

                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        {status_display(project)}
                      </td>

                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        <%= if project.tarikh_mula do %>
                          {Calendar.strftime(project.tarikh_mula, "%d/%m/%Y")}
                        <% else %>
                          <span class="text-gray-400">-</span>
                        <% end %>
                      </td>

                      <td class="whitespace-nowrap px-6 py-4 text-sm print:hidden">
                        <div class="flex items-center gap-2">
                          <%!-- Sentiasa tunjuk butang Lihat untuk paparan penuh maklumat permohonan (data external) --%>
                          <.link
                            navigate={~p"/senarai-projek-diluluskan/#{project.id}"}
                            class="inline-flex items-center gap-1 px-2 py-1.5 text-xs font-medium text-green-700 bg-green-50 hover:bg-green-100 rounded-lg transition-colors duration-200"
                          >
                            <.icon name="hero-eye" class="w-4 h-4" />
                            <span class="hidden lg:inline">Lihat</span>
                          </.link>
                           <%!-- Modul link hanya untuk projek dalaman yang sedia ada --%>
                          <%= if project.project do %>
                            <.link
                              navigate={~p"/projek/#{project.project.id}/modul"}
                              class="inline-flex items-center gap-1 px-2 py-1.5 text-xs font-medium text-blue-700 bg-blue-50 hover:bg-blue-100 rounded-lg transition-colors duration-200"
                            >
                              <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                              <span class="hidden lg:inline">Modul</span>
                            </.link>
                          <% end %>
                        </div>
                      </td>
                    </tr>

                    <tr :if={@projects == []}>
                      <td colspan="6" class="px-6 py-8 text-center text-sm text-gray-500">
                        Tiada projek dijumpai
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <%!-- Pagination --%>
              <div :if={@total_pages > 1} class="flex justify-center">
                <nav class="flex items-center gap-2" aria-label="Pagination">
                  <button
                    :if={@page > 1}
                    phx-click="paginate"
                    phx-value-page={@page - 1}
                    class="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50"
                  >
                    Sebelum
                  </button>
                  <span
                    :for={page_num <- pagination_pages(@page, @total_pages)}
                    :if={page_num == :ellipsis}
                    class="rounded-lg px-3 py-2 text-sm font-medium text-gray-500"
                  >
                    ...
                  </span>
                  <button
                    :for={page_num <- pagination_pages(@page, @total_pages)}
                    :if={page_num != :ellipsis}
                    phx-click="paginate"
                    phx-value-page={page_num}
                    class={[
                      "rounded-lg px-3 py-2 text-sm font-medium transition",
                      if(page_num == @page,
                        do: "bg-[#2F80ED] text-white",
                        else: "border border-gray-300 bg-white text-gray-700 hover:bg-gray-50"
                      )
                    ]}
                  >
                    {page_num}
                  </button>
                  <button
                    :if={@page < @total_pages}
                    phx-click="paginate"
                    phx-value-page={@page + 1}
                    class="rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 transition hover:bg-gray-50"
                  >
                    Seterus
                  </button>
                </nav>
              </div>
            </div>
          </main>
          <%!-- New Project Modal --%>
          <div
            :if={@show_modal}
            class="fixed inset-0 z-50 overflow-y-auto"
            phx-click="close_modal"
            phx-click-away="close_modal"
            role="dialog"
            aria-modal="true"
          >
            <%!-- Backdrop --%>
            <div class="fixed inset-0 bg-black/60 transition-opacity" aria-hidden="true"></div>
            <%!-- Modal container --%>
            <div class="flex min-h-full items-center justify-center p-4">
              <div
                class="relative w-full max-w-3xl transform overflow-hidden rounded-2xl bg-white shadow-2xl transition-all"
                phx-click-away="close_modal"
              >
                <%!-- Modal header --%>
                <div class="border-b border-gray-200 bg-gradient-to-r from-[#2F80ED] to-[#2563EB] px-6 py-5">
                  <div class="flex items-center justify-between">
                    <div>
                      <h2 class="text-2xl font-bold text-white">Projek Baru</h2>

                      <p class="mt-1 text-sm text-blue-100">
                        Lengkapkan maklumat di bawah untuk mencipta projek baharu
                      </p>
                    </div>

                    <button
                      type="button"
                      phx-click="close_modal"
                      class="rounded-lg p-2 text-white/80 transition hover:bg-white/10 hover:text-white focus:outline-none focus:ring-2 focus:ring-white/50"
                      aria-label="Tutup"
                    >
                      <.icon name="hero-x-mark" class="h-6 w-6" />
                    </button>
                  </div>
                </div>
                <%!-- Modal body --%>
                <div class="max-h-[calc(100vh-200px)] overflow-y-auto px-6 py-6">
                  <.form
                    for={@form}
                    phx-change="validate"
                    phx-submit="save"
                    id="new-project-form"
                    multipart={true}
                    class="space-y-6"
                  >
                    <%!-- Basic Information Section --%>
                    <div class="space-y-5">
                      <div class="border-b border-gray-200 pb-2">
                        <h3 class="text-lg font-semibold text-gray-900">Maklumat Asas</h3>

                        <p class="mt-1 text-sm text-gray-500">Maklumat utama projek</p>
                      </div>
                      <%!-- Nama Sistem --%>
                      <div>
                        <.input
                          field={@form[:name]}
                          type="text"
                          label="Nama Sistem"
                          required
                          placeholder="Masukkan nama projek"
                          class="w-full"
                        />
                      </div>
                      <%!-- Jabatan/Agensi --%>
                      <div>
                        <.input
                          field={@form[:department]}
                          type="text"
                          label="Jabatan/Agensi"
                          placeholder="Masukkan nama jabatan atau agensi"
                          class="w-full"
                        />
                      </div>
                    </div>
                    <%!-- Team Assignment Section --%>
                    <div class="space-y-5">
                      <div class="border-b border-gray-200 pb-2">
                        <h3 class="text-lg font-semibold text-gray-900">Penugasan Pasukan</h3>

                        <p class="mt-1 text-sm text-gray-500">
                          Tetapkan pengurus projek dan pembangun sistem
                        </p>
                      </div>

                      <div class="grid grid-cols-1 gap-5 md:grid-cols-2">
                        <%!-- Pengurus Projek --%>
                        <div>
                          <.input
                            field={@form[:project_manager_id]}
                            type="select"
                            label="Pengurus Projek"
                            prompt="Pilih Pengurus Projek"
                            options={
                              Enum.map(@users, fn user ->
                                {"#{user.no_kp} - #{user.role || "N/A"}", user.id}
                              end)
                            }
                            class="w-full"
                          />
                        </div>
                        <%!-- Pembangun Sistem --%>
                        <div>
                          <.input
                            field={@form[:developer_id]}
                            type="select"
                            label="Pembangun Sistem"
                            prompt="Pilih Pembangun Sistem"
                            options={
                              Enum.map(@users, fn user ->
                                {"#{user.no_kp} - #{user.role || "N/A"}", user.id}
                              end)
                            }
                            class="w-full"
                          />
                        </div>
                      </div>
                    </div>
                    <%!-- Timeline Section --%>
                    <div class="space-y-5">
                      <div class="border-b border-gray-200 pb-2">
                        <h3 class="text-lg font-semibold text-gray-900">Jadual Projek</h3>

                        <p class="mt-1 text-sm text-gray-500">
                          Tetapkan tarikh mula dan jangkaan siap
                        </p>
                      </div>

                      <div class="grid grid-cols-1 gap-5 md:grid-cols-2">
                        <%!-- Tarikh Mula --%>
                        <div>
                          <.input
                            field={@form[:start_date]}
                            type="date"
                            label="Tarikh Mula"
                            class="w-full"
                          />
                        </div>
                        <%!-- Tarikh Jangkaan Siap --%>
                        <div>
                          <.input
                            field={@form[:expected_completion_date]}
                            type="date"
                            label="Tarikh Jangkaan Siap"
                            class="w-full"
                          />
                        </div>
                      </div>
                    </div>
                    <%!-- Documents Section --%>
                    <div class="space-y-5">
                      <div class="border-b border-gray-200 pb-2">
                        <h3 class="text-lg font-semibold text-gray-900">Dokumen Sokongan</h3>

                        <p class="mt-1 text-sm text-gray-500">
                          Muat naik dokumen yang berkaitan dengan projek
                        </p>
                      </div>

                      <div>
                        <label class="mb-2 block text-sm font-medium text-gray-700">
                          Dokumen Sokongan
                          <span class="ml-1 text-xs font-normal text-gray-500">(Pilihan)</span>
                        </label>
                        <div class="mt-1 flex justify-center rounded-lg border-2 border-dashed border-gray-300 px-6 py-8 transition hover:border-[#2F80ED] hover:bg-gray-50">
                          <div class="text-center">
                            <.icon
                              name="hero-document-arrow-up"
                              class="mx-auto h-12 w-12 text-gray-400"
                            />
                            <div class="mt-4 flex text-sm leading-6 text-gray-600">
                              <label
                                for="file-upload"
                                class="relative cursor-pointer rounded-md bg-white font-semibold text-[#2F80ED] focus-within:outline-none focus-within:ring-2 focus-within:ring-[#2F80ED] focus-within:ring-offset-2"
                              >
                                <span>Pilih fail</span>
                                <input
                                  id="file-upload"
                                  name="supporting_documents"
                                  type="file"
                                  multiple
                                  accept=".pdf,.doc,.docx"
                                  class="sr-only"
                                />
                              </label>
                              <p class="pl-1">atau seret dan lepaskan</p>
                            </div>

                            <p class="mt-2 text-xs leading-5 text-gray-600">
                              PDF, DOC, DOCX sehingga 10MB setiap fail
                            </p>
                          </div>
                        </div>
                      </div>
                    </div>
                    <%!-- Form Actions --%>
                    <div class="flex items-center justify-end gap-3 border-t border-gray-200 pt-6">
                      <button
                        type="button"
                        phx-click="close_modal"
                        class="rounded-lg border border-gray-300 bg-white px-6 py-2.5 text-sm font-semibold text-gray-700 shadow-sm transition hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2"
                      >
                        Batal
                      </button>
                      <button
                        type="submit"
                        class="rounded-lg bg-gradient-to-r from-[#2F80ED] to-[#2563EB] px-6 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:from-[#2563EB] hover:to-[#1d4ed8] focus:outline-none focus:ring-2 focus:ring-[#2F80ED] focus:ring-offset-2"
                      >
                        Simpan Projek
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp pagination_pages(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages - 1, total_pages]

      current_page >= total_pages - 3 ->
        [
          1,
          2,
          :ellipsis,
          total_pages - 4,
          total_pages - 3,
          total_pages - 2,
          total_pages - 1,
          total_pages
        ]

      true ->
        [
          1,
          2,
          :ellipsis,
          current_page - 1,
          current_page,
          current_page + 1,
          :ellipsis,
          total_pages - 1,
          total_pages
        ]
    end
  end
end
