import Config

config :membrane_dashboard, Membrane.Dashboard.Repo,
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASS", "postgres"),
  database: System.get_env("DB_NAME", "membrane_timescaledb_reporter"),
  hostname: System.get_env("DB_HOST", "localhost"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "8000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "uT0jyRQH9x5jCEYYpACumazKKQz62FWBNFjaX9IXwhzKvHkmP3jLZ75bClryU6Iv",
  url: [host: System.get_env("HOST", "localhost")]
