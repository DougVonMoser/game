defmodule Codenames.Cards do
  @doc """
  returns random cards for a new game
  for now, even 7 for each team
  """

  alias Codenames.Cards.Card

  def generate_new_cards_for_game do
    (List.duplicate("red", 7) ++ List.duplicate("blue", 7) ++ List.duplicate("gray", 11))
    |> Enum.map(fn color -> Card.new(color) end)
    |> Enum.shuffle()
  end
end
