defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel
  # example because calculated at compile time
  @example_cards Codenames.Cards.generate_new_cards_for_game()

  alias CodeNames.Cards.Card
  alias CodeNames.GameServer

  def join("room:lobby", _message, socket) do
    {:ok, GameServer.get_cards(), socket}
  end

  def handle_in("new:msg", msg, socket) do
    broadcast!(socket, "new:msg", %{user: msg["user"], body: msg["body"]})
    {:reply, :ok}
  end

  def handle_in("clicked", msg, socket) do
    clicked_hash = msg["body"]

    updated_cards = GameServer.turn_card(clicked_hash)
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end
end
