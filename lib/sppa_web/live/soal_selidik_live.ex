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
          title: ""
        },
        %{
          id: "section_9",
          category: "NON-FUNCTIONAL REQUIREMENT",
          title: ""
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
        |> assign(:sections, sections)
        |> assign(:current_page, 1)
        |> assign(:form, to_form(%{}, as: :soal_selidik))

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

    # add new section to list
    sections = socket.assigns.sections ++ [new_section]

    socket =
      socket
      |> assign(:sections, sections)
      |> stream(String.to_atom("#{section_id}_rows"), [
        %{id: "#{section_id}_row_1", no: 1, soalan: "", maklumbalas: "", catatan: ""}
      ])

    total_pages = total_pages_for_categories(sections)

    socket =
      socket
      |> assign(:current_page, total_pages)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_section_category", %{"section_id" => section_id, "category" => category}, socket) do
    sections = socket.assigns.sections || []

    updated_sections =
      Enum.map(sections, fn section ->
        if section.id == section_id do
          Map.put(section, :category, category)
        else
          section
        end
      end)

    {:noreply, assign(socket, :sections, updated_sections)}
  end

  @impl true
  def handle_event("remove_section", %{"id" => section_id}, socket) do
    stream_name = String.to_atom("#{section_id}_rows")

    # Remove the section from list and clear its rows stream
    sections =
      socket.assigns.sections
      |> Enum.reject(&(&1.id == section_id))

    # Clear the rows stream if it exists
    socket =
      if Map.has_key?(socket.assigns.streams, stream_name) do
        stream(socket, stream_name, [], reset: true)
      else
        socket
      end

    # Ensure current_page is still within bounds after removal
    total_pages = total_pages_for_categories(sections)

    current_page =
      if socket.assigns.current_page > total_pages do
        total_pages
      else
        socket.assigns.current_page
      end

    {:noreply, socket |> assign(:sections, sections) |> assign(:current_page, current_page)}
  end

  @impl true
  def handle_event("remove_last_section", _params, socket) do
    sections = socket.assigns.sections || []

    # Jika tiada sebarang bahagian, tidak buat apa-apa
    if sections == [] do
      {:noreply, socket}
    else
      current_category = current_category(sections, socket.assigns.current_page)

      sections_in_category =
        sections
        |> sections_for_category(current_category)

      case List.last(sections_in_category) do
        nil ->
          {:noreply, socket}

        %{id: section_id} ->
          stream_name = String.to_atom("#{section_id}_rows")

          # Buang bahagian daripada senarai dan kosongkan stream barisnya
          sections =
            sections
            |> Enum.reject(&(&1.id == section_id))

          socket =
            if Map.has_key?(socket.assigns.streams, stream_name) do
              stream(socket, stream_name, [], reset: true)
            else
              socket
            end

          # Pastikan current_page masih dalam julat selepas buang bahagian
          total_pages = total_pages_for_categories(sections)

          current_page =
            if socket.assigns.current_page > total_pages do
              total_pages
            else
              socket.assigns.current_page
            end

          {:noreply, socket |> assign(:sections, sections) |> assign(:current_page, current_page)}
      end
    end
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
  def handle_event("remove_last_row", %{"section_id" => section_id}, socket) do
    stream_name = get_stream_name(section_id)
    streams = socket.assigns.streams || %{}

    case Map.get(streams, stream_name) do
      %Phoenix.LiveView.LiveStream{} = stream ->
        last_entry = stream |> Enum.to_list() |> List.last()

        case last_entry do
          {dom_id, _row} ->
            socket = stream_delete(socket, stream_name, dom_id)
            {:noreply, renumber_stream(stream_name, socket)}

          nil ->
            {:noreply, socket}
        end

      _other ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "update_row",
        %{
          "section_id" => section_id,
          "row_id" => row_id,
          "field" => field,
          "value" => value
        },
        socket
      ) do
    stream_name = get_stream_name(section_id)
    streams = socket.assigns.streams || %{}

    case Map.get(streams, stream_name) do
      %Phoenix.LiveView.LiveStream{} = stream ->
        field_atom =
          case field do
            "soalan" -> :soalan
            "maklumbalas" -> :maklumbalas
            "catatan" -> :catatan
            _ -> nil
          end

        updated_rows =
          stream
          |> Enum.map(fn {dom_id, row} ->
            if dom_id == row_id and field_atom do
              Map.put(row, field_atom, value)
            else
              row
            end
          end)

        {:noreply, stream(socket, stream_name, updated_rows, reset: true)}

      _other ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    total_pages = total_pages_for_categories(socket.assigns.sections)

    new_page =
      if socket.assigns.current_page < total_pages do
        socket.assigns.current_page + 1
      else
        socket.assigns.current_page
      end

    {:noreply, assign(socket, :current_page, new_page)}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    new_page =
      if socket.assigns.current_page > 1 do
        socket.assigns.current_page - 1
      else
        socket.assigns.current_page
      end

    {:noreply, assign(socket, :current_page, new_page)}
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

  def categories_from_sections(sections) do
    sections
    |> Enum.map(& &1.category)
    |> Enum.uniq()
  end

  def current_category(sections, current_page) do
    sections
    |> categories_from_sections()
    |> Enum.at(current_page - 1)
  end

  def sections_for_category(sections, nil), do: sections

  def sections_for_category(sections, category) do
    Enum.filter(sections, &(&1.category == category))
  end

  def total_pages_for_categories(sections) do
    sections
    |> categories_from_sections()
    |> length()
  end
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
