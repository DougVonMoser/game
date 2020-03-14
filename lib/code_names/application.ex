defmodule CodeNames.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised

    children = [
      CodeNamesWeb.Endpoint,
      CodeNames.Presence
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CodeNames.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CodeNamesWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
