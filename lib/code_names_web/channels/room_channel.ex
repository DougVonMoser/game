defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel
  # example because calculated at compile time
  @example_cards Codenames.Cards.generate_new_cards_for_game()

  def join("room:lobby", _message, socket) do
    {:ok, @example_cards, socket}
  end

  def handle_in("new:msg", msg, socket) do
    broadcast!(socket, "new:msg", %{user: msg["user"], body: msg["body"]})
    {:reply, :ok}
  end

  def handle_in("clicked", msg, socket) do
    broadcast!(socket, "updateFromServer", %{cards: @example_cards})
    {:noreply, socket}
  end
end
