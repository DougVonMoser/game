defmodule CodeNamesWeb.PageController do
  use CodeNamesWeb, :controller

  def test(conn, _) do
    json(conn, %{result: "gucci"})
  end

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
