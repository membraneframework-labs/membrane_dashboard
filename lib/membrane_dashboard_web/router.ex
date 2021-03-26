defmodule Membrane.DashboardWeb.Router do
  use Membrane.DashboardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Membrane.DashboardWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Membrane.DashboardWeb do
    pipe_through :browser

    live "/", DashboardLive
  end

  # Enables LiveDashboard only for development
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: Membrane.DashboardWeb.Telemetry
    end
  end
end
