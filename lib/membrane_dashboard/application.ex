defmodule Membrane.Dashboard.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Membrane.Dashboard.Repo,
      {Phoenix.PubSub, name: Membrane.Dashboard.PubSub},
      Membrane.DashboardWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Membrane.Dashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    Membrane.DashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
