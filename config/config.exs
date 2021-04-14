import Config

config :membrane_dashboard,
  ecto_repos: [Membrane.Dashboard.Repo]

config :membrane_dashboard, Membrane.Dashboard.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "membrane_timescaledb_reporter"

# Configures the endpoint
config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "uT0jyRQH9x5jCEYYpACumazKKQz62FWBNFjaX9IXwhzKvHkmP3jLZ75bClryU6Iv",
  render_errors: [view: Membrane.DashboardWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Membrane.Dashboard.PubSub,
  live_view: [signing_salt: "1US8RBTP"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
