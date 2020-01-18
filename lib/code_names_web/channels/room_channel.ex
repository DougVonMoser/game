defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel

  alias CodeNames.GameServer

  def join("room:lobby", _message, socket) do
    case GameServer.start_link(:lobby) do
      {:ok, _pid} ->
        {:ok, GameServer.get_cards(:lobby), socket}

      {:error, {:already_started, _pid}} ->
        {:ok, GameServer.get_cards(:lobby), socket}
    end
  end

  def handle_in("clicked", msg, socket) do
    IO.inspect(socket)
    clicked_hash = msg["body"]

    updated_cards = GameServer.turn_card(:lobby, clicked_hash)
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end

  def handle_in("restart", _, socket) do
    updated_cards = GameServer.restart(:lobby)
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end
end
