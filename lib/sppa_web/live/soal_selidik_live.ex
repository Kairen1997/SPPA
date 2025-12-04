defmodule SppaWeb.SoalSelidikLive do
  use SppaWeb, :live_view

  @allowed_roles ["pembangun sistem", "pengurus projek", "ketua penolong pengarah"]

  @impl true
  def mount(_params, _session, socket) do
    # Verify user has required role (defense in depth - router already checks this)
    user_role =
      socket.assigns.current_scope && socket.assigns.current_scope.user &&
        socket.assigns.current_scope.user.role

    if user_role && user_role in @allowed_roles do
      # Initialize sections
      sections = [
        %{
          id: "section_1",
          category: "FUNCTIONAL REQUIREMENT",
          title: "PENDAFTARAN DAN LOG MASUK"
        }
      ]

      socket =
        socket
        |> assign(:hide_root_header, true)
        |> assign(:page_title, "Soal Selidik")
        |> assign(:sidebar_open, false)
        |> assign(:notifications_open, false)
        |> assign(:current_path, "/soal-selidik")
        |> assign(:document_id, "JPKN-BPA-01/B1")
        |> assign(:system_name, "")
        |> assign(:form, to_form(%{}, as: :soal_selidik))
        |> stream(:sections, sections)

      # Initialize rows for each section
      socket =
        sections
        |> Enum.reduce(socket, fn section, acc ->
          stream_name = String.to_atom("#{section.id}_rows")

          initial_rows = [
            %{id: "#{section.id}_row_1", no: 1, soalan: "", maklumbalas: "", catatan: ""}
          ]

          stream(acc, stream_name, initial_rows)
        end)

      {:ok, socket}
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
    {:noreply, update(socket, :notifications_open, &(!&1))}
  end

  @impl true
  def handle_event("close_notifications", _params, socket) do
    {:noreply, assign(socket, :notifications_open, false)}
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
  def handle_event("add_section", _params, socket) do
    section_id = "section_#{System.unique_integer([:positive])}"

    new_section = %{
      id: section_id,
      category: "",
      title: ""
    }

    socket =
      socket
      |> stream(:sections, [new_section])
      |> stream(String.to_atom("#{section_id}_rows"), [
        %{id: "#{section_id}_row_1", no: 1, soalan: "", maklumbalas: "", catatan: ""}
      ])

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_section", %{"id" => section_id}, socket) do
    stream_name = String.to_atom("#{section_id}_rows")

    # Remove the section and clear its rows stream
    socket =
      socket
      |> stream_delete(:sections, section_id)

    # Clear the rows stream if it exists
    socket =
      if Map.has_key?(socket.assigns.streams, stream_name) do
        stream(socket, stream_name, [], reset: true)
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("add_row", %{"section_id" => section_id}, socket) do
    # Validate section_id
    if is_nil(section_id) or section_id == "" do
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "Ralat: ID bahagian tidak sah.")

      {:noreply, socket}
    else
      stream_name = get_stream_name(section_id)

      # Calculate next row number based on current stream
      next_no = get_next_row_number(stream_name, socket)

      # Create new blank row
      row_id = "#{section_id}_row_#{System.unique_integer([:positive])}"

      new_row = %{
        id: row_id,
        no: next_no,
        soalan: "",
        maklumbalas: "",
        catatan: ""
      }

      # Add the new blank row to the stream
      {:noreply, stream(socket, stream_name, [new_row])}
    end
  end

  @impl true
  def handle_event("remove_row", %{"section_id" => section_id, "id" => id}, socket) do
    stream_name = get_stream_name(section_id)
    socket = stream_delete(socket, stream_name, id)
    {:noreply, renumber_stream(stream_name, socket)}
  end

  defp get_stream_name(section_id) when is_binary(section_id) do
    # Safe to use String.to_atom here since we control section_id values
    String.to_atom("#{section_id}_rows")
  end

  def get_section_rows(streams, section_id) when is_binary(section_id) do
    try do
      stream_name = String.to_atom("#{section_id}_rows")
      Map.get(streams, stream_name, %{})
    rescue
      ArgumentError -> %{}
    end
  end

  def get_section_rows(_streams, _section_id), do: %{}

  defp get_next_row_number(stream_name, socket) do
    streams = socket.assigns.streams || %{}
    stream = Map.get(streams, stream_name, %{})

    if map_size(stream) == 0 do
      1
    else
      max_no =
        stream
        |> Enum.map(fn {_id, row} -> row.no || 0 end)
        |> Enum.max(0)

      max_no + 1
    end
  end

  defp renumber_stream(stream_name, socket) do
    streams = socket.assigns.streams || %{}
    stream = Map.get(streams, stream_name, %{})

    renumbered_rows =
      stream
      |> Enum.to_list()
      |> Enum.with_index(1)
      |> Enum.map(fn {{id, row}, new_no} ->
        updated_row = Map.put(row, :no, new_no)
        {id, updated_row}
      end)

    socket
    |> stream(stream_name, renumbered_rows, reset: true)
  end
end
