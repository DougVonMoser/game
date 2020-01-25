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

  def handle_in("elmSaysJoinExistingRoom", msg, socket) do
    IO.inspect("elmSaysJoinExistingRoom")
    IO.inspect(msg)

    game_room =
      msg["room"] |> String.to_atom() |> IO.inspect(label: "this is the game_rrom name atom")

    case GenServer.whereis(game_room) do
      nil ->
        raise "#{inspect(game_room)} dont exist}"

      _ ->
        room = Atom.to_string(game_room)
        push(socket, "channelReplyingWithNewGameStarting", %{room: room})
    end

    {:noreply, socket}
  end

  def handle_in("elmSaysCreateNewRoom", _msg, socket) do
    IO.inspect("elmSaysCreateNewRoom")
    IO.inspect(socket)
    new_room = generate_new_random_room()
    push(socket, "channelReplyingWithNewGameStarting", %{room: new_room})

    {:noreply, socket}
  end

  def handle_in("clicked", msg, socket) do
    IO.inspect(socket)
    clicked_hash = msg["body"]
    "room:" <> room = socket.topic
    room = room |> String.upcase() |> String.to_existing_atom()

    updated_cards = GameServer.turn_card(room, clicked_hash)
    IO.inspect("broadcasting!")
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end

  def handle_in("restart", _, socket) do
    updated_cards = GameServer.restart(:ABCD)
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end

  defp generate_new_random_room() do
    random_new_room = for n <- ?A..?Z, do: <<n::utf8>>

    random_new_room |> Enum.shuffle() |> Enum.take(4) |> List.to_string()
  end
end
