defmodule CodeNames.Presence do
  use Phoenix.Presence, otp_app: :codenames, pubsub_server: CodeNames.PubSub

  def fetch(_topic, entries) do
    for {key, %{metas: metas}} <- entries, into: %{} do
      name =
        metas
        |> List.first()
        |> Map.get(:name)

      {key, %{metas: metas, name: name}}
    end
  end
end
