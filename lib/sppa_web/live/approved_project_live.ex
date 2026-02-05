defmodule SppaWeb.ApprovedProjectLive do
  use SppaWeb, :live_view

  alias Sppa.ApprovedProjects
  alias Sppa.Accounts

  @allowed_roles ["pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: current_scope}} = socket) do
    user_role = current_scope && current_scope.user && current_scope.user.role

    if user_role in @allowed_roles do
      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Butiran Projek Diluluskan")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:profile_menu_open, false)
        |> assign(:notifications_count, 0)
        |> assign(:activities, [])

      if connected?(socket) do
        with {approved_id, _} <- Integer.parse(id),
             approved_project when not is_nil(approved_project) <-
               ApprovedProjects.get_approved_project!(approved_id) do
          # Get all developers for the dropdown
          all_users = Accounts.list_users()
          all_developers = Enum.filter(all_users, fn user -> user.role == "pembangun sistem" end)

          # Parse pembangun_sistem from string (comma-separated) to list of names
          stored_names = parse_pembangun_sistem(approved_project.pembangun_sistem)
          selected_developers = stored_names

          # Get available developers (not already selected)
          available_developers =
            all_developers
            |> Enum.filter(fn dev -> dev.no_kp not in selected_developers end)

          {:ok,
           socket
           |> assign(:approved_project, approved_project)
           |> assign(:developers, all_developers)
           |> assign(:available_developers, available_developers)
           |> assign(:selected_developers, selected_developers)
           |> assign(
             :form_pembangun,
             to_form(%{"pembangun_sistem" => selected_developers}, as: :project)
           )}
        else
          _ ->
            {:ok,
             socket
             |> put_flash(:error, "Projek diluluskan tidak ditemui.")
             |> push_navigate(to: ~p"/senarai-projek-diluluskan")}
        end
      else
        {:ok,
         socket
         |> assign(:approved_project, nil)
         |> assign(:developers, [])
         |> assign(:available_developers, [])
         |> assign(:selected_developers, [])}
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
     |> put_flash(:error, "Akses tidak sah.")
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp format_date(nil), do: "-"
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%d/%m/%Y")

  defp ensure_full_url(nil), do: nil

  defp ensure_full_url(url) when is_binary(url) do
    url = String.trim(url)

    # First, normalize any localhost references
    normalized_url =
      url
      |> String.replace("localhost:4000", "10.71.67.159:4000")
      |> String.replace("127.0.0.1:4000", "10.71.67.159:4000")

    cond do
      # Already a full URL with http:// or https://
      String.starts_with?(normalized_url, ["http://", "https://"]) ->
        normalized_url

      # If it starts with the IP address directly (without http://)
      String.starts_with?(normalized_url, "10.71.67.159:4000") ->
        "http://" <> normalized_url

      # If it starts with /localhost: or /127.0.0.1:, extract the path
      String.starts_with?(normalized_url, "/localhost:") or
          String.starts_with?(normalized_url, "/127.0.0.1:") ->
        # Remove /localhost:4000 or /127.0.0.1:4000 and keep the rest
        # Pattern: /localhost:4000/uploads/... -> /uploads/...
        path =
          normalized_url
          |> String.replace(~r/^\/localhost:\d+/, "")
          |> String.replace(~r/^\/127\.0\.0\.1:\d+/, "")

        "http://10.71.67.159:4000" <> path

      # If it starts with localhost: or 127.0.0.1: (without leading slash)
      String.starts_with?(normalized_url, "localhost:") or
          String.starts_with?(normalized_url, "127.0.0.1:") ->
        # Replace localhost:4000 or 127.0.0.1:4000 with http://10.71.67.159:4000
        normalized_url
        |> String.replace(~r/^localhost:\d+/, "10.71.67.159:4000")
        |> String.replace(~r/^127\.0\.0\.1:\d+/, "10.71.67.159:4000")
        |> then(&("http://" <> &1))

      # If it's a relative path starting with /
      String.starts_with?(normalized_url, "/") ->
        "http://10.71.67.159:4000" <> normalized_url

      # If it's just a number or ID, construct the file download URL
      Regex.match?(~r/^\d+$/, normalized_url) ->
        "http://10.71.67.159:4000/api/files/#{normalized_url}"

      # If it looks like a file path without leading slash
      String.contains?(normalized_url, ["/", ".pdf", ".PDF"]) ->
        "http://10.71.67.159:4000/" <> normalized_url

      # Default: treat as relative path
      true ->
        "http://10.71.67.159:4000/" <> normalized_url
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
  def handle_event("add_pembangun_sistem", %{"developer_id" => developer_id_str}, socket) do
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
              # Update available developers (exclude selected ones)
              available_developers =
                socket.assigns.developers
                |> Enum.filter(fn dev -> dev.no_kp not in new_selected end)

              {:noreply,
               socket
               |> assign(:approved_project, updated_project)
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

  @impl true
  def handle_event("remove_pembangun_sistem", %{"no_kp" => no_kp}, socket) do
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

  @impl true
  def handle_event("update_tarikh_mula", %{"tarikh_mula" => date_str}, socket) do
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
           "tarikh_mula" => date_value
         }) do
      {:ok, updated_project} ->
        {:noreply,
         socket
         |> assign(:approved_project, updated_project)
         |> put_flash(:info, "Tarikh mula telah dikemaskini.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Gagal mengemaskini tarikh mula.")}
    end
  end

  @impl true
  def handle_event("update_tarikh_jangkaan_siap", %{"tarikh_jangkaan_siap" => date_str}, socket) do
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
  end

  @impl true
  def render(%{approved_project: nil} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} full_width={true}>
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
                    navigate={~p"/senarai-projek-diluluskan"}
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
                            <%!-- Dropdown to add pembangun sistem --%>
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
                                  <option value="">Pilih Pembangun Sistem</option>

                                  <%= for developer <- @available_developers do %>
                                    <option value={developer.id}>
                                      {developer.no_kp || "Unknown"}{if developer.email,
                                        do: " (#{developer.email})",
                                        else: ""}
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
                            <%!-- Display selected pembangun sistem --%>
                            <%= if @selected_developers != [] do %>
                              <div class="mt-4 space-y-2">
                                <p class="text-xs font-semibold text-gray-700 uppercase tracking-wide">
                                  Pembangun Sistem Dipilih:
                                </p>

                                <div class="flex flex-wrap gap-2">
                                  <%= for no_kp <- @selected_developers do %>
                                    <div class="inline-flex items-center gap-2 rounded-full bg-indigo-100 px-3 py-1.5 text-sm text-indigo-800">
                                      <span>{no_kp}</span>
                                      <button
                                        type="button"
                                        phx-click="remove_pembangun_sistem"
                                        phx-value-no_kp={no_kp}
                                        class="ml-1 rounded-full p-0.5 hover:bg-indigo-200 transition-colors"
                                        title="Keluarkan"
                                      >
                                        <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
                                      </button>
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
                          Tarikh Mula
                        </dt>

                        <dd>
                          <.form
                            for={%{}}
                            phx-change="update_tarikh_mula"
                            id="tarikh-mula-form"
                          >
                            <input
                              type="date"
                              name="tarikh_mula"
                              value={
                                if @approved_project.tarikh_mula,
                                  do: Date.to_iso8601(@approved_project.tarikh_mula),
                                  else: ""
                              }
                              class="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-700 shadow-sm outline-none transition focus:border-indigo-400 focus:ring-2 focus:ring-indigo-200"
                            />
                          </.form>
                        </dd>
                      </div>

                      <div>
                        <dt class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">
                          Tarikh Jangkaan Siap
                        </dt>

                        <dd>
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
