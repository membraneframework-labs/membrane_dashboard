defmodule Membrane.DashboardWeb.Live.Components.MetricsSelect do
  @moduledoc """
  Component for selecting metrics that should get queried from database and displayed
  on charts.
  """

  use Membrane.DashboardWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    selectable_metrics = Map.keys(assigns.available_metrics) -- assigns.metrics

    socket
    |> assign(assigns)
    |> assign(selectable_metrics: selectable_metrics)
    |> then(&{:ok, &1})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col mb-3">
      <h3 class="subheader">Metrics</h3>
      <p class="description mb-3">Select from a set of metrics query from</p>

      <div class="flex items-center rounded-lg bg-secondary p-3">
        <div class="flex justify-center items-center">
          <%= for metric <- @metrics do %>
            <div
              class="text-white rounded-md bg-primary border border-gray-300/25 p-2 mr-3 cursor-pointer hover:bg-red-600"
              phx-click={"metrics:remove:#{metric}"}
              phx-target={@myself}
            >
              <%= metric %>
            </div>
          <% end %>
        </div>

        <%= if @selectable_metrics != [] do %>
          <div x-data="{ open: false }" class="relative">
            <button
              @click="open = !open"
              @keydown.scape="open = false"
              class="default-button"
            >
              Add metric
            </button>
            <div x-show="open" @click.away="open = false" class="dropdown-container w-80 left-0 bottom-2">
              <%= for metric <- @selectable_metrics do %>
                <div
                  @click="open = false"
                  class="dropdown-option"
                  phx-click={"metrics:add:#{metric}"}
                  phx-target={@myself}
                >
                  <%= metric %> <span class="text-gray-300 font-light">(<%= Map.get(@available_metrics, metric) %>)</span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

      </div>
    </div>
    """
  end

  @impl true
  def handle_event("metrics:add:" <> metric, _params, socket) do
    send_self({:add, metric})

    {:noreply, socket}
  end

  @impl true
  def handle_event("metrics:remove:" <> metric, _params, socket) do
    send_self({:remove, metric})

    {:noreply, socket}
  end

  defp send_self(message) do
    send(self(), {:metrics_select, message})
  end
end
