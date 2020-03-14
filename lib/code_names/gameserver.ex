defmodule CodeNames.GameServer do
  use GenServer

  defstruct [:cards, :players]

  def init(_) do
    IO.inspect("I WAS INITTED")

    initial_state = %__MODULE__{
      cards: CodeNames.Cards.generate_new_cards_for_game(),
      players: []
    }

    {:ok, initial_state}
  end

  def handle_call({:clicked, hash}, _from, state) do
    IO.inspect("I WAS get clidkedkced")
    cards = state.cards

    mapper = fn card ->
      if card.hash == hash do
        %{card | turned_over_by: card.original_color}
      else
        card
      end
    end

    updated_state = %{state | cards: Enum.map(cards, mapper)}
    {:reply, updated_state.cards, updated_state}
  end

  def handle_call(:get_cards, _from, state) do
    IO.inspect("I WAS get carded")
    {:reply, state.cards, state}
  end

  def handle_call(:restart, _from, state) do
    IO.inspect("I WAS RESTARTED")
    new_state = %{state | cards: CodeNames.Cards.generate_new_cards_for_game()}

    {:reply, new_state.cards, new_state}
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
