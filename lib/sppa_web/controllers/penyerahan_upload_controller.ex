defmodule SppaWeb.PenyerahanUploadController do
  use SppaWeb, :controller

  alias Sppa.Penyerahans

  @allowed_extensions ~w(.pdf .doc .docx)
  @max_file_size 10_000_000

  def create(conn, params) do
    project_id =
      case conn.path_params["project_id"] do
        nil ->
          nil

        id ->
          case Integer.parse(to_string(id)) do
            {num, _} -> num
            :error -> nil
          end
      end

    current_scope = conn.assigns.current_scope

    if is_nil(project_id) do
      conn
      |> put_flash(:error, "ID projek tidak sah.")
      |> redirect(to: ~p"/projek")
    else
      unless current_scope do
        conn
        |> put_flash(:error, "Sesi tidak sah.")
        |> redirect(to: ~p"/projek/#{project_id}?tab=penyerahan")
      else
        penyerahan =
          Penyerahans.get_penyerahan_by_project_id(project_id) ||
            create_penyerahan_for_project(project_id)

        case penyerahan do
          nil ->
            conn
            |> put_flash(:error, "Projek atau penyerahan tidak ditemui.")
            |> redirect(to: ~p"/projek/#{project_id}?tab=penyerahan")

          penyerahan ->
            attrs = %{}

            attrs =
              case save_uploaded_file(
                     conn,
                     params["manual_file"],
                     penyerahan.id,
                     "manual_pengguna"
                   ) do
                nil ->
                  attrs

                filename ->
                  attrs
                  |> Map.put(:manual_pengguna, filename)
                  |> Map.put(
                    :manual_pengguna_nama,
                    upload_original_filename(params["manual_file"]) || filename
                  )
              end

            attrs =
              case save_uploaded_file(conn, params["surat_file"], penyerahan.id, "surat_akuan") do
                nil ->
                  attrs

                filename ->
                  attrs
                  |> Map.put(:surat_akuan_penerimaan, filename)
                  |> Map.put(
                    :surat_akuan_nama,
                    upload_original_filename(params["surat_file"]) || filename
                  )
              end

            if attrs == %{} do
              conn
              |> put_flash(:error, "Sila pilih sekurang-kurangnya satu fail.")
              |> redirect(to: ~p"/projek/#{project_id}?tab=penyerahan")
            else
              update_attrs =
                %{
                  tarikh_penyerahan: penyerahan.tarikh_penyerahan,
                  manual_pengguna: Map.get(attrs, :manual_pengguna) || penyerahan.manual_pengguna,
                  manual_pengguna_nama:
                    Map.get(attrs, :manual_pengguna_nama) || penyerahan.manual_pengguna_nama,
                  surat_akuan_penerimaan:
                    Map.get(attrs, :surat_akuan_penerimaan) || penyerahan.surat_akuan_penerimaan,
                  surat_akuan_nama:
                    Map.get(attrs, :surat_akuan_nama) || penyerahan.surat_akuan_nama
                }

              case Penyerahans.update_penyerahan(penyerahan, update_attrs) do
                {:ok, _} ->
                  msg =
                    cond do
                      Map.has_key?(attrs, :manual_pengguna) and
                          Map.has_key?(attrs, :surat_akuan_penerimaan) ->
                        "Manual pengguna dan Surat Akuan berjaya dimuat naik"

                      Map.has_key?(attrs, :manual_pengguna) ->
                        "Manual pengguna berjaya dimuat naik"

                      true ->
                        "Surat Akuan Penerimaan Aplikasi berjaya dimuat naik"
                    end

                  conn
                  |> put_flash(:info, msg)
                  |> redirect(to: ~p"/projek/#{project_id}?tab=penyerahan")

                {:error, _changeset} ->
                  conn
                  |> put_flash(:error, "Gagal menyimpan. Sila cuba lagi.")
                  |> redirect(to: ~p"/projek/#{project_id}?tab=penyerahan")
              end
            end
        end
      end
    end
  end

  defp upload_original_filename(nil), do: nil
  defp upload_original_filename(%{path: ""}), do: nil
  defp upload_original_filename(%{path: nil}), do: nil

  defp upload_original_filename(%Plug.Upload{filename: filename}) when is_binary(filename),
    do: filename

  defp upload_original_filename(_), do: nil

  defp create_penyerahan_for_project(project_id) do
    case Penyerahans.create_penyerahan(%{project_id: project_id}) do
      {:ok, p} -> p
      {:error, _} -> nil
    end
  end

  defp save_uploaded_file(_conn, nil, _penyerahan_id, _prefix), do: nil
  defp save_uploaded_file(_conn, %{path: ""}, _penyerahan_id, _prefix), do: nil
  defp save_uploaded_file(_conn, %{path: nil}, _penyerahan_id, _prefix), do: nil

  defp save_uploaded_file(
         _conn,
         %Plug.Upload{path: path, filename: filename} = upload,
         penyerahan_id,
         prefix
       ) do
    ext = Path.extname(filename) |> String.downcase()
    ext = if ext in @allowed_extensions, do: ext, else: ".pdf"

    file_size = Map.get(upload, :size, 0)

    if file_size > @max_file_size do
      nil
    else
      dest_dir = Path.join(File.cwd!(), "priv/static/uploads/penyerahan")
      File.mkdir_p!(dest_dir)
      dest_filename = "#{prefix}_#{penyerahan_id}#{ext}"
      dest_path = Path.join(dest_dir, dest_filename)
      File.cp!(path, dest_path)
      dest_filename
    end
  rescue
    _ -> nil
  end
end
