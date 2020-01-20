defmodule CodeNames.GameServer do
  use GenServer

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_) do
    IO.inspect("I WAS INITTED")
    {:ok, Codenames.Cards.generate_new_cards_for_game()}
  end

  def handle_call({:clicked, hash}, _from, cards) do
    IO.inspect("I WAS get clidkedkced")

    mapper = fn card ->
      if card.hash == hash do
        %{card | turned_over_by: card.original_color}
      else
        card
      end
    end

    updated_cards = Enum.map(cards, mapper)
    {:reply, updated_cards, updated_cards}
  end

  def handle_call(:get_cards, _from, cards) do
    IO.inspect("I WAS get carded")
    {:reply, cards, cards}
  end

  def handle_call(:restart, _from, _) do
    IO.inspect("I WAS RESTARTED")
    new_cards = Codenames.Cards.generate_new_cards_for_game()

    {:reply, new_cards, new_cards}
  end

  # all these need a topic to ask which process to reach out to
  # be simple to keep the room/game id in sync with the genserver name
  #
  def turn_card(name, hash) do
    IO.inspect("I WAS turn carded")
    GenServer.call(name, {:clicked, hash})
  end

  def get_cards(name) do
    IO.inspect(name, label: "Genserver.call namey")
    GenServer.call(name, :get_cards)
  end

  def restart(name) do
    GenServer.call(name, :restart)
  end
end
