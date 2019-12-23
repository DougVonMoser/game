defmodule Codenames.Cards do
  @doc """
  returns random cards for a new game
  for now, even 7 for each team
  """

  alias Codenames.Cards.Card

  def generate_new_cards_for_game do
    (List.duplicate("red", 7) ++ List.duplicate("blue", 7) ++ List.duplicate("gray", 11))
    |> Enum.zip(twenty_five_static_real_words())
    |> Enum.map(fn {color, word} -> Card.new(color, word) end)
    |> Enum.shuffle()
  end

  def twenty_five_static_real_words do
    ~w( yard apple mine turkey check queen kiwi code copper jack undertaker cell play cover mail tooth point tube force track game washer bell octopus chair)
  end
end
