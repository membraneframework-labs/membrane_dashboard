defmodule Membrane.DashboardWeb.Live.Components.ElementsSelect do
  @moduledoc """
  Component for selecting and displaying currently selected elements' path
  that can be further used for different kinds of filtering e.g. in charts.
  """

  use Membrane.DashboardWeb, :live_component

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            current_select_values: [String.t()],
            active_elements: [String.t()]
          }

    defstruct current_select_values: [], active_elements: []
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="ElementsSelect">
      <div class="activeElements">
        <%= if @state.active_elements != [] do %>
            <%= for element <- @state.active_elements do %>
              <div>
                <%= element %>
              </div>
            <% end %>
        <% end %>
      </div>
      <form phx-change="change" phx-submit="submit" phx-target={@myself}>
        <div>
          <select id="select-current-element" name="value" disabled={@disabled}>
            <option selected={true} disabled>Choose element</option>
            <%= for {value, idx} <- Enum.with_index(@state.current_select_values) do %>
              <option value={idx + 1} selected={false}>
                <%= value %>
              </option>
            <% end %>
          </select>
          <button name="add-to-path" type="submit" disabled={@disabled}>
            Add to path
          </button>
          <button type="button" phx-click="filter-active-elements" disabled={@disabled} phx-target={@myself}>
            Apply active elements filter
          </button>
          <button type="button" phx-click="reset-active-elements" disabled={@disabled} phx-target={@myself}>
            Reset
          </button>
        </div>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("change", _params, socket) do
    # TODO: we may need to reassign the value here to socket (we probably don't have to...)
    {:noreply, socket}
  end

  def handle_event("filter-active-elements", _params, socket) do
    send_self(:apply_filter)

    {:noreply, socket}
  end

  def handle_event("reset-active-elements", _params, socket) do
    send_self(:reset)

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", %{"value" => value}, socket) do
    idx = String.to_integer(value)

    %State{active_elements: active_elements, current_select_values: current_select_values} =
      socket.assigns.state

    selected_element = Enum.at(current_select_values, idx - 1)
    active_elements = active_elements ++ [selected_element]
    current_select_values = Map.keys(get_in(socket.assigns.elements_tree, active_elements))

    send_self(%State{
      active_elements: active_elements,
      current_select_values: current_select_values
    })

    {:noreply, socket}
  end

  def handle_event("submit", _params, socket), do: {:noreply, socket}

  defp send_self(message) do
    send(self(), {:elements_select, message})
  end
end
