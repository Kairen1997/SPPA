defmodule SppaWeb.ProjectListLive do
  use SppaWeb, :live_view

  alias Sppa.Projects.Project
  alias Sppa.Accounts
  alias Sppa.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role == "pengurus projek" do
      socket = assign(socket, :hide_root_header, true)
      socket = assign(socket, :page_title, "Senarai Projek")
      socket = assign(socket, :desktop_sidebar_visible, true)

      # Filter assigns
      socket =
        socket
        |> assign(:status_filter, "")
        |> assign(:phase_filter, "")
        |> assign(:search_query, "")
        |> assign(:page, 1)
        |> assign(:per_page, 10)
        |> assign(:show_modal, false)
        |> assign(:form, to_form(%{}, as: :project))

      if connected?(socket) do
        projects = list_projects(socket)
        total_pages = calculate_total_pages(socket)
        users = Accounts.list_users()

        {:ok,
         socket
         |> assign(:projects, projects)
         |> assign(:total_pages, total_pages)
         |> assign(:users, users)}
      else
        {:ok,
         socket
         |> assign(:projects, [])
         |> assign(:total_pages, 1)
         |> assign(:users, [])}
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
  def handle_event("toggle_desktop_sidebar", _params, socket) do
    new_state = !socket.assigns.desktop_sidebar_visible
    {:noreply, assign(socket, :desktop_sidebar_visible, new_state)}
  end

  @impl true
  def handle_event("filter", %{"status" => status, "phase" => phase, "search" => search}, socket) do
    socket =
      socket
      |> assign(:status_filter, status)
      |> assign(:phase_filter, phase)
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

  defp list_projects(socket) do
    base_query =
      Project
      |> where([p], p.user_id == ^socket.assigns.current_scope.user.id)

    # Apply status filter
    base_query =
      if socket.assigns.status_filter != "" do
        where(base_query, [p], p.status == ^socket.assigns.status_filter)
      else
        base_query
      end

    # Apply search filter
    base_query =
      if socket.assigns.search_query != "" do
        search_term = "%#{socket.assigns.search_query}%"
        where(base_query, [p], ilike(p.name, ^search_term))
      else
        base_query
      end

    # Apply pagination
    offset = (socket.assigns.page - 1) * socket.assigns.per_page

    base_query
    |> preload([:developer, :project_manager])
    |> order_by([p], desc: p.last_updated)
    |> limit(^socket.assigns.per_page)
    |> offset(^offset)
    |> Repo.all()
  end

  defp calculate_total_pages(socket) do
    base_query =
      Project
      |> where([p], p.user_id == ^socket.assigns.current_scope.user.id)

    # Apply status filter
    base_query =
      if socket.assigns.status_filter != "" do
        where(base_query, [p], p.status == ^socket.assigns.status_filter)
      else
        base_query
      end

    # Apply search filter
    base_query =
      if socket.assigns.search_query != "" do
        search_term = "%#{socket.assigns.search_query}%"
        where(base_query, [p], ilike(p.name, ^search_term))
      else
        base_query
      end

    total = Repo.aggregate(base_query, :count, :id)
    ceil(total / socket.assigns.per_page)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
      <div class="flex min-h-screen flex-col bg-[#F4F5FB] text-gray-800">
        <.topbar current_scope={@current_scope} />

        <.sidebar
          current_scope={@current_scope}
          desktop_sidebar_visible={@desktop_sidebar_visible}
          current_path="/senarai-projek"
        >
          <%!-- Main content --%>
          <main class="flex-1 overflow-y-auto px-4 pb-10 pt-6 sm:px-6 lg:px-10">
            <div class="mx-auto flex max-w-7xl flex-col gap-6">
              <%!-- Page title --%>
              <div class="flex items-center justify-between">
                <div class="flex flex-col">
                  <span class="text-xs font-semibold tracking-[0.2em] text-gray-400">
                    SENARAI PROJEK
                  </span>
                  <span class="text-2xl font-semibold tracking-wide text-gray-800">
                    Tapisan
                  </span>
                </div>
              </div>

              <%!-- Filter section --%>
              <div class="rounded-xl bg-white p-6 shadow-sm">
                <.form
                  for={%{}}
                  phx-change="filter"
                  id="filter-form"
                  class="flex flex-wrap items-end gap-4"
                >
                  <%!-- Status Projek dropdown --%>
                  <div class="flex-1 min-w-[200px]">
                    <label class="mb-2 block text-sm font-medium text-gray-700">
                      Status Projek
                    </label>
                    <select
                      name="status"
                      class="w-full rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm text-gray-700 shadow-sm outline-none transition focus:border-blue-400 focus:ring-2 focus:ring-blue-200"
                    >
                      <option value="">Semua</option>
                      <option value="Dalam Pembangunan">Dalam Pembangunan</option>
                      <option value="Ditangguhkan">Ditangguhkan</option>
                      <option value="UAT">UAT</option>
                      <option value="Pengurusan Perubahan">Pengurusan Perubahan</option>
                      <option value="Selesai">Selesai</option>
                    </select>
                  </div>

                  <%!-- Fasa Semasa dropdown --%>
                  <div class="flex-1 min-w-[200px]">
                    <label class="mb-2 block text-sm font-medium text-gray-700">
                      Fasa Semasa
                    </label>
                    <select
                      name="phase"
                      class="w-full rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm text-gray-700 shadow-sm outline-none transition focus:border-blue-400 focus:ring-2 focus:ring-blue-200"
                    >
                      <option value="">Semua</option>
                      <option value="Analisis dan Rekabentuk">Analisis dan Rekabentuk</option>
                      <option value="Pembangunan">Pembangunan</option>
                      <option value="UAT">UAT</option>
                      <option value="Penyerahan">Penyerahan</option>
                    </select>
                  </div>

                  <%!-- Search input --%>
                  <div class="flex-1 min-w-[200px]">
                    <label class="mb-2 block text-sm font-medium text-gray-700">Carian</label>
                    <input
                      type="text"
                      name="search"
                      placeholder="Carian projek..."
                      class="w-full rounded-lg border border-gray-300 bg-white px-4 py-2.5 text-sm text-gray-700 shadow-sm outline-none transition focus:border-blue-400 focus:ring-2 focus:ring-blue-200"
                    />
                  </div>

                  <%!-- New Project button --%>
                  <div class="flex-shrink-0">
                    <button
                      type="button"
                      phx-click="open_new_project_modal"
                      class="rounded-lg bg-[#2F80ED] px-6 py-2.5 text-sm font-medium text-white shadow-sm transition hover:bg-[#2563EB] focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                    >
                      Projek Baru
                    </button>
                  </div>
                </.form>
              </div>

              <%!-- Projects table --%>
              <div class="overflow-hidden rounded-xl bg-white shadow-sm">
                <table class="w-full">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Nama Projek
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Status
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Fasa Semasa
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Progress
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Dokumen
                      </th>
                      <th class="px-6 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                        Tindakan
                      </th>
                    </tr>
                  </thead>
                  <tbody class="divide-y divide-gray-200 bg-white">
                    <tr :for={project <- @projects} class="hover:bg-gray-50">
                      <td class="whitespace-nowrap px-6 py-4 text-sm font-medium text-gray-900">
                        {project.name}
                      </td>
                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        <span
                          class={[
                            "inline-flex rounded-full px-3 py-1 text-xs font-semibold",
                            status_badge_class(project.status)
                          ]}
                        >
                          {project.status}
                        </span>
                      </td>
                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        {get_phase(project)}
                      </td>
                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        {get_progress(project)}%
                      </td>
                      <td class="whitespace-nowrap px-6 py-4 text-sm text-gray-700">
                        {get_documents(project)}
                      </td>
                      <td class="whitespace-nowrap px-6 py-4 text-sm">
                        <button
                          type="button"
                          class="font-medium text-[#2F80ED] transition hover:text-[#2563EB]"
                        >
                          [Lihat]
                        </button>
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
        </.sidebar>

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

                    <%!-- Nama Projek --%>
                    <div>
                      <.input
                        field={@form[:name]}
                        type="text"
                        label="Nama Projek"
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
                      <p class="mt-1 text-sm text-gray-500">Tetapkan pengurus projek dan pembangun sistem</p>
                    </div>

                    <div class="grid grid-cols-1 gap-5 md:grid-cols-2">
                      <%!-- Pengurus Projek --%>
                      <div>
                        <.input
                          field={@form[:project_manager_id]}
                          type="select"
                          label="Pengurus Projek"
                          prompt="Pilih Pengurus Projek"
                          options={Enum.map(@users, fn user -> {"#{user.no_kp} - #{user.role || "N/A"}", user.id} end)}
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
                          options={Enum.map(@users, fn user -> {"#{user.no_kp} - #{user.role || "N/A"}", user.id} end)}
                          class="w-full"
                        />
                      </div>
                    </div>
                  </div>

                  <%!-- Timeline Section --%>
                  <div class="space-y-5">
                    <div class="border-b border-gray-200 pb-2">
                      <h3 class="text-lg font-semibold text-gray-900">Jadual Projek</h3>
                      <p class="mt-1 text-sm text-gray-500">Tetapkan tarikh mula dan jangkaan siap</p>
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
                      <p class="mt-1 text-sm text-gray-500">Muat naik dokumen yang berkaitan dengan projek</p>
                    </div>

                    <div>
                      <label class="mb-2 block text-sm font-medium text-gray-700">
                        Dokumen Sokongan
                        <span class="ml-1 text-xs font-normal text-gray-500">(Pilihan)</span>
                      </label>
                      <div class="mt-1 flex justify-center rounded-lg border-2 border-dashed border-gray-300 px-6 py-8 transition hover:border-[#2F80ED] hover:bg-gray-50">
                        <div class="text-center">
                          <.icon name="hero-document-arrow-up" class="mx-auto h-12 w-12 text-gray-400" />
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
    </Layouts.app>
    """
  end

  # Helper functions for display
  defp status_badge_class(status) do
    case status do
      "Dalam Pembangunan" -> "bg-blue-100 text-blue-700 ring-1 ring-blue-200"
      "Ditangguhkan" -> "bg-amber-100 text-amber-700 ring-1 ring-amber-200"
      "Selesai" -> "bg-emerald-100 text-emerald-700 ring-1 ring-emerald-200"
      "UAT" -> "bg-purple-100 text-purple-700 ring-1 ring-purple-200"
      "Pengurusan Perubahan" -> "bg-indigo-100 text-indigo-700 ring-1 ring-indigo-200"
      _ -> "bg-gray-100 text-gray-700 ring-1 ring-gray-200"
    end
  end

  defp get_phase(project) do
    # Placeholder - map status to phase for now
    case project.status do
      "Dalam Pembangunan" -> "Pembangunan"
      "UAT" -> "UAT"
      "Selesai" -> "Penyerahan"
      "Ditangguhkan" -> "Analisis dan Rekabentuk"
      _ -> "Analisis dan Rekabentuk"
    end
  end

  defp get_progress(project) do
    # Placeholder - calculate based on status for now
    case project.status do
      "Selesai" -> 100
      "UAT" -> 75
      "Dalam Pembangunan" -> 45
      "Ditangguhkan" -> 30
      _ -> 0
    end
  end

  defp get_documents(project) do
    # Placeholder - return mock document count
    case project.status do
      "Selesai" -> "6/6"
      "UAT" -> "4/6"
      "Dalam Pembangunan" -> "2/6"
      _ -> "0/6"
    end
  end

  defp pagination_pages(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages - 1, total_pages]

      current_page >= total_pages - 3 ->
        [1, 2, :ellipsis, total_pages - 4, total_pages - 3, total_pages - 2, total_pages - 1, total_pages]

      true ->
        [1, 2, :ellipsis, current_page - 1, current_page, current_page + 1, :ellipsis, total_pages - 1, total_pages]
    end
  end
end
