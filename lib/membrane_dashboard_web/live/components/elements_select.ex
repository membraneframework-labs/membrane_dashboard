defmodule Membrane.DashboardWeb.Live.Components.ElementsSelect do
  @moduledoc """
  Component for selecting and displaying currently selected elements' path
  that can be further used for different kinds of filtering e.g. in charts.
  """

  use Membrane.DashboardWeb, :live_component

  import Membrane.DashboardWeb.Live.Helpers, only: [info_header: 1, arrow_down_icon: 1]

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="flex flex-col mb-3">
      <.info_header
        title="Selected path"
        tooltip="You may want to filter charts to a subset of elements or a single particular element, you can do so by selecting elements' path"
      />
      <%= if length(@active_path) > 0 do %>
        <div class="flex flex-col justify-center bg-secondary rounded-xl w-fit p-3">
          <%= for element <- Enum.intersperse(@active_path, :icon) do %>
            <%= if element == :icon do %>
              <div class="flex justify-center items-center p-2">
                <.arrow_down_icon />
              </div>
            <% else %>
              <div class="text-white rounded-lg bg-primary border border-gray-300/25 p-3 mb-2">
                <%= element %>
              </div>
            <% end %>
          <% end %>

          <div class="flex justify-end">
            <button
              type="button"
              disabled={@disabled}
              class="danger-button m-2"
              phx-click="reset-active-elements"
              phx-target={@myself}
            >
              Reset
            </button>
          <div>
        </div>
      <% else %>
        <div class="flex items-center bg-secondary rounded-xl p-3 description">
          No path selected...
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("reset-active-elements", _params, socket) do
    send(self(), {:elements_select, :reset})

    {:noreply, socket}
  end
end
