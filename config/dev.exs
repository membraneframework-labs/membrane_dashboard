use Mix.Config

# Configure your database
config :membrane_dashboard, Membrane.Dashboard.Repo,
  username: "postgres",
  password: "postgres",
  database: "membrane_timescaledb_reporter",
  hostname: "localhost",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/membrane_dashboard_web/(live|views)/.*(ex)$",
      ~r"lib/membrane_dashboard_web/templates/.*(eex)$"
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
