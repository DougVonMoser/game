defmodule CodeNames.Cards do
  @doc """
  returns random cards for a new game
  """

  alias CodeNames.Cards.Card
  alias CodeNames.Cards.ExhaustiveWordList

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
    |> Enum.zip([7, 7])
    |> Enum.map(fn {color, count} -> List.duplicate(color, count) end)
    |> Enum.concat()
    |> Kernel.++(List.duplicate("gray", 6))
  end

  def twenty_five_static_real_words do
    ExhaustiveWordList.words()
    |> Enum.uniq()
    |> Enum.shuffle()
    |> Enum.take(20)
  end
end
