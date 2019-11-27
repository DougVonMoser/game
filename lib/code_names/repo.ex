defmodule CodeNames.Repo do
  use Ecto.Repo,
    otp_app: :code_names,
    adapter: Ecto.Adapters.Postgres
end
