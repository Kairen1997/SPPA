defmodule SppaWeb.ApprovedProjectController do
  use SppaWeb, :controller

  alias Sppa.ApprovedProjects

  def kertas_kerja(conn, %{"id" => id}) do
    current_scope = conn.assigns[:current_scope]
    current_user = current_scope && current_scope.user

    if is_nil(current_user) do
      conn
      |> put_status(404)
      |> put_view(html: SppaWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
    else
      load_and_send_kertas_kerja(conn, id)
    end
  end

  def kertas_kerja(conn, _params) do
    conn
    |> put_status(404)
    |> put_view(html: SppaWeb.ErrorHTML)
    |> render(:"404")
    |> halt()
  end

  defp load_and_send_kertas_kerja(conn, id) do
    approved_project = ApprovedProjects.get_approved_project!(id)
    path = approved_project.kertas_kerja_path

    if is_nil(path) or path == "" do
      not_found(conn)
    else
      app_root = Application.get_env(:sppa, :root_path) || File.cwd!()
      base = Path.expand(app_root)
      resolved = Path.expand(path, app_root)

      safe_documents = Path.expand(Path.join(app_root, "priv/static/documents"))

      under_root = String.starts_with?(resolved, base)
      under_documents = String.starts_with?(resolved, safe_documents)

      if (under_root or under_documents) and File.regular?(resolved) do
        filename = Path.basename(resolved)
        content_type = MIME.from_path(resolved)

        sent_conn =
          conn
          |> put_resp_content_type(content_type)
          |> put_resp_header("content-disposition", ~s(inline; filename="#{filename}"))
          |> Plug.Conn.send_file(200, resolved)
          |> halt()

        sent_conn
      else
        not_found(conn)
      end
    end
  rescue
    Ecto.NoResultsError -> not_found(conn)
  end

  defp not_found(conn) do
    conn
    |> put_status(404)
    |> put_view(html: SppaWeb.ErrorHTML)
    |> render(:"404")
    |> halt()
  end
end
