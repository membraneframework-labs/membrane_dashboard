defmodule Membrane.DashboardWeb.Live.Components.AlivePipelines do
  @moduledoc """
  Component for displaying alive pipelines that further can be marked as dead
  if the application starting them unexpectedly crashed.
  """

  use Membrane.DashboardWeb, :live_component

  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="m-4">
      <h3 class="subheader">Pipeline marking</h3>
      <p class="text-white mb-2">It may happen that pipeline terminating has not been registered. Here you can manually mark pipeline as dead.</p>
      <div id="alive-pipelines" class="flex items-center bg-secondary rounded-xl p-5">
        <%= for pipeline <- @alive_pipelines do %>
          <div x-data="{ open: false }" class="relative">
            <button
              data-combo-id={pipeline}
              @click="open = !open"
              class="base-button text-white font-bold bg-green-600 hover:bg-red-500 mr-3"
            >
              <%= pipeline %>
            </button>

            <div
              x-show="open"
              @click.away="open = !open"
              class="flex flex-col rounded-xl absolute bottom-2 p-5 bg-primary border border-gray-200/25"
            >
              <span class="text-white font-bold mb-5">Are you sure that you want to mark pipeline as dead?</span>
              <div class="flex">
                <button
                  @click="open = !open"
                  class="base-button bg-gray-700 hover:bg-gray-800 mr-3"
                >
                  Cancel
                </button>
                <button
                  @click="open = !open"
                  phx-click={JS.push("pipelines:focus",value: %{pipeline: pipeline})}
                  phx-target={@myself}
                  class="danger-button"
                >
                  Delete
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event(
        "pipelines:focus",
        %{"pipeline" => pipeline},
        socket
      ) do
    send_self({:mark_dead, pipeline})

    {:noreply, assign(socket, is_marking_active: false)}
  end

  # TODO: this should be put inside `use Membrane.DashboardWeb, :live_component`
  defp send_self(message) do
    send(self(), {:alive_pipelines, message})
  end
end
