defmodule Membrane.Dashboard.Repo do
  use Ecto.Repo,
    otp_app: :membrane_dashboard,
    adapter: Ecto.Adapters.Postgres
end
