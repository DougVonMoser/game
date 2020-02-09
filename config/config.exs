# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :code_names, CodeNamesWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "+vNr0SuVkZ7PaQFz7jcakwvORVM1IRKKvXk+1rLdeuo9lvd1d5o1aAAYIGJCPHgz",
  render_errors: [view: CodeNamesWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: CodeNames.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason
config :code_names, env: Mix.env()

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
