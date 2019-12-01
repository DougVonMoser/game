defmodule CodeNamesWeb.RoomChannel do
  use Phoenix.Channel

  def join("room:lobby", _message, socket) do
    some_cards = Codenames.Cards.generate_new_cards_for_game()
    {:ok, some_cards, socket}
  end
end
