import Config

config :membrane_dashboard,
  ecto_repos: [Membrane.Dashboard.Repo]

config :esbuild,
  version: "0.14.0",
  default: [
    args: ~w(
        src/index.ts
        --bundle
        --target=es2017
        --outfile=../priv/static/assets/js/app.js
        --external:/images/*
      ),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures the endpoint
config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
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
