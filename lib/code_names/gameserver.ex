defmodule CodeNames.GameServer do
  use GenServer

  def start_link(_) do
    # out here self() is the caller's pid.
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    IO.inspect("I WAS INITTED")
    {:ok, Codenames.Cards.generate_new_cards_for_game()}
  end

  @impl true
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

  def turn_card(hash) do
    IO.inspect("I WAS turn carded")
    GenServer.call(__MODULE__, {:clicked, hash})
  end

  def get_cards do
    GenServer.call(__MODULE__, :get_cards)
  end
end
