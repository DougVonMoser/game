defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel

  alias CodeNames.GameServer

  def join("room:lobby", _message, socket) do
    {:ok, "omg hello from roomchannel! welcome! anything to drink?", socket}
  end

  def join("room:" <> game_room, _message, socket) do
    game_room = String.to_atom(game_room) |> IO.inspect(label: "this is the game_rrom name atom")

    case GenServer.start(CodeNames.GameServer, [], name: game_room) do
      {:ok, _pid} ->
        IO.inspect("started new Genserver #{inspect(game_room)}")
        {:ok, GameServer.get_cards(game_room), socket}

      {:error, {:already_started, _pid}} ->
        IO.inspect("already started Genserver #{inspect(game_room)}")
        {:ok, GameServer.get_cards(game_room), socket}
    end
  end

  def handle_in("elmSaysCreateNewRoom", _msg, socket) do
    IO.inspect("elmSaysCreateNewRoom")
    IO.inspect(socket)
    push(socket, "channelReplyingWithNewGameStarting", %{room: "ABCD"})
    {:noreply, socket}
  end

  def handle_in("clicked", msg, socket) do
    IO.inspect(socket)
    clicked_hash = msg["body"]

    updated_cards = GameServer.turn_card(:ABCD, clicked_hash)
    IO.inspect("broadcasting!")
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end

  def handle_in("restart", _, socket) do
    updated_cards = GameServer.restart(:ABCD)
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end
end
