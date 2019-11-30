defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    {:ok, "hi elm", socket}
  end
end
