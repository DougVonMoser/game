defmodule CodeNamesWeb.PageController do
  use CodeNamesWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
