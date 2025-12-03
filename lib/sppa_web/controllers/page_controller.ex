defmodule SppaWeb.PageController do
  use SppaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
