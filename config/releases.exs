import Config

config :code_names, CodeNamesWeb.Endpoint, url: [host: System.fetch_env!("HOST_URL"), port: 80]
