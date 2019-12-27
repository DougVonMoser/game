defmodule Codenames.Cards do
  @doc """
  returns random cards for a new game
  for now, even 7 for each team
  """

  alias Codenames.Cards.Card
  alias Codenames.Cards.ExhaustiveWordList

  def generate_new_cards_for_game do
    red_and_blues_and_grays()
    |> Enum.shuffle()
    |> Enum.zip(twenty_five_static_real_words())
    |> Enum.map(fn {color, word} -> Card.new(color, word) end)
    |> Enum.shuffle()
  end

  def red_and_blues_and_grays do
    ["red", "blue"]
    |> Enum.shuffle()
    |> Enum.zip([9, 8])
    |> Enum.map(fn {color, count} -> List.duplicate(color, count) end)
    |> Enum.concat()
    |> Kernel.++(List.duplicate("gray", 8))
  end

  def twenty_five_static_real_words do
    ExhaustiveWordList.words()
    |> Enum.shuffle()
    |> Enum.take(25)
  end
end
