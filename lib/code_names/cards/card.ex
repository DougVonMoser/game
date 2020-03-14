defmodule CodeNames.Cards.Card do
  @doc """
  word is a random word
  original_color can be red | blue | no_team
  hash will be a unique identifier string (uuid probs)
  """
  @derive Jason.Encoder

  defstruct word: "testers", original_color: "gray", hash: nil, turned_over_by: nil

  def new(color, word) do
    %__MODULE__{word: word, hash: Ecto.UUID.generate(), original_color: color}
  end
end

# type Card
#     = UnTurned Word OriginallyColored Hash
#     | Turned Word TurnedOverBy OriginallyColored Hash
# 
