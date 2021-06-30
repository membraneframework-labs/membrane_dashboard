import Config

config :membrane_dashboard, Membrane.Dashboard.Repo,
  username: System.fetch_env!("DB_USER"),
  password: System.fetch_env!("DB_PASS"),
  database: System.fetch_env!("DB_NAME"),
  hostname: System.fetch_env!("DB_HOST"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

config :membrane_dashboard, Membrane.DashboardWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "8000"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "uT0jyRQH9x5jCEYYpACumazKKQz62FWBNFjaX9IXwhzKvHkmP3jLZ75bClryU6Iv",
  url: [host: System.fetch_env!("HOST")]
