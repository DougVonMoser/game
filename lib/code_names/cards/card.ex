defmodule Codenames.Cards.Card do
  @doc """
  word is a random word
  original_color can be red | blue | no_team
  hash will be a unique identifier string (uuid probs)
  """
  defstruct word: "testers", original_color: "gray", hash: nil

  def new(color) do
    %__MODULE__{word: Faker.Lorem.word(), hash: Faker.UUID.v4(), original_color: color}
  end
end
