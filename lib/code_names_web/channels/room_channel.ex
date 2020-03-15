defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel

  alias CodeNames.Presence
  alias CodeNames.GameServer

  def join("room:lobby", _message, socket) do
    {:ok, "omg hello from roomchannel! welcome! anything to drink?", socket}
  end

  def join("room:" <> game_room, msg, socket) do
    name = Map.get(msg, "name", "DEFAULT_HARD_CODED_NAME") |> IO.inspect(label: "LOOK AT DIS")

    send(self(), {:after_join, name})
    _ = GenServer.start(CodeNames.GameServer, [], name: String.to_atom(game_room))
    {:ok, :waitforitwaitforitwait, socket}
  end

  def handle_info({:after_join, name}, socket) do
    # push(socket, "presence_state", Presence.list(socket))

    {:ok, _} =
      Presence.track(socket, socket.assigns.user_id, %{
        name: name,
        online_at: inspect(System.system_time(:second))
      })

    broadcast!(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("elmSaysStartCardGame", _msg, socket) do
    IO.inspect("elmSaysStartCardGame")
    "room:" <> room = socket.topic
    room = room |> String.upcase() |> String.to_existing_atom()

    case GenServer.start(CodeNames.GameServer, [], name: room) do
      {:ok, _pid} ->
        cards = GameServer.get_cards(room)
        broadcast!(socket, "signalToStartGameWithCards", %{cards: cards})
        {:noreply, socket}

      {:error, {:already_started, _pid}} ->
        cards = GameServer.get_cards(room)
        broadcast!(socket, "signalToStartGameWithCards", %{cards: cards})
        {:noreply, socket}
    end
  end

  def handle_in("elmSaysJoinExistingRoom", msg, socket) do
    # IO.inspect("elmSaysJoinExistingRoom")

    game_room = msg["room"] |> String.to_atom()

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
    # IO.inspect("elmSaysCreateNewRoom")

    new_room = generate_new_random_room_string()

    push(socket, "channelReplyingWithNewGameStarting", %{room: new_room})

    {:noreply, socket}
  end

  def handle_in("clicked", msg, socket) do
    # IO.inspect("clicked")
    clicked_hash = msg["body"]
    "room:" <> room = socket.topic
    room = room |> String.upcase() |> String.to_existing_atom()

    updated_cards = GameServer.turn_card(room, clicked_hash)

    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end

  def handle_in("restart", _, socket) do
    "room:" <> room = socket.topic
    room = room |> String.upcase() |> String.to_existing_atom()

    updated_cards = GameServer.restart(room)

    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end

  defp generate_new_random_room_string() do
    random_new_room = for n <- ?A..?Z, do: <<n::utf8>>

    random_new_room |> Enum.shuffle() |> Enum.take(4) |> List.to_string()
  end
end
