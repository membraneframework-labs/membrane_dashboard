import Config

# Configure your database
config :membrane_dashboard, Membrane.Dashboard.Repo, show_sensitive_data_on_connection_error: true

config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: [
    esbuild:
      {Esbuild, :install_and_run,
       [
         :default,
         ~w(--sourcemap=inline --bundle --watch)
       ]},
    npx: [
      "tailwindcss",
      "--input=css/app.css",
      "--output=../priv/static/assets/css/app.css",
      "--postcss",
      "--watch",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/membrane_dashboard_web/(live|views)/.*(ex)$",
      ~r"lib/membrane_dashboard/.*(ex)$",
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
