defmodule SppaWeb.Internal.ApprovedProjectController do
  use SppaWeb, :controller

  plug :verify_internal_token

  def create(conn, params) do
    case Sppa.ApprovedProjects.create_approved_project(params) do
      {:ok, _record} ->
        send_resp(conn, 201, "Created")

      {:error, _changeset} ->
        send_resp(conn, 422, "Invalid data")
    end
  end

  defp verify_internal_token(conn, _opts) do
    if get_req_header(conn, "authorization") == ["Bearer Sppa_INTERNAL_SECRET"] do
      conn
    else
      conn |> send_resp(403, "Forbidden") |> halt()
    end
  end
end
