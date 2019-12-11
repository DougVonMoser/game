defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel
  # example because calculated at compile time
  @example_cards Codenames.Cards.generate_new_cards_for_game()

  alias Codenames.Cards.Card

  def join("room:lobby", _message, socket) do
    {:ok, @example_cards, socket}
  end

  def handle_in("new:msg", msg, socket) do
    broadcast!(socket, "new:msg", %{user: msg["user"], body: msg["body"]})
    {:reply, :ok}
  end

  def handle_in("clicked", msg, socket) do
    clicked_hash = msg["body"]

    mapper = fn card ->
      if card.hash == clicked_hash do
        %{card | turned_over_by: card.original_color}
      else
        card
      end
    end

    updated_cards = Enum.map(@example_cards, mapper)
    broadcast!(socket, "updateFromServer", %{cards: updated_cards})
    {:noreply, socket}
  end

  def mapper(%Card{hash: hash}) do
  end
end
