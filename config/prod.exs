import Config

config :membrane_dashboard, Membrane.DashboardWeb.Endpoint, url: [host: "example.com", port: 80]

config :logger, level: :info

import_config "prod.secret.exs"
