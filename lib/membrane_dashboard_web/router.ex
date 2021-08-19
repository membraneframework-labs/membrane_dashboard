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
end
